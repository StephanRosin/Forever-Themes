--[[---------------------------------------------------------------------------
Skins/Legacy.lua -- Blizzards Vermaechtnis-Fenster (LegacySystemFrame, Forever
1.60.1: Blizzard_LegacySystem, nur Spielart "camelot", laedt bei Bedarf;
LegacyMicroButton bzw. Taste TOGGLELEGACYSYSTEM) im zentralen Theme. Drei
Seiten: Belohnungsleiste (RewardTrackPage), Herausforderungen
(ChallengesPage), Baum (TreePage). Schalter "Blizzards Vermaechtnis-Fenster
im Theme" (Optionen, Blizzards Fenster), kontoweit, Standard aus. Gleicher Weg
wie Skins/Character.lua.

Im Theme:
  - Rahmen: NineSlice, Portraet, Felsenkachel (Bg) und Streifen darunter
    (TopTileStreaks) aus, darunter die Kunst wie die Panels der Forever-Addons (Skin.PaintArt).
  - Die grossen Hintergrundbilder der drei Seiten aus; die senkrechten
    Trennlinien (Herausforderungen, Baum) in der Linienfarbe des Themes.
  - Titel in der Theme-Schrift und Kopfzeilenfarbe (Akzent); die
    Ueberschriften "Vermaechtnispunkte" (Belohnungsleiste) und der Name des
    gewaehlten Baums in der Textschrift (bodyFont; ist das Friz, die
    Zierschrift).
  - Schliessen: das gezeichnete Kreuz in der Symbolfarbe.
  - Seitenreiter rechts: grau getoent, Auswahl und Hover in der Symbolfarbe.
Blizzard bleibt: Belohnungskarten und Fortschrittsleisten, Punkte-Schilde,
Kategorien- und Herausforderungsliste, Suchfelder, Filter, Talentbaum samt
Knoepfen, Bildlaufleisten, alle Zahlen (Punkte koennen geheim sein, und die
Punkteleiste des Baums richtet ihren Rahmen an der Textbreite aus).

Klassisch oder Schalter aus: alles wie von Blizzard (Skin.Restore).

Das Fenster laedt erst beim ersten Oeffnen (LoadOnDemand): eingerichtet
wird bei ADDON_LOADED "Blizzard_LegacySystem" oder beim Login, falls es
schon geladen ist. Der Rahmen ist nicht geschuetzt (keine Secure-Vorlage),
eigene Texturen daran anzulegen geht darum auch im Kampf.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local Themes, Skin = ns.Themes, ns.Skin

local LegacySkin = {}
ns.LegacySkin = LegacySkin

local BLIZZARD_ADDON = "Blizzard_LegacySystem"
-- Bg der PortraitFrameTemplate beginnt 21 unter der Oberkante.
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

-- ForeverThemesDB direkt gelesen: AccountDB() legte sie vor ADDON_LOADED an.
function LegacySkin.Enabled()
    return _G.ForeverThemesDB ~= nil and _G.ForeverThemesDB.skinLegacy == true
end

local function active()
    return LegacySkin.Enabled() and Themes.Current() ~= Themes.CLASSIC
end

-- Theme-Schriften haben nur lateinische Buchstaben (LibForeverThemes.LatinClient).
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

-- Die senkrechte Trennlinie einer Seite: Textur ohne parentKey (Challenges).
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
    -- Ueberschriften im Inhalt: ist die Textschrift Friz, die Zierschrift (wie
    -- die Stufenzeile im Charakterfenster).
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

-- force: auch wenn sich Theme, Farbe und Schalter nicht geaendert haben
-- (Fenster oder Seite gezeigt).
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

-- Eine Seite setzt beim Zeigen den Titel (SetTitle): einen Takt spaeter nachziehen.
local function later() C_Timer.After(0, function() LegacySkin.Apply(true) end) end

-- Einmal, sobald Blizzards Fenster da ist und das Theme feststeht (Login).
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

-- Fuer die Tests: die eigene Kunst.
function LegacySkin.Parts() return art end

ns.On("PLAYER_LOGIN", function() loggedIn = true; LegacySkin.Setup() end)
ns.On("ADDON_LOADED", function(_, name) if name == BLIZZARD_ADDON then LegacySkin.Setup() end end)
ns.Settings.OnChange(function() LegacySkin.Apply() end)
