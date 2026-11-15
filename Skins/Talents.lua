--[[---------------------------------------------------------------------------
Skins/Talents.lua -- Blizzards Talentfenster im zentralen Theme.
Schalter "Blizzards Talentfenster im Theme" (Optionen, Blizzards Fenster),
kontoweit, Standard aus. Gebaut wie Skins/Character.lua.

Forever 1.60.1 (Camelot) hat kein eigenes Talentfenster: Zauberbuch und
Talente teilen sich PlayerSpellsFrame (Blizzard_PlayerSpells, laedt bei
Bedarf; Camelot/Blizzard_PlayerSpellsFrame.xml), die Talente sind dessen
Kind TalentsFrame (Camelot/ClassTalents/Blizzard_ClassTalentsFrame.xml).
Den aeusseren Rahmen (Ring, Titelstreifen, Pitwall-Keil, Schliessen,
Portraet, Titel) themt das Zauberbuch-Modul. Hier nur der Inhalt des
Talentreiters:
  - Theme-Kachel samt Toenung und dunkler Flaeche wie die Panels der Forever-Addons unter dem
    Talentbaum; Blizzards Hintergrund, Klassenbild und Innenrahmen aus.
    Die pulsierenden Kopien des Klassenbilds (OverlayBackground*) laufen
    ueber Blizzards Animationen, die die Deckkraft setzen: sie werden
    schwarz getoent, und schwarz bleibt bei additiver Mischung unsichtbar.
  - Trennlinien zwischen den Baeumen in der Linienfarbe des Themes.
  - Kopf je Baum: Name in Theme-Schrift und Akzent, Punktzahl in der
    Textschrift, Ring um das Symbol in der Symbolfarbe, Zahlkasten grau.
  - Reiter der Spezialisierungen: grau, Auswahl und Hover in der Symbolfarbe.
  - "Aktiv" in der Textschrift (ist die Friz, in der Zierschrift),
    "Unverteilte Punkte" in der Textschrift.
Blizzard bleibt: Talentknoepfe und Linien, Wolken/Partikel/Aktivierungs-
Effekte, Suchfeld, Ladeauswahl, Knoepfe (Anwenden, Zuruecksetzen,
Rueckgaengig), Kasten der Punktanzeige, Zahlen.

Klassisch oder Schalter aus: alles wie von Blizzard (Skin.Restore).

Nachgezogen bei jedem Zeigen des Reiters (einen Takt spaeter: Blizzard legt
die Baumkoepfe erst im OnShow an) und wenn sich Theme, Farbe oder Schalter
aendern. Nur eigene Texturen (keine Rahmen), Toenung, Schriften, Deckkraft:
das darf auch im Kampf laufen, das Fenster ist nicht geschuetzt.
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
-- Additiv gemischt und von Blizzards Animationen eingeblendet.
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

-- Wie Character.lua: Theme-Schriften nur fuer lateinische Clients; Friz als
-- Textschrift heisst "Blizzards Schrift bleibt".
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

-- Kachel und dunkle Flaeche wie Skin.PaintArt, ohne Ring und Titelstreifen
-- (die gehoeren dem aeusseren Rahmen).
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

-- Die Baumkoepfe kommen aus einem Pool (RefreshTreeHeaders): frame.treeHeaders.
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

-- force: auch ohne Aenderung an Theme, Farbe, Schalter (Reiter gezeigt).
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

-- Eigene Texturen anlegen (nur Texturen: auch im Kampf erlaubt) und einhaengen.
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

-- Fuer die Tests: die eigene Kachel und die dunkle Flaeche.
function TalentsSkin.Parts() return back, shade end

-- Schon geladen (ein anderes Addon lud es vor uns) oder spaeter bei Bedarf;
-- vor dem Login sind die Einstellungen noch nicht bereit.
ns.On("PLAYER_LOGIN", function() loggedIn = true; TalentsSkin.Setup() end)
ns.On("ADDON_LOADED", function(_, name) if name == BLIZZARD_ADDON and loggedIn then TalentsSkin.Setup() end end)
ns.Settings.OnChange(function() TalentsSkin.Apply() end)
