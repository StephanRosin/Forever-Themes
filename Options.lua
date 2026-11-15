--[[---------------------------------------------------------------------------
Options.lua -- the pages of the options window (OptionsPanel.lua):
Theme (the central theme and colour, minimap button), Addons (follow or own
theme per registered Forever addon, with its theme now), Blizzard's windows
(one switch per skin) and Blizzard's texts (the font bridges). Built at
login: every addon has registered by then.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local L = ns.L
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

local function themeChoices()
    local list = {}
    for _, id in ipairs(Themes.IDS) do list[#list + 1] = { value = id, label = ns.ThemeName(id) } end
    return list
end

local function colorChoices()
    local theme, list = Themes.Current(), {}
    for _, id in ipairs(Themes.Colors(theme)) do list[#list + 1] = { value = id, label = ns.ColorName(theme, id) } end
    return list
end

local function themePage(spec)
    spec[#spec + 1] = { type = "tab", label = "TAB_THEME" }
    spec[#spec + 1] = { type = "header", label = "HEADER_THEME" }
    spec[#spec + 1] = { type = "select", label = "OPT_THEME", hint = "HINT_THEME", choices = themeChoices,
        get = Themes.Current, set = function(v) Themes.Switch(v) end }
    spec[#spec + 1] = { type = "select", label = "OPT_COLOR", choices = colorChoices,
        visible = function() return #Themes.Colors() > 0 end,
        get = function() return Themes.Color() end, set = function(v) Themes.SetColor(v) end }
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

ns.On("PLAYER_LOGIN", function() ns.BuildOptions(ns.OptionsSpec()) end)
-- The theme changed (here, the menu, the minimap button): the window shows it.
ns.Settings.OnChange(function() ns.RefreshOptions() end)
