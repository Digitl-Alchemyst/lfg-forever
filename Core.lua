-- LFG Forever: data, filters, actions, slash commands.
--
-- Design rules (learned from this client):
--  * Never call into or hook the game's own Looking For Group window
--    (LFGParentFrame / LFGBrowseFrame). Addon code touching it "taints" it and
--    its searches break until /reload. We use our own window and only the
--    C_LFGList API, so the original window keeps working through the normal
--    menu button.
--  * C_LFGList.Search needs a real mouse/key press, so searches only start
--    from the Search button (or Enter), never from timers or events.
--  * Values can come back "secret" (e.g. in combat). Every read goes through
--    Safe(), and a secret value is treated as unknown instead of erroring.

local ADDON, ns = ...
_G.LFGForever = ns

local DEFAULTS = {
    minimap = { angle = 215, hide = false },
    categoryID = nil,
    activityIDs = {},
    roles = { TANK = false, HEALER = false, DAMAGER = false },
    show = "ALL",          -- ALL | GROUPS | PLAYERS
    hideDelisted = true,
    minLevel = nil,
    maxLevel = nil,
    text = "",
    sort = "DEFAULT",      -- DEFAULT | LEVEL | NAME | MEMBERS
    hideDeclined = true,
    point = nil,
}

ns.ROLES = { "TANK", "HEALER", "DAMAGER" }
ns.ROLE_NAMES = { TANK = "Tank", HEALER = "Healer", DAMAGER = "DPS" }
ns.results = {}      -- all parsed results from the last search
ns.filtered = {}     -- results after our filters
ns.requested = {}    -- leaderName -> time we sent a Request to Join
ns.declined = {}     -- leaderName -> time they declined our Request to Join
ns.searching = false
ns.sawSecret = false

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function ns.Print(msg)
    print("|cff33ccffLFG Forever:|r " .. tostring(msg))
end

-- ----------------------------------------------------------------- safety
local issecret = _G.issecretvalue
local function Safe(v)
    if issecret and issecret(v) then
        ns.sawSecret = true
        return nil
    end
    return v
end
ns.Safe = Safe

local function Call(fn, ...)
    if not fn then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
    return nil
end
ns.Call = Call

-- ------------------------------------------------------------ categories
function ns.GetCategories()
    local list = {}
    local ids = Call(C_LFGList and C_LFGList.GetAvailableCategories)
    if type(ids) ~= "table" then return list end
    for _, id in ipairs(ids) do
        local info = Call(C_LFGList.GetLfgCategoryInfo, id)
        local name = type(info) == "table" and info.name or ("Category " .. id)
        list[#list + 1] = { id = id, name = name }
    end
    return list
end

function ns.GetCategoryName(id)
    if not id then return "Pick a category" end
    local info = Call(C_LFGList and C_LFGList.GetLfgCategoryInfo, id)
    return type(info) == "table" and info.name or ("Category " .. id)
end

local activityCache = {}
function ns.GetActivityInfo(id)
    if not id then return nil end
    local info = activityCache[id]
    if info == nil then
        info = Call(C_LFGList and C_LFGList.GetActivityInfoTable, id) or false
        activityCache[id] = info
    end
    return info or nil
end

function ns.GetActivityName(id)
    local info = ns.GetActivityInfo(id)
    if info then return info.fullName or info.shortName or ("Activity " .. id) end
    return "Activity " .. tostring(id)
end

function ns.GetActivities(categoryID)
    local list = {}
    if not categoryID then return list end
    local ids = Call(C_LFGList and C_LFGList.GetAvailableActivities, categoryID)
    if type(ids) ~= "table" then return list end
    for _, id in ipairs(ids) do
        local info = ns.GetActivityInfo(id)
        list[#list + 1] = {
            id = id,
            name = ns.GetActivityName(id),
            minLevel = info and (info.minLevelSuggestion or info.minLevel),
            maxLevel = info and (info.maxLevelSuggestion or info.maxLevel),
        }
    end
    table.sort(list, function(a, b)
        local la, lb = a.minLevel or 0, b.minLevel or 0
        if la ~= lb then return la < lb end
        return a.name < b.name
    end)
    return list
end

-- Pick "Dungeons" (or the first category) when nothing was saved yet.
function ns.EnsureCategory()
    local db = ns.db
    if db.categoryID then return end
    local cats = ns.GetCategories()
    for _, c in ipairs(cats) do
        if c.name and c.name:lower():find("dungeon") then db.categoryID = c.id; return end
    end
    if cats[1] then db.categoryID = cats[1].id end
end

-- ------------------------------------------------------- zone matching
-- For the Titan Panel plugin: finds, among a category's activities, one
-- whose name matches the player's current zone (an outdoor "questing"
-- activity, e.g. a dig site) and one whose own map falls within the
-- player's current zone/continent but isn't named after it (a dungeon
-- reachable from here).
local function MapAncestors(mapID, depth)
    local chain = {}
    local id = mapID
    for _ = 1, (depth or 4) do
        if not id then break end
        chain[id] = true
        local info = Call(C_Map and C_Map.GetMapInfo, id)
        id = type(info) == "table" and Safe(info.parentMapID) or nil
    end
    return chain
