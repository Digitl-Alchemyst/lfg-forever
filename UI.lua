-- LFG Forever: the browser window.
local ADDON, ns = ...

local ROW_HEIGHT = 36
local NUM_ROWS = 11
local WIDTH, HEIGHT = 720, 560

local ROLE_ATLAS = {
    TANK = "groupfinder-icon-role-large-tank",
    HEALER = "groupfinder-icon-role-large-heal",
    DAMAGER = "groupfinder-icon-role-large-dps",
}
local ROLE_TEX = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
local ROLE_COORDS = {
    TANK = { 0, 19 / 64, 22 / 64, 41 / 64 },
    HEALER = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 },
    DAMAGER = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 },
}

local function HasAtlas(name)
    if C_Texture and C_Texture.GetAtlasInfo then
        return C_Texture.GetAtlasInfo(name) ~= nil
    end
    return false
end

local function SetRoleIcon(tex, role)
    if HasAtlas(ROLE_ATLAS[role]) then
        tex:SetAtlas(ROLE_ATLAS[role], false)
    else
        tex:SetTexture(ROLE_TEX)
        tex:SetTexCoord(unpack(ROLE_COORDS[role]))
    end
end

local function SetClassIcon(tex, classFile)
    tex:SetTexCoord(0, 1, 0, 1)
    if classFile and HasAtlas("groupfinder-icon-class-" .. classFile:lower()) then
        tex:SetAtlas("groupfinder-icon-class-" .. classFile:lower(), false)
    elseif classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile] then
        tex:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
        tex:SetTexCoord(unpack(CLASS_ICON_TCOORDS[classFile]))
    else
        tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end
end

local function PartyIcon(tex)
    tex:SetTexCoord(0, 1, 0, 1)
    if HasAtlas("groupfinder-icon-friend") then
        tex:SetAtlas("groupfinder-icon-friend", false)
    else
        tex:SetTexture("Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon")
    end
end

local function ClassColor(classFile)
    local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if c then return c.r, c.g, c.b end
    return 1, 0.82, 0
end

local function ColorName(name, classFile)
    local r, g, b = ClassColor(classFile)
    return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, name or "?")
end

local function Menu(owner, generator)
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(owner, generator)
    else
        ns.Print("Menus aren't available on this client.")
    end
end

local function Button(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, h or 22)
    b:SetText(text)
    return b
end

