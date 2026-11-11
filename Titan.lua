-- LFG Forever: Titan Panel integration via LibDataBroker-1.1.
-- Titan bridges any registered LDB object into a panel button on its own
-- (see Titan/TitanLDB.lua) - we only need to register one, the same way
-- Socialite does.
local ADDON, ns = ...

local LDB = LibStub and LibStub:GetLibrary("LibDataBroker-1.1", true)
if not LDB then return end

local ICON = "Interface\\LFGFrame\\LFG-Eye"
local ICON_COORDS = { 0, 0.125, 0, 0.25 } -- first frame of the animated sheet, same crop as the minimap button

-- ns.AddZoneMenuItems() is always recomputed fresh against the player's
-- CURRENT zone (not cached), so this menu already reflects zone changes
-- the moment you right-click again - no stale state to refresh here.
local function ShowZoneMenu(owner)
    if not ns.db then return end
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        ns.Toggle()
        return
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        ns.AddZoneMenuItems(root)
        root:CreateDivider()
        local settings = root:CreateButton("Settings")
        ns.AddSettingsMenuItems(settings)
        root:CreateButton("Open window", function() ns.Toggle() end)
    end)
end

local dataobj = LDB:NewDataObject(ADDON, {
    -- "data source" (not "launcher") so Titan defaults new installs to the
    -- left/center side of the bar instead of the right - Titan hardcodes
    -- launchers to start on the right regardless of what we request here.
    type = "data source",
    icon = ICON,
    iconCoords = ICON_COORDS,
    label = "LFG Forever",
    text = "0",
    OnClick = function(self, button)
        if button == "RightButton" then
            ShowZoneMenu(self)
        else
            ns.Toggle()
        end
    end,
    -- Right-click always works (a real click); hover also triggers a search
    -- when db.autoSearch is on - see MaybeAutoSearch in Core.lua for the
    -- known risk (the server can silently drop a non-click search) and how
    -- ns.Search()'s self-heal timeout bounds it.
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("LFG Forever", 1, 0.82, 0)
        ns.AddZoneTooltipLines(tooltip)
        tooltip:AddLine(" ")
        tooltip:AddLine("Left-click: open window.  Right-click: search.", 0.5, 0.5, 0.5)
    end,
})

-- Bar text: "<questing groups>/<dungeon groups>" when the zone has both a
-- matching zone activity and a dungeon; just a single number when only one
-- of the two applies here (no slash when there's nothing to pair it with);
-- plain "0" when neither was found.
function ns.RefreshTitanText()
    if not ns.db then return end
    ns.EnsureCategory()
    local zoneActivity, dungeonActivity = ns.FindZoneAndDungeonActivity(ns.db.categoryID)
    if zoneActivity and dungeonActivity then
        dataobj.text = ns.CountByActivity(zoneActivity.id) .. "/" .. ns.CountByActivity(dungeonActivity.id)
    elseif zoneActivity then
        dataobj.text = tostring(ns.CountByActivity(zoneActivity.id))
    elseif dungeonActivity then
        dataobj.text = tostring(ns.CountByActivity(dungeonActivity.id))
    else
        dataobj.text = "0"
    end
end
