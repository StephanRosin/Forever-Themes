--[[---------------------------------------------------------------------------
Skins/Legacy.lua -- Blizzard's legacy window (LegacySystemFrame, Forever
1.60.1: Blizzard_LegacySystem, only game type "camelot", loads on demand;
LegacyMicroButton or key TOGGLELEGACYSYSTEM) in the central theme. Three
pages: reward track (RewardTrackPage), challenges (ChallengesPage), tree
(TreePage). Option "Theme Blizzard's legacy window" (options, Blizzard's
windows), account-wide (default: Core.lua, Migrate.lua). Same approach as
Skins/Character.lua.

Themed:
  - Frame: NineSlice, portrait, rock tile (Bg) and the streaks under it
    (TopTileStreaks) hidden; under them the art like the Forever addons' panels (Skin.PaintArt).
  - The three pages' large background images hidden; the vertical dividers
    (challenges, tree) in the theme's line colour.
  - Title in the theme font and header colour (accent); the headings
    "Legacy points" (reward track) and the selected tree's name in the text
    font (bodyFont; if that is Friz, the title font).
  - Close: the drawn cross in the icon colour.
  - Side tabs on the right: tinted grey, selection and hover in the icon colour.
Blizzard's stays: reward cards and progress bars, point shields, category
and challenge list, search boxes, filter, talent tree with its buttons,
scroll bars, all numbers (points can be secret, and the tree's point bar
aligns its frame to the text width).

Classic or option off: everything as Blizzard built it (Skin.Restore).

The window only loads when first opened (LoadOnDemand): set up on
ADDON_LOADED "Blizzard_LegacySystem" or at login if already loaded. The
frame is not protected (no secure template), so creating our own textures
on it works in combat too.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local Themes, Skin = ns.Themes, ns.Skin

local LegacySkin = {}
ns.LegacySkin = LegacySkin

local BLIZZARD_ADDON = "Blizzard_LegacySystem"
-- PortraitFrameTemplate's Bg starts 21 below the top edge.
local TITLE_HEIGHT = 21
local TAB_TINT = { 0.3, 0.3, 0.3, 1 }
local BODY_FONT = "Friz Quadrata"
local PAGES = { "RewardTrackPage", "ChallengesPage", "TreePage" }

local L_OPTION = {
    enUS = "Theme Blizzard's legacy window",
    deDE = "Blizzards Vermaechtnis-Fenster im Theme",
    esES = "Aplicar el tema a la ventana de legado",
    frFR = "Appliquer le thème à la fenêtre d'héritage",
}
for code, text in pairs(L_OPTION) do
    if ns.Locales[code] then ns.Locales[code].OPT_SKIN_LEGACY = text end
end

local rec = Skin.NewRecord()
local art
local loggedIn = false

-- ForeverThemesDB read directly: AccountDB() created it before ADDON_LOADED.
function LegacySkin.Enabled()
    return _G.ForeverThemesDB ~= nil and _G.ForeverThemesDB.skinLegacy == true
end

local function active()
    return LegacySkin.Enabled() and Themes.Current() ~= Themes.CLASSIC
end

-- Theme fonts only have Latin letters (LibForeverThemes.LatinClient).
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

-- A page's vertical divider: a texture without parentKey (challenges).
local function dividerTextures(page)
    local divider = page and page.VerticalDivider
    if not (divider and divider.GetRegions) then return {} end
    return { divider:GetRegions() }
end

local function hideBlizzardArt(frame)
    Skin.Hide(rec, frame.NineSlice)
    Skin.Hide(rec, frame.PortraitContainer)
    Skin.Hide(rec, frame.Bg)
    Skin.Hide(rec, frame.TopTileStreaks)
    local line = Themes.Spec(Themes.Current()).art.line
    for _, key in ipairs(PAGES) do
        local page = frame[key]
        if page then
            Skin.Hide(rec, page.Background)
            for _, tex in ipairs(dividerTextures(page)) do Skin.Tint(rec, tex, line, true) end
        end
    end
end

local function skinTabs(frame, accent)
    for _, tab in ipairs(frame.Tabs or {}) do
        Skin.Tint(rec, tab.Background, TAB_TINT, true)
        Skin.Tint(rec, tab.SelectedTexture, accent, true)
        Skin.Tint(rec, tab.TabGlow, accent, true)
        Skin.Tint(rec, tab.HighlightTexture, accent, true)
    end
end

local function skinTexts(frame)
    local display, body = fonts()
    local flag, color = titleStyle()
    Skin.Font(rec, frame.TitleContainer and frame.TitleContainer.TitleText, display, flag, color)
    -- Headings in the content: if the text font is Friz, the title font (like
    -- the level line in the character window).
    local track, tree = frame.RewardTrackPage, frame.TreePage
    Skin.Font(rec, track and track.PointsLabel, body or display)
    local panel = tree and tree.LegacyTreeTraitPanel
    local icon = panel and panel.SelectedTreeIcon
    Skin.Font(rec, icon and icon.SelectedTreeLabel, body or display)
end

local function restore()
    Skin.Restore(rec)
    if art then Skin.HideArt(art) end
    Skin.CloseButton(rec, _G.LegacySystemFrame and _G.LegacySystemFrame.CloseButton, nil)
end

local drawn
local function signature()
    if not active() then return "off" end
    return Themes.Current() .. "|" .. tostring(Themes.Color())
end

-- force: even if theme, colour and option have not changed
-- (window or page shown).
function LegacySkin.Apply(force)
    local frame = _G.LegacySystemFrame
    if not (frame and art) then return end
    local now = signature()
    if now == drawn and not force then return end
    if now ~= drawn then restore() end
    drawn = now
    if now == "off" then return end
    Skin.PaintArt(art)
    hideBlizzardArt(frame)
    local accent = Themes.IconColor()
    Skin.CloseButton(rec, frame.CloseButton, accent)
    skinTabs(frame, accent)
    skinTexts(frame)
end

function LegacySkin.SetEnabled(on)
    ns.AccountDB().skinLegacy = on and true or nil
    LegacySkin.Apply()
end

-- A page sets the title when shown (SetTitle): refresh one frame later.
local function later() C_Timer.After(0, function() LegacySkin.Apply(true) end) end

-- Once, as soon as Blizzard's window exists and the theme is known (login).
function LegacySkin.Setup()
    local frame = _G.LegacySystemFrame
    if not (frame and loggedIn) or art then return end
    art = Skin.NewArt(frame, TITLE_HEIGHT)
    Skin.NewCross(frame.CloseButton)
    frame:HookScript("OnShow", function() LegacySkin.Apply(true) end)
    for _, key in ipairs(PAGES) do
        local page = frame[key]
        if page and page.HookScript then page:HookScript("OnShow", later) end
    end
    LegacySkin.Apply(true)
end

-- For the tests: our own art.
function LegacySkin.Parts() return art end

ns.On("PLAYER_LOGIN", function() loggedIn = true; LegacySkin.Setup() end)
ns.On("ADDON_LOADED", function(_, name) if name == BLIZZARD_ADDON then LegacySkin.Setup() end end)
ns.Settings.OnChange(function() LegacySkin.Apply() end)
