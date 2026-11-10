-- LFG Forever: Titan Panel integration via LibDataBroker-1.1.
-- Titan bridges any registered LDB object into a panel button on its own
-- (see Titan/TitanLDB.lua) - we only need to register one, the same way
-- Socialite does.
local ADDON, ns = ...

local LDB = LibStub and LibStub:GetLibrary("LibDataBroker-1.1", true)
if not LDB then return end

local ICON = "Interface\\LFGFrame\\LFG-Eye"
local ICON_COORDS = { 0, 0.125, 0, 0.25 } -- first frame of the animated sheet, same crop as the minimap button

local function AddActivitySection(tooltip, title, activity)
    if not activity then return end
    tooltip:AddLine(" ")
    tooltip:AddLine(title .. ": " .. activity.name, 1, 0.82, 0)
    local groups, solo = ns.CountByActivity(activity.id)
    if groups == 0 and solo == 0 then
        if ns.searchedActivities[activity.id] then
            tooltip:AddLine("No active listings", 0.6, 0.6, 0.6)
        else
            tooltip:AddLine("Not searched yet - right-click to search", 0.6, 0.6, 0.6, true)
        end
        return
    end
    tooltip:AddLine(groups .. (groups == 1 and " group, " or " groups, ") .. solo .. (solo == 1 and " solo player" or " solo players"), 0.8, 0.8, 0.8)
    local shown = ns.ListByActivity(activity.id, 5)
    for _, e in ipairs(shown) do
        local who = e.isSolo and (e.name or "?") or ((e.name or "?") .. "'s group")
        tooltip:AddDoubleLine(who, e.level and ("Lvl " .. e.level) or "", 1, 1, 1, 0.7, 0.7, 0.7)
    end
    local total = groups + solo
    if total > #shown then
        tooltip:AddLine("+" .. (total - #shown) .. " more", 0.6, 0.6, 0.6)
    end
end

-- Find() is always recomputed fresh against the player's CURRENT zone (not
-- cached), so both the tooltip and this menu already reflect zone changes
-- the moment you hover/right-click again - no stale state to refresh here.
local function ShowZoneMenu(owner)
    if not ns.db then return end
    ns.EnsureCategory()
    local zoneActivity, dungeonActivity, zoneName = ns.FindZoneAndDungeonActivity(ns.db.categoryID)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        ns.Toggle()
        return
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle("LFG Forever")
        if zoneActivity then
            root:CreateButton("Search " .. zoneActivity.name, function() ns.SearchActivity(zoneActivity.id) end)
        end
        if dungeonActivity then
            root:CreateButton("Search " .. dungeonActivity.name, function() ns.SearchActivity(dungeonActivity.id) end)
        end
        if not zoneActivity and not dungeonActivity then
            root:CreateTitle("No activity found for " .. (zoneName ~= "" and zoneName or "this zone"))
        end
        root:CreateDivider()
        root:CreateButton("Open window", function() ns.Toggle() end)
    end)
end

LDB:NewDataObject(ADDON, {
    -- "data source" (not "launcher") so Titan defaults new installs to the
    -- left/center side of the bar instead of the right - Titan hardcodes
    -- launchers to start on the right regardless of what we request here.
    type = "data source",
    icon = ICON,
    iconCoords = ICON_COORDS,
    label = "LFG Forever",
    OnClick = function(self, button)
        if button == "RightButton" then
            ShowZoneMenu(self)
        else
            ns.Toggle()
        end
    end,
    -- Deliberately does NOT trigger a search itself: C_LFGList.Search only
    -- works from a real click (see the note at the top of Core.lua) - a
    -- hover-triggered search was tried here and got silently dropped by
    -- the server, leaving ns.searching stuck true forever. Right-click is
    -- the one reliable trigger, so that's what this points you to.
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("LFG Forever", 1, 0.82, 0)
        if not ns.db then
            tooltip:AddLine("Loading...", 0.6, 0.6, 0.6)
            return
        end
        ns.EnsureCategory()
        local zoneActivity, dungeonActivity, zoneName = ns.FindZoneAndDungeonActivity(ns.db.categoryID)

        if not zoneActivity and not dungeonActivity then
            tooltip:AddLine(" ")
            tooltip:AddLine("No matching activity for " .. (zoneName ~= "" and zoneName or "this zone"), 0.6, 0.6, 0.6)
        else
            AddActivitySection(tooltip, "Zone", zoneActivity)
            AddActivitySection(tooltip, "Dungeon", dungeonActivity)
        end
        if ns.searching then
            tooltip:AddLine(" ")
            tooltip:AddLine("Searching...", 0.6, 0.6, 0.6)
        end
        tooltip:AddLine(" ")
        tooltip:AddLine("Left-click: open window.  Right-click: search.", 0.5, 0.5, 0.5)
    end,
})
