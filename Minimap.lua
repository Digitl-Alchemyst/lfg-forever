-- LFG Forever: minimap button (drag to move around the edge).
local ADDON, ns = ...

local btn

local function Menu(owner, generator)
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(owner, generator)
    else
        ns.Print("Menus aren't available on this client.")
    end
end

local function ShowSettingsMenu(owner)
    if not ns.db then return end
    Menu(owner, function(_, root)
        root:CreateTitle("LFG Forever Settings")
        root:CreateCheckbox("Zone entry notifications", function() return ns.db.zoneNotify end, function()
            ns.db.zoneNotify = not ns.db.zoneNotify
            return MenuResponse and MenuResponse.Refresh
        end)
        root:CreateCheckbox("Hide minimap button", function() return ns.db.minimap.hide end, function()
            ns.db.minimap.hide = not ns.db.minimap.hide
            ns.UpdateMinimap()
            return MenuResponse and MenuResponse.Refresh
        end)
        root:CreateDivider()
        root:CreateButton("Open window", function() ns.Toggle() end)
    end)
end

local function Place()
    local angle = math.rad(ns.db.minimap.angle or 215)
    local r = (Minimap:GetWidth() / 2) + 5
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale
    ns.db.minimap.angle = math.deg(math.atan2(py - my, px - mx)) % 360
    Place()
end

function ns.UpdateMinimap()
    if not btn then return end
    if ns.db.minimap.hide then btn:Hide() else btn:Show(); Place() end
end

function ns.InitMinimap()
    if btn then return end
    btn = CreateFrame("Button", "LFGForeverMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", 7, -5)

    -- First frame of the game's animated LFG eye (512x256 sheet of 64x64).
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\LFGFrame\\LFG-Eye")
    icon:SetTexCoord(0, 0.125, 0, 0.25)
    icon:SetSize(22, 22)
    icon:SetPoint("TOPLEFT", 5, -4)

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    btn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            ShowSettingsMenu(self)
        else
            ns.Toggle()
        end
    end)
    btn:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", OnDragUpdate) end)
    btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("LFG Forever")
        GameTooltip:AddLine("Left-click: open the group browser", 1, 1, 1)
        GameTooltip:AddLine("Right-click: settings", 1, 1, 1)
        GameTooltip:AddLine("Drag: move this button", 1, 1, 1)
        GameTooltip:AddLine("/lfg also opens it", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    ns.UpdateMinimap()
end