local function Label(parent, text, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormalSmall")
    fs:SetText(text)
    return fs
end

local function EditBox(parent, w, numeric)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(w, 20)
    e:SetAutoFocus(false)
    if numeric then e:SetNumeric(true); e:SetMaxLetters(2) end
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return e
end

-- ------------------------------------------------------------------ tooltip
local function ShowTooltip(row)
    local e = row.entry
    if not e then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(ColorName(e.name, e.classFile) .. (e.level and ("  |cffaaaaaaLvl " .. e.level .. "|r") or ""))
    if e.delisted then GameTooltip:AddLine("Delisted", 1, 0.2, 0.2) end
    if e.activityIDs and #e.activityIDs > 0 then
        for _, a in ipairs(e.activityIDs) do GameTooltip:AddLine(ns.GetActivityName(a), 0.8, 0.8, 0.8) end
    end
    if e.area then GameTooltip:AddLine("Zone: " .. e.area, 0.7, 0.7, 0.7) end
    if e.comment ~= "" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("\"" .. e.comment .. "\"", 1, 1, 1, true)
    end
    if e.isSolo then
        if e.roles then
            local r = {}
            for _, role in ipairs(ns.ROLES) do if e.roles[role] then r[#r + 1] = ns.ROLE_NAMES[role] end end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Can play: " .. (#r > 0 and table.concat(r, ", ") or "not set"), 0.4, 1, 0.4)
        end
    else
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(e.numMembers .. " members:", 1, 0.82, 0)
        for _, m in ipairs(e.members) do
            local role = m.role and ns.ROLE_NAMES[m.role] or ""
            GameTooltip:AddDoubleLine((m.isLeader and "* " or "") .. ColorName(m.name, m.classFile) .. (m.level and (" " .. m.level) or ""), role, 1, 1, 1, 0.7, 0.7, 0.7)
        end
        if e.counts then
            local need = {}
            for _, role in ipairs(ns.ROLES) do
                local rem = e.counts[role .. "_REMAINING"]
                if rem and rem > 0 then need[#need + 1] = rem .. " " .. ns.ROLE_NAMES[role] end
            end
            if #need > 0 then GameTooltip:AddLine("Needs: " .. table.concat(need, ", "), 0.4, 1, 0.4) end
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Right-click for options", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

-- ------------------------------------------------------------ row actions
local function OpenRowMenu(row)
    local e = row.entry
    if not e or not e.name then return end
    Menu(row, function(_, root)
        root:CreateTitle(e.name)
        root:CreateButton("Whisper", function() ns.Whisper(e.name) end)
        if e.isSolo then
            local b = root:CreateButton("Invite to group", function() ns.Invite(e.name) end)
            if b.SetEnabled then b:SetEnabled(ns.CanInvite() and not e.hasSelf) end
        else
            local b = root:CreateButton("Request to Join", function() ns.RequestInvite(e.name) end)
            if b.SetEnabled then b:SetEnabled(not e.hasSelf) end
        end
        root:CreateButton("Who is " .. e.name .. "?", function()
            if C_FriendList and C_FriendList.SendWho then C_FriendList.SendWho("n-\"" .. e.name .. "\"") end
        end)
    end)
end

local function DoRowAction(row)
    local e = row.entry
    if not e or not e.name then return end
    if e.isSolo then ns.Invite(e.name) else ns.RequestInvite(e.name) end
end

-- --------------------------------------------------------------- rows
local function CreateRow(parent, i)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0.0)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(24, 24)
    row.icon:SetPoint("LEFT", 6, 0)

    row.name = Label(row, "", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, 2)
    row.name:SetWidth(160); row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)

    row.level = Label(row, "", "GameFontHighlightSmall")
    row.level:SetPoint("TOPLEFT", 205, -5)

    row.activity = Label(row, "", "GameFontDisableSmall")
    row.activity:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 6, -2)
    row.activity:SetWidth(210); row.activity:SetJustifyH("LEFT"); row.activity:SetWordWrap(false)

    -- Role area: three icons with a count each.
    row.roleIcons, row.roleText = {}, {}
    for j, role in ipairs(ns.ROLES) do
        local t = row:CreateTexture(nil, "ARTWORK")
        t:SetSize(18, 18)
        t:SetPoint("LEFT", 250 + (j - 1) * 42, 0)
        SetRoleIcon(t, role)
        row.roleIcons[role] = t
        local fs = Label(row, "", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", t, "RIGHT", 1, 0)
        row.roleText[role] = fs
    end

    row.comment = Label(row, "", "GameFontHighlightSmall")
    row.comment:SetPoint("LEFT", 382, 0)
    row.comment:SetWidth(145); row.comment:SetHeight(ROW_HEIGHT - 4)
    row.comment:SetJustifyH("LEFT"); row.comment:SetJustifyV("MIDDLE")
    if row.comment.SetMaxLines then row.comment:SetMaxLines(2) end

    row.action = Button(row, "Invite", 74, 20)
    row.action:SetPoint("RIGHT", -4, 0)
    row.action:SetScript("OnClick", function() DoRowAction(row) end)

    row.whisper = Button(row, "Whisper", 64, 20)
    row.whisper:SetPoint("RIGHT", row.action, "LEFT", -2, 0)
    row.whisper:SetScript("OnClick", function() if row.entry then ns.Whisper(row.entry.name) end end)

    row:SetScript("OnClick", function(self, btn)
        if btn == "RightButton" then OpenRowMenu(self) end
    end)
    row:SetScript("OnDoubleClick", function(self) if self.entry then ns.Whisper(self.entry.name) end end)
    row:SetScript("OnEnter", ShowTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

local function UpdateRow(row, e)
    row.entry = e
    if not e then row:Hide(); return end
    row:Show()
    local dim = e.delisted
    if e.isSolo then SetClassIcon(row.icon, e.classFile) else PartyIcon(row.icon) end
    row.icon:SetDesaturated(dim)

    row.name:SetText(e.name or "?")
    if dim then row.name:SetTextColor(0.5, 0.5, 0.5) else row.name:SetTextColor(ClassColor(e.classFile)) end
    row.level:SetText(e.level and ("Lvl " .. e.level) or "")

    local act = e.hasSelf and "|cff66ff66Your listing|r" or (e.activityText or "")
    if not e.isSolo then act = e.numMembers .. " players - " .. act end
    row.activity:SetText(act)

    for _, role in ipairs(ns.ROLES) do
        local icon, fs = row.roleIcons[role], row.roleText[role]
        if e.isSolo then
            local has = e.roles and e.roles[role]
            icon:SetShown(has and true or false)
            icon:SetDesaturated(dim)
            fs:SetText("")
        else
            local have = e.counts and e.counts[role] or 0
            local rem = e.counts and e.counts[role .. "_REMAINING"]
            icon:Show()
            icon:SetDesaturated(dim or (rem ~= nil and rem <= 0))
            if rem ~= nil then
                local color = rem > 0 and "|cff66ff66" or "|cff888888"
                fs:SetText(color .. have .. "/" .. (have + rem) .. "|r")
            else
                fs:SetText(tostring(have))
            end
        end
    end

    row.comment:SetText(e.comment or "")
    if dim then row.comment:SetTextColor(0.5, 0.5, 0.5) else row.comment:SetTextColor(0.9, 0.9, 0.9) end

    if e.isSolo then
        row.action:SetText("Invite")
        row.action:SetEnabled(ns.CanInvite() and not e.hasSelf and not dim)
    else
        local sent = e.name and ns.requested[e.name] and (GetTime() - ns.requested[e.name] < 120)
        row.action:SetText(sent and "Requested" or "Request")
        row.action:SetEnabled(not e.hasSelf and not dim)
    end
    row.whisper:SetEnabled(not e.hasSelf and e.name ~= nil)
end

-- --------------------------------------------------------------- window
function ns.CreateUI()
    local db = ns.db
    local f = CreateFrame("Frame", "LFGForeverFrame", UIParent, "BasicFrameTemplateWithInset")
    ns.frame = f
    f:SetSize(WIDTH, HEIGHT)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        db.point = { p, rp, x, y }
    end)
    if db.point then
        f:SetPoint(db.point[1], UIParent, db.point[2], db.point[3], db.point[4])
    else
        f:SetPoint("CENTER")
    end
    tinsert(UISpecialFrames, "LFGForeverFrame")
    f:Hide()

    local title = f.TitleText or f.title
    if not title then
        title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("TOP", 0, -5)
    end
    title:SetText("LFG Forever")

    -- ---- row 1: category, activity, search
    local cat = Button(f, "", 150)
    cat:SetPoint("TOPLEFT", 14, -32)
    f.category = cat
    cat:SetScript("OnClick", function(self)
        Menu(self, function(_, root)
            root:CreateTitle("Category")
            for _, c in ipairs(ns.GetCategories()) do
                root:CreateRadio(c.name, function() return db.categoryID == c.id end, function()
                    if db.categoryID ~= c.id then
                        db.categoryID = c.id
                        wipe(db.activityIDs)
                    end
                    ns.UpdateUI()
                end)
            end
        end)
    end)

    local act = Button(f, "", 260)
    act:SetPoint("LEFT", cat, "RIGHT", 6, 0)
    f.activity = act
    act:SetScript("OnClick", function(self)
        ns.EnsureCategory()
        Menu(self, function(_, root)
            root:CreateTitle("Activities (none ticked = all)")
            root:CreateButton("Clear (search everything)", function() wipe(db.activityIDs); ns.UpdateUI() end)
            root:CreateDivider()
            for _, a in ipairs(ns.GetActivities(db.categoryID)) do
                local label = a.name
                if a.minLevel and a.minLevel > 0 then
                    label = label .. "  |cff888888(" .. a.minLevel .. (a.maxLevel and a.maxLevel > 0 and ("-" .. a.maxLevel) or "+") .. ")|r"
                end
                root:CreateCheckbox(label, function() return tContains(db.activityIDs, a.id) end, function()
                    for i, id in ipairs(db.activityIDs) do
                        if id == a.id then table.remove(db.activityIDs, i); ns.UpdateUI(); return MenuResponse and MenuResponse.Refresh end
                    end
                    tinsert(db.activityIDs, a.id)
                    ns.UpdateUI()
                    return MenuResponse and MenuResponse.Refresh
                end)
            end
        end)
    end)

    local search = Button(f, "Search", 100, 24)
    search:SetPoint("TOPRIGHT", -14, -31)
    search:SetScript("OnClick", function() ns.Search() end)
    f.search = search

    f.status = Label(f, "", "GameFontHighlightSmall")
    f.status:SetPoint("RIGHT", search, "LEFT", -10, 0)
    f.status:SetJustifyH("RIGHT")

    -- ---- row 2: show type + role filters
    local showLbl = Label(f, "Show:")
    showLbl:SetPoint("TOPLEFT", 16, -66)
    f.showButtons = {}
    local prev
    for _, key in ipairs({ "ALL", "GROUPS", "PLAYERS" }) do
        local text = key == "ALL" and "All" or (key == "GROUPS" and "Groups" or "Players")
        local b = Button(f, text, 70, 20)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 2, 0) else b:SetPoint("LEFT", showLbl, "RIGHT", 6, 0) end
        b:SetScript("OnClick", function() db.show = key; ns.UpdateUI() end)
        f.showButtons[key] = b
        prev = b
    end

    local roleLbl = Label(f, "Role:")
    roleLbl:SetPoint("LEFT", prev, "RIGHT", 18, 0)
    f.roleButtons = {}
    prev = roleLbl
    for _, role in ipairs(ns.ROLES) do
        local b = CreateFrame("Button", nil, f)
        b:SetSize(26, 26)
        b:SetPoint("LEFT", prev, "RIGHT", prev == roleLbl and 6 or 4, 0)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        SetRoleIcon(b.icon, role)
        b.ring = b:CreateTexture(nil, "OVERLAY")
        b.ring:SetPoint("TOPLEFT", -4, 4); b.ring:SetPoint("BOTTOMRIGHT", 4, -4)
        b.ring:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        b.ring:SetBlendMode("ADD")
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        b:SetScript("OnClick", function() db.roles[role] = not db.roles[role]; ns.UpdateUI() end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(ns.ROLE_NAMES[role])
            GameTooltip:AddLine("Players who can play this role, and groups with a free " .. ns.ROLE_NAMES[role] .. " spot.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f.roleButtons[role] = b
        prev = b
    end

    local mine = Button(f, "My roles", 76, 20)
    mine:SetPoint("LEFT", prev, "RIGHT", 8, 0)
    mine:SetScript("OnClick", function()
        local r = ns.GetMyRoles()
        if r then
            for k, v in pairs(r) do db.roles[k] = v end
        else
            ns.Print("Couldn't read your roles; pick them with the role icons.")
        end
        ns.UpdateUI()
    end)
    local clearRoles = Button(f, "Any", 46, 20)
    clearRoles:SetPoint("LEFT", mine, "RIGHT", 2, 0)
    clearRoles:SetScript("OnClick", function()
        for _, r in ipairs(ns.ROLES) do db.roles[r] = false end
        ns.UpdateUI()
    end)

    -- ---- row 3: level, text, delisted, sort
    local lvlLbl = Label(f, "Level:")
    lvlLbl:SetPoint("TOPLEFT", 16, -98)
    local minL = EditBox(f, 28, true)
    minL:SetPoint("LEFT", lvlLbl, "RIGHT", 10, 0)
    local dash = Label(f, "-", "GameFontHighlight")
    dash:SetPoint("LEFT", minL, "RIGHT", 2, 0)
    local maxL = EditBox(f, 28, true)
    maxL:SetPoint("LEFT", dash, "RIGHT", 8, 0)
    local function LevelChanged()
        db.minLevel = tonumber(minL:GetText())
        db.maxLevel = tonumber(maxL:GetText())
        ns.UpdateUI()
    end
    minL:SetScript("OnTextChanged", function(_, user) if user then LevelChanged() end end)
    maxL:SetScript("OnTextChanged", function(_, user) if user then LevelChanged() end end)
    f.minLevel, f.maxLevel = minL, maxL
    local nearMe = Button(f, "Near me", 64, 20)
    nearMe:SetPoint("LEFT", maxL, "RIGHT", 4, 0)
    nearMe:SetScript("OnClick", function()
        local lvl = UnitLevel("player")
        db.minLevel, db.maxLevel = math.max(1, lvl - 3), lvl + 3
        minL:SetText(db.minLevel); maxL:SetText(db.maxLevel)
        ns.UpdateUI()
    end)
    nearMe:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Only show players / leaders within 3 levels of you")
        GameTooltip:Show()
    end)
    nearMe:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local findLbl = Label(f, "Filter:")
    findLbl:SetPoint("LEFT", nearMe, "RIGHT", 14, 0)
    local find = EditBox(f, 150)
    find:SetPoint("LEFT", findLbl, "RIGHT", 10, 0)
    find:SetScript("OnTextChanged", function(self) db.text = self:GetText(); ns.UpdateUI() end)
    find:SetScript("OnEnterPressed", function(self) self:ClearFocus(); ns.Search() end)
    f.find = find

    local delisted = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    delisted:SetSize(24, 24)
    delisted:SetPoint("LEFT", find, "RIGHT", 10, 0)
    local dl = Label(delisted, "Hide delisted", "GameFontHighlightSmall")
    dl:SetPoint("LEFT", delisted, "RIGHT", 0, 1)
    delisted:SetScript("OnClick", function(self) db.hideDelisted = self:GetChecked() and true or false; ns.UpdateUI() end)
    f.delisted = delisted

    local sort = Button(f, "", 120, 20)
    sort:SetPoint("TOPRIGHT", -14, -96)
    sort:SetScript("OnClick", function(self)
        Menu(self, function(_, root)
            root:CreateTitle("Sort by")
            for _, key in ipairs(ns.SORT_ORDER) do
                root:CreateRadio(ns.SORT_NAMES[key], function() return db.sort == key end, function() db.sort = key; ns.UpdateUI() end)
            end
        end)
    end)
    f.sort = sort

    -- ---- list
    local list = CreateFrame("Frame", nil, f)
    list:SetPoint("TOPLEFT", 10, -146)
    list:SetPoint("BOTTOMRIGHT", -30, 38)
    f.list = list

    local hdr = {
        { "Name / activity", 36 }, { "Level", 205 }, { "Roles", 250 }, { "Comment", 382 },
    }
    for _, h in ipairs(hdr) do
        local fs = Label(f, h[1], "GameFontNormalSmall")
        fs:SetPoint("BOTTOMLEFT", list, "TOPLEFT", h[2], 4)
    end

    f.rows = {}
    for i = 1, NUM_ROWS do f.rows[i] = CreateRow(list, i) end

    local slider = CreateFrame("Slider", nil, f)
    slider:SetPoint("TOPLEFT", list, "TOPRIGHT", 6, 0)
    slider:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 6, 0)
    slider:SetWidth(14)
    slider:SetOrientation("VERTICAL")
    slider:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0, 0, 0, 0.35)
    slider:SetMinMaxValues(0, 0)
    slider:SetValueStep(1)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    slider:SetValue(0)
    slider:SetScript("OnValueChanged", function(_, v)
        f.offset = math.floor(v + 0.5)
        ns.UpdateRows()
    end)
    f.slider = slider
    f.offset = 0

    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        local _, max = slider:GetMinMaxValues()
        slider:SetValue(math.max(0, math.min(max, f.offset - delta * 3)))
    end)

    f.empty = Label(list, "", "GameFontDisableLarge")
    f.empty:SetPoint("CENTER", 0, 20)
    f.empty:SetWidth(500)

    -- ---- footer
    f.count = Label(f, "", "GameFontHighlightSmall")
    f.count:SetPoint("BOTTOMLEFT", 16, 14)
    local hint = Label(f, "Right-click a listing for Whisper / Invite / Request to Join.  Double-click to whisper.", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMRIGHT", -16, 14)

    f:SetScript("OnShow", function()
        ns.EnsureCategory()
        -- Show whatever the last search returned (yours or the game window's).
        ns.CollectResults()
        ns.UpdateUI()
    end)
end

-- --------------------------------------------------------------- updates
function ns.UpdateRows()
    local f = ns.frame
    if not f then return end
    for i = 1, NUM_ROWS do
        UpdateRow(f.rows[i], ns.filtered[f.offset + i])
    end
end

function ns.UpdateUI()
    local f = ns.frame
    if not f or not f:IsShown() then return end
    local db = ns.db

    f.category:SetText(ns.GetCategoryName(db.categoryID))
    local n = #db.activityIDs
    if n == 0 then
        f.activity:SetText("All activities")
    elseif n == 1 then
        f.activity:SetText(ns.GetActivityName(db.activityIDs[1]))
    else
        f.activity:SetText(n .. " activities")
    end
    f.sort:SetText("Sort: " .. (ns.SORT_NAMES[db.sort] or "?"))

    for key, b in pairs(f.showButtons) do
        if db.show == key then b:LockHighlight() else b:UnlockHighlight() end
    end
    for role, b in pairs(f.roleButtons) do
        local on = db.roles[role]
        b.icon:SetDesaturated(not on)
        b.icon:SetAlpha(on and 1 or 0.45)
        b.ring:SetShown(on)
    end
    if not f.minLevel:HasFocus() then f.minLevel:SetText(db.minLevel and tostring(db.minLevel) or "") end
    if not f.maxLevel:HasFocus() then f.maxLevel:SetText(db.maxLevel and tostring(db.maxLevel) or "") end
    if not f.find:HasFocus() and f.find:GetText() ~= (db.text or "") then f.find:SetText(db.text or "") end
    f.delisted:SetChecked(db.hideDelisted)

    ns.ApplyFilters()

    local total, shown = #ns.results, #ns.filtered
    local max = math.max(0, shown - NUM_ROWS)
    f.slider:SetMinMaxValues(0, max)
    if f.offset > max then f.offset = max end
    f.slider:SetValue(f.offset)
    f.slider:SetShown(max > 0)
    ns.UpdateRows()

    if ns.searching then
        f.status:SetText("|cffffd200Searching...|r")
        f.search:Disable()
    else
        f.search:Enable()
        f.status:SetText(ns.searchFailed and "|cffff4444Search failed - try again|r" or "")
    end

    if ns.searching and total == 0 then
        f.empty:SetText("Searching...")
    elseif total == 0 then
        f.empty:SetText("Press Search to look for groups and players.")
    elseif shown == 0 then
        f.empty:SetText("Nothing matches your filters.")
    else
        f.empty:SetText("")
    end
    if ns.sawSecret then
        f.count:SetText(string.format("Showing %d of %d  |cffff8800(some details are hidden by the game right now, e.g. in combat)|r", shown, total))
    else
        f.count:SetText(string.format("Showing %d of %d", shown, total))
    end
end
