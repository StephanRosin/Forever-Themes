-- Blizzards Charakterfenster im Theme (Skins/Skin.lua, Skins/Character.lua).
-- Eigene Datei, damit wowmock.lua unberuehrt bleibt: das Fenster ist hier
-- nachgestellt, so weit das Addon es anfasst (Camelot/CharacterFrame.xml).
local M = dofile("wowmock.lua")

-- Blizzards Rahmen: zaehlt jede Aenderung an Anordnung und Sichtbarkeit
-- (verboten: nur Texturen, Schriften, Deckkraft).
local layoutCalls = 0
local function blizzard(name)
    local w = M.newWidget(name)
    for _, method in ipairs({ "SetPoint", "ClearAllPoints", "SetSize", "SetWidth", "SetHeight", "Show", "Hide",
                              "SetShown", "SetParent", "SetScale" }) do
        local orig = w[method]
        w[method] = function(self, ...)
            layoutCalls = layoutCalls + 1
            if orig then return orig(self, ...) end
        end
    end
    w._scriptHooks = {}
    function w:HookScript(script, fn) self._scriptHooks[script] = fn end
    if name then _G[name] = w end
    return w
end

local function tex(atlas, alpha)
    local t = blizzard()
    t._atlas, t._alpha = atlas, alpha
    function t:GetAtlas() return self._atlas end
    function t:GetVertexColor() local v = self._vertex or { 1, 1, 1, 1 }; return v[1], v[2], v[3], v[4] end
    function t:SetDesaturated(v) self._desaturated = v end
    function t:IsDesaturated() return self._desaturated == true end
    return t
end

local function regions(frame, list) function frame:GetRegions() return unpack(list) end end

local frame = blizzard("CharacterFrame")
frame._w, frame._h = 631, 424
frame.NineSlice = blizzard()
frame.PortraitContainer = blizzard()
local generalBg, statBg, stoneBg, divider = tex("UI-Character-Info-General-BG"), tex("UI-Character-Info-Stat-BG"),
    tex("UI-Character-Info-Stat-StoneBG3", 0.5), tex("common-framedivider")
frame.LeftPaneHost = blizzard("CharacterFrameLeftPaneHost")
regions(frame.LeftPaneHost, { generalBg })
frame.RightPaneHost = blizzard("CharacterFrameRightPaneHost")
frame.RightPaneHost.StoneBg = stoneBg
regions(frame.RightPaneHost, { statBg, stoneBg })
local dividerFrame = blizzard()
regions(dividerFrame, { divider })
function frame.RightPaneHost:GetChildren() return dividerFrame end
frame.TitleContainer = blizzard()
frame.TitleContainer.TitleText = frame.TitleContainer:CreateFontString()
local closeTextures = { tex(), tex(), tex(), tex() }
frame.CloseButton = blizzard("CharacterFrameCloseButton")
function frame.CloseButton:GetNormalTexture() return closeTextures[1] end
function frame.CloseButton:GetPushedTexture() return closeTextures[2] end
function frame.CloseButton:GetHighlightTexture() return closeTextures[3] end
function frame.CloseButton:GetDisabledTexture() return closeTextures[4] end
local tab = blizzard()
tab.Background, tab.SelectedTexture, tab.TabGlow, tab.HighlightTexture = tex(), tex(), tex(), tex()
frame.ModeTabs = { Tabs = { tab } }

local stats = blizzard("CharacterStatsPaneScrollBox")
stats.ClassBackground, stats.Border = tex(), tex()
local scrollRows = {}
stats.ScrollBox = blizzard()
local rowCallback
ScrollUtil = { AddInitializedFrameCallback = function(box, fn, owner, iterate)
    rowCallback = fn
    if iterate then for _, row in ipairs(scrollRows) do fn(owner, row) end end
end }
local doll = blizzard("PaperDollFrame")
doll.TopBackgroundStripHost = { TopBackgroundStrip = tex(), TopBackgroundStripBottomEdge = tex() }
doll.TitleManagerPane = { Border = tex() }
blizzard("ReputationFrame")
CharacterLevelText = blizzard():CreateFontString()

local ns = dofile("load.lua")()

local pass, fail = 0, 0
local function check(label, got, want)
    if got == want then pass = pass + 1; print(("  OK   %-52s -> %s"):format(label, tostring(got)))
    else fail = fail + 1; print(("  FAIL %-52s -> %s   (erwartet: %s)"):format(label, tostring(got), tostring(want))) end
