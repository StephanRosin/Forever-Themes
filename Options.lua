--[[---------------------------------------------------------------------------
Options.lua -- the pages of the options window (OptionsPanel.lua):
Theme (the central theme and colour, minimap button), Addons (follow or own
theme per registered Forever addon, with its theme now), Blizzard's windows
(one switch per skin) and Blizzard's texts (the font bridges). Built when
the window is made, not at login: InfoPanel registers Bartender in its own
PLAYER_LOGIN, after ours.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local L = ns.L
local Lib = LibForeverThemes
local Themes, Hub = ns.Themes, ns.Hub

local FOLLOW, OWN = "FOLLOW", "OWN"
local SKINS = { "CharacterSkin", "SpellbookSkin", "TalentsSkin", "ProfessionsSkin", "LegacySkin", "CommunitiesSkin",
    "CollectionsSkin" }
local SKIN_LABELS = { CharacterSkin = "OPT_SKIN_CHARACTER", SpellbookSkin = "OPT_SKIN_SPELLBOOK",
    TalentsSkin = "OPT_SKIN_TALENTS", ProfessionsSkin = "OPT_SKIN_PROFESSIONS", LegacySkin = "OPT_SKIN_LEGACY",
    CommunitiesSkin = "OPT_SKIN_COMMUNITIES", CollectionsSkin = "OPT_SKIN_COLLECTIONS" }

function ns.ThemeName(id) return L["THEME_" .. tostring(id)] end
function ns.ColorName(theme, id) return L["THEME_COLOR_" .. tostring(theme) .. "_" .. tostring(id)] end

-- "Pitwall, Red" (the colour left out where there is none).
function ns.ThemeLabel(theme, color)
    if not color then return ns.ThemeName(theme) end
    return L.THEME_AND_COLOR:format(ns.ThemeName(theme), ns.ColorName(theme, color))
end

-- The theme menu: base themes only, an HD theme shows as its base (its
-- colours are in the colour menu). Stored ids keep their meaning.
local function themeChoices()
    local list = {}
    for _, id in ipairs(Lib.MenuIds(Themes.IDS)) do list[#list + 1] = { value = id, label = ns.ThemeName(id) } end
    return list
end

function ns.ThemeChoice() return Lib.BaseTheme(Themes.Current()) end

-- The colour menu (here and Menu.lua): the base's colours, then its HD
-- theme's as "HD Carbon"; values Lib.MenuValue ("TECH_HD:CARBON").
function ns.ColorChoices()
    local list = {}
    for _, e in ipairs(Lib.MenuColors(Themes.SPECS, Themes.Current())) do
        local label = ns.ColorName(e.theme, e.color)
        list[#list + 1] = { value = Lib.MenuValue(e.theme, e.color), label = e.hd and "HD " .. label or label }
    end
    return list
end

function ns.ColorChoice() return Lib.MenuValue(Themes.Current(), Themes.Color()) end

-- Colour first, then the theme: one change for the addons, not a switch
-- with the old colour followed by the new one.
function ns.ChooseColor(value)
    local theme, color = Lib.ParseMenuValue(value)
    if Themes.SetColor(color, theme) then Themes.Switch(theme) end
end

local function themePage(spec)
    spec[#spec + 1] = { type = "tab", label = "TAB_THEME" }
    spec[#spec + 1] = { type = "header", label = "HEADER_THEME" }
    spec[#spec + 1] = { type = "select", label = "OPT_THEME", hint = "HINT_THEME", choices = themeChoices,
        get = ns.ThemeChoice, set = function(v) Themes.Switch(v) end }
    spec[#spec + 1] = { type = "select", label = "OPT_COLOR", choices = ns.ColorChoices,
        visible = function() return #Themes.Colors() > 0 end,
        get = ns.ColorChoice, set = ns.ChooseColor }
    spec[#spec + 1] = { type = "check", label = "OPT_MINIMAP",
        get = function() return ns.MinimapButton.Get("show") end,
        set = function(v) ns.MinimapButton.Set("show", v) end }
end

local function addonRow(addon)
    return { type = "select", label = function() return addon.title end,
        hint = function() return L.ADDON_NOW:format(ns.ThemeLabel(Hub.Current(addon))) end,
        choices = { { value = FOLLOW, label = L.FOLLOW }, { value = OWN, label = L.OWN } },
        get = function() return Hub.Follows(addon.folder) and FOLLOW or OWN end,
        set = function(v)
            Hub.SetFollows(addon.folder, v == FOLLOW)
            ns.RefreshOptions()
        end }
end

local function addonsPage(spec)
    spec[#spec + 1] = { type = "tab", label = "TAB_ADDONS" }
    local addons = Hub.Addons()
    spec[#spec + 1] = { type = "header", label = #addons > 0 and "HEADER_ADDONS" or "ADDONS_NONE" }
    for _, addon in ipairs(addons) do spec[#spec + 1] = addonRow(addon) end
end

local function windowsPage(spec)
    spec[#spec + 1] = { type = "tab", label = "TAB_WINDOWS" }
    spec[#spec + 1] = { type = "header", label = "HEADER_WINDOWS" }
    for _, name in ipairs(SKINS) do
        local skin = ns[name]
        spec[#spec + 1] = { type = "check", label = SKIN_LABELS[name], tooltip = "TIP_WINDOWS",
            get = skin.Enabled, set = skin.SetEnabled }
    end
end

local function textsPage(spec)
    spec[#spec + 1] = { type = "tab", label = "TAB_TEXTS" }
    spec[#spec + 1] = { type = "header", label = "HEADER_TEXTS" }
    spec[#spec + 1] = { type = "check", label = "OPT_BLIZZARD_TEXTS", hint = "HINT_BLIZZARD_TEXTS",
        tooltip = "TIP_BLIZZARD_TEXTS", get = ns.BlizzardFonts.Enabled, set = ns.BlizzardFonts.SetEnabled }
    spec[#spec + 1] = { type = "check", label = "OPT_PLATYNATOR", hint = "HINT_PLATYNATOR",
        tooltip = "TIP_PLATYNATOR", get = ns.PlatynatorFonts.Enabled, set = ns.PlatynatorFonts.SetEnabled }
end

function ns.OptionsSpec()
    local spec = {}
    themePage(spec)
    addonsPage(spec)
    windowsPage(spec)
    textsPage(spec)
    return spec
end

ns.BuildOptions(ns.OptionsSpec)
-- The theme changed (here, the menu, the minimap button): the window shows it.
ns.Settings.OnChange(function() ns.RefreshOptions() end)