end

function ns.CurrentZoneChain()
    local mapID = Safe(Call(C_Map and C_Map.GetBestMapForUnit, "player"))
    if not mapID then return {} end
    return MapAncestors(mapID, 4)
end

function ns.CurrentZoneName()
    return Safe(GetRealZoneText()) or Safe(GetZoneText()) or ""
end

function ns.FindZoneAndDungeonActivity(categoryID)
    local zoneName = ns.CurrentZoneName()
    local chain = ns.CurrentZoneChain()
    local zoneActivity, dungeonActivity
    for _, a in ipairs(ns.GetActivities(categoryID)) do
        local nameMatch = zoneName ~= "" and a.name and a.name:lower():find(zoneName:lower(), 1, true)
        if nameMatch and not zoneActivity then
            zoneActivity = a
        elseif not nameMatch and not dungeonActivity then
            local info = ns.GetActivityInfo(a.id)
            local mapID = info and Safe(info.mapID)
            if mapID and chain[mapID] then
                dungeonActivity = a
            end
        end
    end
    return zoneActivity, dungeonActivity, zoneName
end

-- Active listings (from the last search) for one activity, groups first.
function ns.ListByActivity(activityID, limit)
    local list = {}
    for _, e in ipairs(ns.results) do
        if not e.delisted then
            for _, id in ipairs(e.activityIDs) do
                if id == activityID then list[#list + 1] = e; break end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.isSolo ~= b.isSolo then return not a.isSolo end
        return a.order < b.order
    end)
    if limit and #list > limit then
        for i = #list, limit + 1, -1 do list[i] = nil end
    end
    return list
end

function ns.CountByActivity(activityID)
    local groups, solo = 0, 0
    for _, e in ipairs(ns.results) do
        if not e.delisted then
            for _, id in ipairs(e.activityIDs) do
                if id == activityID then
                    if e.isSolo then solo = solo + 1 else groups = groups + 1 end
                    break
                end
            end
        end
    end
    return groups, solo
end

-- Runs a one-activity search and opens the window. Only call this from a
-- click - see the note on ns.Search() above.
function ns.SearchActivity(activityID)
    if not activityID or not ns.db then return end
    ns.db.activityIDs = { activityID }
    if not ns.frame then ns.CreateUI() end
    if not ns.frame:IsShown() then ns.frame:Show() end
    ns.Search()
end