end
local function list(t) return t and table.concat(t, ",") or "nil" end

for _, f in ipairs(M.frames) do
    if f._events and f._events["PLAYER_LOGIN"] and f:GetScript("OnEvent") then
        f:GetScript("OnEvent")(f, "PLAYER_LOGIN")
    end
end
local panel = dofile("reference.lua")(ns)
local Themes, Skin, Media = ns.Themes, ns.CharacterSkin, ns.Media
local art, line = Skin.Parts()
local title = frame.TitleContainer.TitleText
local FRIZ = "Fonts\\FRIZQT__.TTF"
local function alpha(region) return region:GetAlpha() end

print("\nSchalter aus (Standard):")
check("angelegt beim Login", art ~= nil, true)
check("Standard aus", Skin.Enabled(), false)
Themes.Switch("WOOD")
check("Wood ohne Schalter: NineSlice bleibt", alpha(frame.NineSlice), 1)
check("Wood ohne Schalter: keine Kachel", art.back:IsShown(), false)
check("Wood ohne Schalter: Titel in Friz", (title:GetFont()), FRIZ)

print("\nSchalter an:")
-- Eine Kopfzeile und ein Wert der Werteliste, schon vor dem Einschalten belegt.
local header = { Background = tex(), Title = blizzard():CreateFontString() }
local statRow = { Label = blizzard():CreateFontString(), Value = blizzard():CreateFontString() }
rowCallback(nil, header)
rowCallback(nil, statRow)
layoutCalls = 0
Skin.SetEnabled(true)
check("gespeichert kontoweit", ForeverThemesDB.skinCharacter, true)
check("Kachel sichtbar", art.back:IsShown(), true)
check("NineSlice aus", alpha(frame.NineSlice), 0)
check("Portraet aus", alpha(frame.PortraitContainer), 0)
check("Hintergrund links aus", alpha(generalBg), 0)
check("Hintergrund rechts aus", alpha(statBg), 0)
check("Steinkopf aus", alpha(stoneBg), 0)
check("Blizzards Trennlinie aus", alpha(divider), 0)
check("eigene Trennlinie an", line:IsShown(), true)
check("Klassenbild aus", alpha(stats.ClassBackground), 0)
check("Streifen ueber dem Modell aus", alpha(doll.TopBackgroundStripHost.TopBackgroundStrip), 0)
check("Schliessen: Blizzards Bild aus", alpha(closeTextures[1]), 0)
check("Titel: Cinzel", (title:GetFont()), Media.FontPath("Cinzel"))
check("Stufe: bodyFont Friz -> Zierschrift", (CharacterLevelText:GetFont()), Media.FontPath("Cinzel"))
check("Kopfzeile der Werte: Band aus", alpha(header.Background), 0)
check("Kopfzeile der Werte: Cinzel", (header.Title:GetFont()), Media.FontPath("Cinzel"))
local icon = Themes.IconColor()
check("Reiter: Auswahl in der Symbolfarbe", list(tab.SelectedTexture._vertex), list({ icon[1], icon[2], icon[3], 1 }))
check("Reiter: entsaettigt", tab.SelectedTexture:IsDesaturated(), true)
check("keine Anordnung an Blizzards Rahmen", layoutCalls, 0)

