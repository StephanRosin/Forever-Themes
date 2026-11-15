--[[---------------------------------------------------------------------------
Menu.lua -- the theme menu: the central theme, its colour and the way to the
options. Opened by a right-click on the minimap button and by other addons
through LibForeverThemes.Hub().OpenMenu(anchor) (Forever Data Bar's Theme
element). Blizzard_Menu (MenuUtil), as the InfoPanel's theme picker.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local L = ns.L
local Themes = ns.Themes

local Menu = {}
ns.Menu = Menu

-- Fills the menu (Blizzard_Menu: rootDescription).
function Menu.Fill(root)
    root:CreateTitle(L.ADDON_NAME)
    for _, id in ipairs(Themes.IDS) do
        root:CreateRadio(ns.ThemeName(id), function() return Themes.Current() == id end,
            function() Themes.Switch(id) end)
    end
    local theme = Themes.Current()
    local colors = Themes.Colors(theme)
    if #colors > 0 then
        local sub = root:CreateButton(L.OPT_COLOR)
        for _, id in ipairs(colors) do
            sub:CreateRadio(ns.ColorName(theme, id), function() return Themes.Color() == id end,
                function() Themes.SetColor(id) end)
        end
    end
    root:CreateDivider()
    root:CreateButton(L.MENU_OPTIONS, function() ns.Window.Open() end)
end

-- At anchor (a frame); without Blizzard_Menu the options open instead.
function Menu.Open(anchor)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        ns.Window.Open()
        return
    end
    MenuUtil.CreateContextMenu(anchor, function(_, root) Menu.Fill(root) end)
end
