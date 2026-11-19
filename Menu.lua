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
    -- HD themes are colours of their base (Options.lua).
    for _, id in ipairs(LibForeverThemes.MenuIds(Themes.IDS)) do
        root:CreateRadio(ns.ThemeName(id), function() return ns.ThemeChoice() == id end,
            function() ns.ChooseTheme(id) end)
    end
    local colors = ns.ColorChoices()
    if #colors > 0 then
        local sub = root:CreateButton(L.OPT_COLOR)
        for _, c in ipairs(colors) do
            sub:CreateRadio(c.label, function() return ns.ColorChoice() == c.value end,
                function() ns.ChooseColor(c.value) end)
        end
    end
    root:CreateDivider()
    root:CreateButton(L.MENU_OPTIONS, function() ns.Window.Open() end)
end

-- Owned by anchor (any frame; the menu opens at the cursor); without
-- Blizzard_Menu the options open instead.
function Menu.Open(anchor)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        ns.Window.Open()
        return
    end
    MenuUtil.CreateContextMenu(anchor or UIParent, function(_, root) Menu.Fill(root) end)
end