print("\nWie das Panel, je Theme und Farbe:")
local mismatch = {}
for _, id in ipairs(Themes.IDS) do
    if id ~= Themes.CLASSIC then
        Themes.Switch(id)
        for _, color in ipairs(Themes.Colors(id)) do
            Themes.SetColor(color, id)
            panel.Paint()
            local where = id .. "/" .. color
            if art.back._texture ~= panel.bg._texture then mismatch[#mismatch + 1] = where .. " Textur" end
            if list(art.back._vertex) ~= list(panel.bg._vertex) then mismatch[#mismatch + 1] = where .. " Toenung" end
            local mine, theirs = ns.Border.Pieces(art.over)[1], ns.Border.Pieces(panel)[1]
            if list(mine._vertex) ~= list(theirs._vertex) then mismatch[#mismatch + 1] = where .. " Rand" end
        end
    end
end
check("Kachel, Toenung und Rand wie das InfoPanel", table.concat(mismatch, "; "), "")

print("\nThemenwechsel:")
Themes.SetColor("ORANGE", "PITWALL")
Themes.Switch("PITWALL")
check("Pitwall: Keil", art.wedge:IsShown(), true)
check("Pitwall: Keil in der Farbe", list(art.wedge._vertex), list(Themes.Wedge({ 0.882, 0.024, 0, 1 })))
check("Pitwall: Titel Titillium", (title:GetFont()), Media.FontPath("Titillium Web Bold Italic"))
check("Pitwall: Stufe in der Textschrift", (CharacterLevelText:GetFont()), Media.FontPath("Titillium Web SemiBold"))
check("Pitwall: Bezeichnung in der Textschrift", (statRow.Label:GetFont()), Media.FontPath("Titillium Web SemiBold"))
check("Pitwall: Zahl unberuehrt (kann geheim sein)", (statRow.Value:GetFont()), FRIZ)
Themes.Switch("FROST")
check("Frost: Titel Julius", (title:GetFont()), Media.FontPath("Julius Sans One"))
check("Frost: kein Keil", art.wedge:IsShown(), false)
check("Frost: dunkle Flaeche", art.shade:IsShown(), true)
-- Blizzard zeigt einen Reiter und setzt die Titelfarbe neu: einen Takt spaeter nachgezogen.
title:SetTextColor(1, 1, 1, 1)
M.timers = {}
_G.ReputationFrame._scriptHooks.OnShow()
for _, fn in ipairs(M.timers) do fn() end
local accent = Themes.Accent(Themes.SPECS.FROST.look.headerColor)
check("Reiter gezeigt: Titel wieder im Akzent", list(title._textColor), list({ accent[1], accent[2], accent[3], 1 }))
local newRow = { Background = tex(), Title = blizzard():CreateFontString() }
rowCallback(nil, newRow)
check("neue Zeile der Werteliste: Julius", (newRow.Title:GetFont()), Media.FontPath("Julius Sans One"))

print("\nKlassisch stellt alles her:")
Themes.Switch("CLASSIC")
check("NineSlice zurueck", alpha(frame.NineSlice), 1)
check("Steinkopf auf seine Deckkraft", alpha(stoneBg), 0.5)
check("Trennlinie zurueck", alpha(divider), 1)
check("eigene Trennlinie aus", line:IsShown(), false)
check("Kachel aus", art.back:IsShown(), false)
check("Keil aus", art.wedge:IsShown(), false)
check("Titel in Friz", (title:GetFont()), FRIZ)
check("Bezeichnung in Friz", (statRow.Label:GetFont()), FRIZ)
check("Reiter nicht mehr entsaettigt", tab.SelectedTexture:IsDesaturated(), false)
check("Reiter ungetoent", list(tab.SelectedTexture._vertex), "1,1,1,1")
check("Schliessen: Blizzards Bild zurueck", alpha(closeTextures[1]), 1)
check("Ring weg", ns.Border.Pieces(art.over)[1]:IsShown(), false)

print("\nSchalter aus unter einem Theme:")
Themes.Switch("TECH")
check("Tech: Titel Space Grotesk", (title:GetFont()), Media.FontPath("Space Grotesk"))
Skin.SetEnabled(false)
check("aus: gespeichert ohne Eintrag", ForeverThemesDB.skinCharacter, nil)
check("aus: NineSlice zurueck", alpha(frame.NineSlice), 1)
check("aus: Titel in Friz", (title:GetFont()), FRIZ)
check("aus: Kachel aus", art.back:IsShown(), false)
frame._scriptHooks.OnShow()
check("aus: Zeigen aendert nichts", alpha(frame.NineSlice), 1)

print("\nFallen:")
local found = {}
for _, f in ipairs({ "Skins/Skin.lua", "Skins/Character.lua" }) do
    local h = assert(io.open(ADDONDIR .. "/" .. f)); local src = h:read("*a"); h:close()
    -- Kommentare zaehlen nicht: sie erklaeren gerade, warum es fehlt.
    src = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
    if src:find("hooksecurefunc") then found[#found + 1] = f end
end
check("kein hooksecurefunc", table.concat(found, ","), "")
check("Schalter in allen Sprachen", ns.Locales.deDE.OPT_SKIN_CHARACTER ~= nil and ns.Locales.esES.OPT_SKIN_CHARACTER ~= nil
    and ns.Locales.frFR.OPT_SKIN_CHARACTER ~= nil and ns.Locales.enUS.OPT_SKIN_CHARACTER ~= nil, true)

print(("\n%d bestanden, %d fehlgeschlagen"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
