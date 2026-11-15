--[[---------------------------------------------------------------------------
Skins/Talents.lua -- Blizzard's talent window in the central theme.
Option "Theme Blizzard's talent window" (options, Blizzard's windows),
account-wide (default: Core.lua, Migrate.lua). Built like Skins/Character.lua.

Forever 1.60.1 (Camelot) has no talent window of its own: spellbook and
talents share PlayerSpellsFrame (Blizzard_PlayerSpells, loads on demand;
Camelot/Blizzard_PlayerSpellsFrame.xml), the talents are its child
TalentsFrame (Camelot/ClassTalents/Blizzard_ClassTalentsFrame.xml). The
spellbook module themes the outer frame (ring, title strip, Pitwall wedge,
close, portrait, title). Here only the talent tab's content:
  - Theme tile with tint and dark fill like the Forever addons' panels under
    the talent tree; Blizzard's background, class image and inset hidden.
    The pulsing copies of the class image (OverlayBackground*) run on
    Blizzard's animations, which set the alpha: they are tinted black, and
    black stays invisible with additive blending.
  - Dividers between the trees in the theme's line colour.
  - Header per tree: name in the theme font and accent, point count in the
    text font, ring around the icon in the icon colour, number box grey.
  - Specialization tabs: grey, selection and hover in the icon colour.
  - "Active" in the text font (if that is Friz, in the title font),
    "Unspent points" in the text font.
Blizzard's stays: talent buttons and lines, clouds/particles/activation
effects, search box, loadout dropdown, buttons (apply, reset, undo), the
point display's box, numbers.

Classic or option off: everything as Blizzard built it (Skin.Restore).

Refreshed on every show of the tab (one frame later: Blizzard only creates
the tree headers in OnShow) and when theme, colour or option change. Only
our own textures (no frames), tint, fonts, alpha: that may run in combat,
the window is not protected.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local Themes, Skin = ns.Themes, ns.Skin

local TalentsSkin = {}
ns.TalentsSkin = TalentsSkin

local BLIZZARD_ADDON = "Blizzard_PlayerSpells"
local TAB_TINT = { 0.3, 0.3, 0.3, 1 }
local BLACK = { 0, 0, 0, 1 }
local BODY_FONT = "Friz Quadrata"
local HIDDEN = { "Background", "ClassBackground", "BackgroundBorder" }
-- Blended additively and faded in by Blizzard's animations.
local PULSING = { "OverlayBackgroundRight", "OverlayBackgroundMid" }
local DIVIDERS = { "DividerHorizontalLeft", "DividerHorizontalRight", "DividerVerticalLeft", "DividerVerticalRight" }
-- TabSystemButtonArtTemplate (Blizzard_SharedXML/Shared/TabSystem).
local TAB_BACK = { "Left", "Middle", "Right" }
local TAB_ACCENT = { "LeftActive", "MiddleActive", "RightActive", "LeftHighlight", "MiddleHighlight", "RightHighlight" }

local L_OPTION = {
    enUS = "Theme Blizzard's talent window",
    deDE = "Blizzards Talentfenster im Theme",
    esES = "Aplicar el tema a la ventana de talentos",
    frFR = "Appliquer le thème à la fenêtre des talents",
}
for code, text in pairs(L_OPTION) do
    if ns.Locales[code] then ns.Locales[code].OPT_SKIN_TALENTS = text end
end

local rec = Skin.NewRecord()
local back, shade
local loggedIn

local function talents() return _G.PlayerSpellsFrame and _G.PlayerSpellsFrame.TalentsFrame end

function TalentsSkin.Enabled()
    return _G.ForeverThemesDB ~= nil and _G.ForeverThemesDB.skinTalents == true
end

local function active()
    return TalentsSkin.Enabled() and Themes.Current() ~= Themes.CLASSIC
end

-- As in Character.lua: theme fonts only for Latin clients; Friz as the
-- text font means "Blizzard's font stays".
local function fonts()
    if not LibForeverThemes.LatinClient() then return nil, nil end
    local spec = Themes.Spec(Themes.Current())
    local body = spec.bodyFont or spec.font
    return spec.font, body ~= BODY_FONT and body or nil
end

local function titleStyle()
    local look = Themes.Spec(Themes.Current()).look
    local c = Themes.Accent(look.headerColor or ns.Settings.DEFAULTS.headerColor)
    return look.headerFlag or "OUTLINE", { c[1], c[2], c[3], 1 }
end

-- Tile and dark fill like Skin.PaintArt, without ring and title strip
-- (those belong to the outer frame).
local function paintBack()
    local spec = Themes.Spec(Themes.Current())
    local color = spec.art and spec.art.contentShade
    ns.Media.ThemeBackground(back, spec.art)
    back:Show()
    shade:SetShown(color ~= nil)
    if color then shade:SetColorTexture(color[1], color[2], color[3], color[4]) end
end

local function skinFrameArt(frame, line)
    for _, key in ipairs(HIDDEN) do Skin.Hide(rec, frame[key]) end
    for _, key in ipairs(PULSING) do Skin.Tint(rec, frame[key], BLACK) end
    for _, key in ipairs(DIVIDERS) do Skin.Tint(rec, frame[key], line, true) end
end

local function skinTabs(frame, accent)
    local tabs = frame.TabSystem and frame.TabSystem.tabs
    for _, tab in ipairs(tabs or {}) do
        for _, key in ipairs(TAB_BACK) do Skin.Tint(rec, tab[key], TAB_TINT, true) end
        for _, key in ipairs(TAB_ACCENT) do Skin.Tint(rec, tab[key], accent, true) end
    end
end

-- The tree headers come from a pool (RefreshTreeHeaders): frame.treeHeaders.
local function skinHeaders(frame, accent, line)
    local display, body = fonts()
    local flag, color = titleStyle()
    for _, header in ipairs(frame.treeHeaders or {}) do
        Skin.Font(rec, header.Name, display, flag, color)
        Skin.Font(rec, header.Text, body)
        Skin.Tint(rec, header.MainRing, accent, true)
        Skin.Tint(rec, header.TextBackground, TAB_TINT, true)
        Skin.Tint(rec, header.Divider, line, true)
    end
end

local function skinTexts(frame)
    local display, body = fonts()
    Skin.Font(rec, frame.ActiveSpec and frame.ActiveSpec.ActiveLabel, body or display)
    Skin.Font(rec, frame.ClassCurrencyDisplay and frame.ClassCurrencyDisplay.UnspentLabel, body)
end

local function restore()
    Skin.Restore(rec)
    if back then back:Hide(); shade:Hide() end
end

local drawn
local function signature()
    if not active() then return "off" end
    return Themes.Current() .. "|" .. tostring(Themes.Color())
end

-- force: even if theme, colour, option are unchanged (tab shown).
function TalentsSkin.Apply(force)
    local frame = talents()
    if not (frame and back) then return end
    local now = signature()
    if now == drawn and not force then return end
    if now ~= drawn then restore() end
    drawn = now
    if now == "off" then return end
    local accent, line = Themes.IconColor(), Themes.Spec(Themes.Current()).art.line
    paintBack()
    skinFrameArt(frame, line)
    skinTabs(frame, accent)
    skinHeaders(frame, accent, line)
    skinTexts(frame)
end

function TalentsSkin.SetEnabled(on)
    ns.AccountDB().skinTalents = on and true or nil
    TalentsSkin.Apply()
end

-- Create our own textures (textures only: allowed in combat too) and hook in.
function TalentsSkin.Setup()
    local frame = talents()
    if not frame or back then return end
    back = Skin.OwnTexture(frame, "BACKGROUND", -8)
    back:SetAllPoints(frame)
    shade = Skin.OwnTexture(frame, "BACKGROUND", -7)
    shade:SetAllPoints(frame)
    frame:HookScript("OnShow", function() C_Timer.After(0, function() TalentsSkin.Apply(true) end) end)
    TalentsSkin.Apply(true)
end

-- For the tests: our own tile and the dark fill.
function TalentsSkin.Parts() return back, shade end

-- Already loaded (another addon loaded it before us) or later on demand;
-- before login the settings are not ready yet.
ns.On("PLAYER_LOGIN", function() loggedIn = true; TalentsSkin.Setup() end)
ns.On("ADDON_LOADED", function(_, name) if name == BLIZZARD_ADDON and loggedIn then TalentsSkin.Setup() end end)
ns.Settings.OnChange(function() TalentsSkin.Apply() end)