-- ---------------------------------------------------------------- search
-- Must be called from a click / key press.
function ns.Search()
    local db = ns.db
    ns.EnsureCategory()
    if not db.categoryID then
        ns.Print("No Looking For Group categories are available right now.")
        return
    end
    if not (C_LFGList and C_LFGList.Search) then
        ns.Print("This client has no group search (C_LFGList.Search).")
        return
    end
    local activityIDs = {}
    for _, id in ipairs(db.activityIDs) do activityIDs[#activityIDs + 1] = id end
    if #activityIDs == 0 then
        for _, a in ipairs(ns.GetActivities(db.categoryID)) do activityIDs[#activityIDs + 1] = a.id end
    end
    -- Same arguments the game's own Search button uses on this client.
    local ok, err = pcall(C_LFGList.Search, db.categoryID, 0, 0, nil, false, nil, activityIDs)
    if not ok then
        ns.Print("Search failed: " .. tostring(err))
        ns.searching = false
    else
        ns.searching = true
        ns.searchFailed = false
    end
    if ns.UpdateUI then ns.UpdateUI() end
end

-- ------------------------------------------------------- reading results
local function ParseResult(id)
    local info = Call(C_LFGList.GetSearchResultInfo, id)
    if type(info) ~= "table" then return nil end
    local e = {
        id = id,
        name = Safe(info.leaderName),
        numMembers = Safe(info.numMembers) or 1,
        delisted = Safe(info.isDelisted) and true or false,
        hasSelf = Safe(info.hasSelf) and true or false,
        comment = Safe(info.comment) or "",
        age = Safe(info.age),
        newPlayerFriendly = Safe(info.newPlayerFriendly),
        activityIDs = {},
    }
    if type(info.activityIDs) == "table" then
        for _, a in ipairs(info.activityIDs) do e.activityIDs[#e.activityIDs + 1] = Safe(a) end
    elseif Safe(info.activityID) then
        e.activityIDs[1] = info.activityID
    end
    e.isSolo = e.numMembers == 1

    if #e.activityIDs == 1 then
        e.activityText = ns.GetActivityName(e.activityIDs[1])
    elseif #e.activityIDs > 1 then
        local names = {}
        for i, a in ipairs(e.activityIDs) do
            if i > 3 then names[#names + 1] = "..."; break end
            names[#names + 1] = ns.GetActivityInfo(a) and (ns.GetActivityInfo(a).shortName or ns.GetActivityName(a)) or ns.GetActivityName(a)
        end
        e.activityText = #e.activityIDs .. " activities: " .. table.concat(names, ", ")
    else
        e.activityText = ""
    end

    local leader = Call(C_LFGList.GetSearchResultLeaderInfo, id)
    if type(leader) == "table" then
        e.name = e.name or Safe(leader.name)
        e.classFile = Safe(leader.classFilename)
        e.level = Safe(leader.level)
        e.area = Safe(leader.areaName)
        if type(leader.lfgRoles) == "table" then
            e.roles = {
                TANK = Safe(leader.lfgRoles.tank) and true or false,
                HEALER = Safe(leader.lfgRoles.healer) and true or false,
                DAMAGER = Safe(leader.lfgRoles.dps) and true or false,
            }
        end
    end

    -- Members (for the tooltip; solo players' roles live here too).
    e.members = {}
    if C_LFGList.GetSearchResultPlayerInfo and e.numMembers <= 40 then
        for i = 1, e.numMembers do
            local m = Call(C_LFGList.GetSearchResultPlayerInfo, id, i)
            if type(m) == "table" then
                local mem = {
                    name = Safe(m.name), classFile = Safe(m.classFilename), level = Safe(m.level),
                    role = Safe(m.assignedRole), isLeader = Safe(m.isLeader),
                }
                e.members[#e.members + 1] = mem
                if e.isSolo then
                    e.classFile = e.classFile or mem.classFile
                    e.level = e.level or mem.level
                    if not e.roles and type(m.lfgRoles) == "table" then
                        e.roles = {
                            TANK = Safe(m.lfgRoles.tank) and true or false,
                            HEALER = Safe(m.lfgRoles.healer) and true or false,
                            DAMAGER = Safe(m.lfgRoles.dps) and true or false,
                        }
                    end
                end
            end
        end
    end

    local counts = Call(C_LFGList.GetSearchResultMemberCounts, id)
    if type(counts) == "table" then
        e.counts = {}
        for _, r in ipairs(ns.ROLES) do
            e.counts[r] = Safe(counts[r]) or 0
            e.counts[r .. "_REMAINING"] = Safe(counts[r .. "_REMAINING"])
        end
    end
    return e
end

function ns.CollectResults()
    wipe(ns.results)
    ns.sawSecret = false
    if not C_LFGList then return end
    local getter = C_LFGList.GetFilteredSearchResults or C_LFGList.GetSearchResults
    local _, ids = Call(getter)
    if type(ids) ~= "table" then return end
    for i, id in ipairs(ids) do
        local e = ParseResult(id)
        if e then
            e.order = i
            ns.results[#ns.results + 1] = e
        end
    end
end

-- ---------------------------------------------------------------- filters
local function RoleFilterActive(db)
    return db.roles.TANK or db.roles.HEALER or db.roles.DAMAGER
end

-- A solo player passes when they offer a selected role. A group passes when
-- it still has a free slot for a selected role.
local function PassesRoles(e, db)
    if not RoleFilterActive(db) then return true end
    for _, r in ipairs(ns.ROLES) do
        if db.roles[r] then
            if e.isSolo then
                if e.roles and e.roles[r] then return true end
            else
                local rem = e.counts and e.counts[r .. "_REMAINING"]
                if rem == nil or rem > 0 then return true end
            end
        end
    end
    return false
end

local function PassesText(e, text)
    if not text or text == "" then return true end
    text = text:lower()
    local hay = ((e.name or "") .. " " .. (e.comment or "") .. " " .. (e.activityText or "")):lower()
    return hay:find(text, 1, true) ~= nil
end

local SORTS = {
    DEFAULT = function(a, b)
        if a.isSolo ~= b.isSolo then return not a.isSolo end -- groups first
        return a.order < b.order
    end,
    LEVEL = function(a, b)
        local la, lb = a.level or 0, b.level or 0
        if la ~= lb then return la > lb end
        return a.order < b.order
    end,
    NAME = function(a, b)
        local na, nb = (a.name or ""):lower(), (b.name or ""):lower()
        if na ~= nb then return na < nb end
        return a.order < b.order
    end,
    MEMBERS = function(a, b)
        if a.numMembers ~= b.numMembers then return a.numMembers > b.numMembers end
        return a.order < b.order
    end,
}
ns.SORT_ORDER = { "DEFAULT", "LEVEL", "NAME", "MEMBERS" }
ns.SORT_NAMES = { DEFAULT = "Groups first", LEVEL = "Level", NAME = "Name", MEMBERS = "Group size" }

function ns.ApplyFilters()
    local db = ns.db
    wipe(ns.filtered)
    for _, e in ipairs(ns.results) do
        local ok = true
        if db.hideDelisted and e.delisted then ok = false end
        if ok and db.show == "GROUPS" and e.isSolo then ok = false end
        if ok and db.show == "PLAYERS" and not e.isSolo then ok = false end
        if ok and db.minLevel and e.level and e.level < db.minLevel then ok = false end
        if ok and db.maxLevel and e.level and e.level > db.maxLevel then ok = false end
        if ok and not PassesRoles(e, db) then ok = false end
        if ok and not PassesText(e, db.text) then ok = false end
        if ok and db.hideDeclined and e.name and ns.declined[e.name] then ok = false end
        if ok then ns.filtered[#ns.filtered + 1] = e end
    end
    table.sort(ns.filtered, SORTS[db.sort] or SORTS.DEFAULT)
end

-- Your own selected roles from the game's role picker, if it has one.
function ns.GetMyRoles()
    local r = Call(C_LFGListRoles and C_LFGListRoles.GetRoles)
    if type(r) == "table" then
        return { TANK = r.tank and true or false, HEALER = r.healer and true or false, DAMAGER = r.dps and true or false }
    end
    return nil
end

-- ---------------------------------------------------------------- actions
function ns.Whisper(name)
    if not name then return end
    if ChatFrameUtil and ChatFrameUtil.SendTell then
        ChatFrameUtil.SendTell(name)
    elseif ChatFrame_SendTell then
        ChatFrame_SendTell(name)
    end
end

-- Same call either way - if we're not the leader/assist, the game itself
-- relays this to the leader as a suggestion instead of a direct invite
-- (the same behavior as the built-in social menu / player frame "Invite").
function ns.Invite(name)
    if not name then return end
    if ns.GroupIsFull() then
        ns.Print("Your " .. (IsInRaid() and "raid" or "group") .. " is full.")
        return
    end
    if C_PartyInfo and C_PartyInfo.InviteUnit then
        C_PartyInfo.InviteUnit(name)
    elseif InviteUnit then
        InviteUnit(name)
    end
    if ns.CanInvite() then
        ns.Print("Invited " .. name .. ".")
    else
        ns.Print("Suggested inviting " .. name .. " to your group leader.")
    end
end

-- The same call as "Request to Join" on a player's right-click menu.
function ns.RequestInvite(name)
    if not name then return end
    local fn = (C_PartyInfo and C_PartyInfo.RequestInviteFromUnit) or _G.RequestInviteFromUnit
    if not fn then
        ns.Print("This client has no Request to Join. Whisper " .. name .. " instead.")
        return
    end
    local ok, err = pcall(fn, name)
    if ok then
        ns.requested[name] = GetTime()
        ns.Print("Asked " .. name .. " to invite you.")
        if IsInGroup() then
            ns.Print("|cffff8800Note:|r you're in a group right now - leave it so their invite can reach you.")
        end
    else
        ns.Print("Request to Join failed: " .. tostring(err))
    end
    if ns.UpdateUI then ns.UpdateUI() end
end

function ns.CanInvite()
    return not IsInGroup() or UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

-- A full party can't become a full raid mid-invite, and a full raid has no
-- more slots, so either way there's no point inviting or suggesting one.
function ns.GroupIsFull()
    local n = GetNumGroupMembers()
    if n == 0 then return false end
    if IsInRaid() then
        return n >= (_G.MAX_RAID_MEMBERS or 40)
    end
    return n >= ((_G.MAX_PARTY_MEMBERS or 4) + 1)
end

-- --------------------------------------------------------------- declines
function ns.MarkDeclined(name)
    if not name then return end
    ns.requested[name] = nil
    ns.declined[name] = GetTime()
    ns.Print(name .. " declined your request to join.")
    if ns.UpdateUI then ns.UpdateUI() end
end

function ns.ClearDeclined(name)
    if name then
        ns.declined[name] = nil
    else
        wipe(ns.declined)
    end
    if ns.UpdateUI then ns.UpdateUI() end
end

-- There's no dedicated event for a declined Request to Join, so we watch
-- the system chat line this server prints for it - "<Name> declines your
-- group invitation request." (confirmed in-game; distinct from Blizzard's
-- own ERR_DECLINE_GROUP_S text for a plain invite decline) - and match the
-- extracted name against who we're waiting on. CHAT_MSG_SYSTEM is
-- client/server generated, never player-authored chat, so this can't be
-- spoofed through a whisper or other chat message.
local DECLINE_PATTERN = "^(.+) declines your group invitation request%.$"

local function CheckDeclineMessage(msg)
    if type(msg) ~= "string" then return end
    local name = msg:match(DECLINE_PATTERN)
    if name and ns.requested[name] then
        ns.MarkDeclined(name)
    end
end

-- ---------------------------------------------------------------- events
local throttle
local function RefreshSoon()
    if throttle then return end
    throttle = true
    C_Timer.After(0.3, function()
        throttle = false
        ns.CollectResults()
        if ns.UpdateUI then ns.UpdateUI() end
    end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
ev:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED")
ev:RegisterEvent("LFG_LIST_SEARCH_FAILED")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("CHAT_MSG_SYSTEM")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        LFGForeverDB = LFGForeverDB or {}
        CopyDefaults(DEFAULTS, LFGForeverDB)
        ns.db = LFGForeverDB
        if ns.InitMinimap then ns.InitMinimap() end
    elseif event == "LFG_LIST_SEARCH_RESULTS_RECEIVED" then
        ns.searching = false
        ns.searchFailed = false
        ns.lastSearch = GetTime()
        ns.CollectResults()
        if ns.UpdateUI then ns.UpdateUI() end
    elseif event == "LFG_LIST_SEARCH_FAILED" then
        ns.searching = false
        ns.searchFailed = true
        if ns.UpdateUI then ns.UpdateUI() end
    elseif event == "LFG_LIST_SEARCH_RESULT_UPDATED" or event == "GROUP_ROSTER_UPDATE" then
        if ns.frame and ns.frame:IsShown() then RefreshSoon() end
    elseif event == "CHAT_MSG_SYSTEM" then
        CheckDeclineMessage(arg1)
    end
end)

-- ----------------------------------------------------------------- toggles
function ns.Toggle()
    if not ns.db then return end
    if not ns.frame then ns.CreateUI() end
    if ns.frame:IsShown() then
        ns.frame:Hide()
    else
        ns.frame:Show()
    end
end

function LFGForever_OnCompartmentClick()
    ns.Toggle()
end

SLASH_LFGFOREVER1 = "/lfg"
SLASH_LFGFOREVER2 = "/groupfinder"
SlashCmdList.LFGFOREVER = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "minimap" then
        ns.db.minimap.hide = not ns.db.minimap.hide
        if ns.UpdateMinimap then ns.UpdateMinimap() end
        ns.Print("Minimap button " .. (ns.db.minimap.hide and "hidden" or "shown") .. ".")
    elseif msg == "reset" then
        ns.db.point = nil
        if ns.frame then
            ns.frame:ClearAllPoints()
            ns.frame:SetPoint("CENTER")
        end
        ns.Print("Window position reset.")
    elseif msg == "cleardeclined" then
        ns.ClearDeclined()
        ns.Print("Cleared all declined listings.")
    elseif msg == "debugzone" then
        local zoneName = ns.CurrentZoneName()
        local chain = ns.CurrentZoneChain()
        local chainList = {}
        for id in pairs(chain) do chainList[#chainList + 1] = tostring(id) end
        ns.Print("Zone: " .. (zoneName ~= "" and zoneName or "?")
            .. "  |  Map chain: " .. (next(chain) and table.concat(chainList, ", ") or "none"))
        ns.EnsureCategory()
        ns.Print("Category: " .. ns.GetCategoryName(ns.db.categoryID))
        for _, a in ipairs(ns.GetActivities(ns.db.categoryID)) do
            local info = ns.GetActivityInfo(a.id)
            local rawMapID = info and info.mapID
            local secret = issecret and issecret(rawMapID)
            ns.Print(a.id .. "  " .. a.name .. "  mapID=" .. tostring(Safe(rawMapID)) .. (secret and " (secret!)" or ""))
        end
    elseif msg == "help" then
        ns.Print("/lfg - open or close the browser. /lfg minimap - show/hide the minimap button. /lfg reset - recenter the window. /lfg cleardeclined - forget all declined listings. /lfg debugzone - print zone/activity map IDs for Titan debugging.")
    else
        ns.Toggle()
    end
end
