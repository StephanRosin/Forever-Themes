-- Blizzards Vermaechtnis-Fenster im Theme (Skins/Skin.lua, Skins/Legacy.lua).
-- Eigene Datei, damit wowmock.lua unberuehrt bleibt: das Fenster ist hier
-- nachgestellt, so weit das Addon es anfasst (Blizzard_LegacySystem.xml).
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

-- Das Fenster entsteht erst, wenn Blizzard_LegacySystem laedt (nach dem Login).
local frame, closeTextures, tab, pages, dividers
local function loadBlizzardLegacy()
    frame = blizzard("LegacySystemFrame")
    frame._w, frame._h = 920, 575
    frame.NineSlice, frame.PortraitContainer = blizzard(), blizzard()
    frame.Bg, frame.TopTileStreaks = tex(), tex()
    frame.TitleContainer = blizzard()
    frame.TitleContainer.TitleText = frame.TitleContainer:CreateFontString()
    closeTextures = { tex(), tex(), tex(), tex() }
    frame.CloseButton = blizzard("LegacySystemFrameCloseButton")
    function frame.CloseButton:GetNormalTexture() return closeTextures[1] end
    function frame.CloseButton:GetPushedTexture() return closeTextures[2] end
    function frame.CloseButton:GetHighlightTexture() return closeTextures[3] end
    function frame.CloseButton:GetDisabledTexture() return closeTextures[4] end
    tab = blizzard()
    tab.Background, tab.SelectedTexture, tab.TabGlow, tab.HighlightTexture = tex(), tex(), tex(), tex()
    frame.Tabs = { tab }
    pages, dividers = {}, {}
    for _, key in ipairs({ "RewardTrackPage", "ChallengesPage", "TreePage" }) do
        local page = blizzard()
        page.Background = tex("Legacy-Page-BG")
        frame[key] = page
        pages[key] = page
    end
    for _, key in ipairs({ "ChallengesPage", "TreePage" }) do
        local d = tex("Legacy-Tree-Frame-divider-Vertical")
        pages[key].VerticalDivider = blizzard()
        regions(pages[key].VerticalDivider, { d })
        dividers[key] = d
    end
    -- Die Belohnungsleiste hat keine Trennlinie (der Mock liefert sonst eine Funktion).
    pages.RewardTrackPage.VerticalDivider = false
    local track = pages.RewardTrackPage
    track.PointsLabel, track.Points = track:CreateFontString(), track:CreateFontString()
    local panel = blizzard()
    panel.SelectedTreeIcon = blizzard()
    panel.SelectedTreeIcon.SelectedTreeLabel = panel.SelectedTreeIcon:CreateFontString()
    pages.TreePage.LegacyTreeTraitPanel = panel
end

local ns = dofile("load.lua")()

local pass, fail = 0, 0
local function check(label, got, want)
    if got == want then pass = pass + 1; print(("  OK   %-52s -> %s"):format(label, tostring(got)))
    else fail = fail + 1; print(("  FAIL %-52s -> %s   (erwartet: %s)"):format(label, tostring(got), tostring(want))) end
end
local function list(t) return t and table.concat(t, ",") or "nil" end

local function fire(event, ...)
    for _, f in ipairs(M.frames) do
        if f._events and f._events[event] and f:GetScript("OnEvent") then f:GetScript("OnEvent")(f, event, ...) end
    end
end

local Themes, Skin, Media = ns.Themes, ns.LegacySkin, ns.Media
local FRIZ = "Fonts\\FRIZQT__.TTF"
local function alpha(region) return region:GetAlpha() end

print("\nLaden bei Bedarf:")
fire("PLAYER_LOGIN")
check("Login ohne Fenster: nichts angelegt", Skin.Parts(), nil)
loadBlizzardLegacy()
fire("ADDON_LOADED", "Blizzard_Calendar")
check("fremdes Addon geladen: nichts angelegt", Skin.Parts(), nil)
fire("ADDON_LOADED", "Blizzard_LegacySystem")
local art = Skin.Parts()
check("Blizzard_LegacySystem geladen: angelegt", art ~= nil, true)
fire("ADDON_LOADED", "Blizzard_LegacySystem")
check("zweites Laden: dieselbe Kunst", Skin.Parts(), art)
local panel = dofile("reference.lua")(ns)
local title = frame.TitleContainer.TitleText
local treeLabel = pages.TreePage.LegacyTreeTraitPanel.SelectedTreeIcon.SelectedTreeLabel
local track = pages.RewardTrackPage

print("\nSchalter aus (Standard):")
check("Standard aus", Skin.Enabled(), false)
Themes.Switch("WOOD")
check("Wood ohne Schalter: NineSlice bleibt", alpha(frame.NineSlice), 1)
check("Wood ohne Schalter: keine Kachel", art.back:IsShown(), false)
check("Wood ohne Schalter: Titel in Friz", (title:GetFont()), FRIZ)

print("\nSchalter an:")
layoutCalls = 0
Skin.SetEnabled(true)
check("gespeichert kontoweit", ForeverThemesDB.skinLegacy, true)
check("Kachel sichtbar", art.back:IsShown(), true)
check("NineSlice aus", alpha(frame.NineSlice), 0)
check("Portraet aus", alpha(frame.PortraitContainer), 0)
check("Felsenkachel aus", alpha(frame.Bg), 0)
check("Streifen aus", alpha(frame.TopTileStreaks), 0)
for key, page in pairs(pages) do check(key .. ": Hintergrund aus", alpha(page.Background), 0) end
local line = Themes.Spec("WOOD").art.line
check("Trennlinie in der Linienfarbe", list(dividers.TreePage._vertex), list(line))
check("Trennlinie entsaettigt", dividers.ChallengesPage:IsDesaturated(), true)
check("Schliessen: Blizzards Bild aus", alpha(closeTextures[1]), 0)
check("Titel: Cinzel", (title:GetFont()), Media.FontPath("Cinzel"))
check("Punkte-Ueberschrift: bodyFont Friz -> Zierschrift", (track.PointsLabel:GetFont()), Media.FontPath("Cinzel"))
check("Baumname: Zierschrift", (treeLabel:GetFont()), Media.FontPath("Cinzel"))
check("Punktzahl unberuehrt", (track.Points:GetFont()), FRIZ)
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
check("Pitwall: Baumname in der Textschrift", (treeLabel:GetFont()), Media.FontPath("Titillium Web SemiBold"))
Themes.Switch("FROST")
check("Frost: Titel Julius", (title:GetFont()), Media.FontPath("Julius Sans One"))
check("Frost: kein Keil", art.wedge:IsShown(), false)
check("Frost: Trennlinie in Frosts Linienfarbe", list(dividers.TreePage._vertex), list(Themes.Spec("FROST").art.line))
-- Eine Seite gezeigt: Blizzard setzt Titel neu, einen Takt spaeter nachgezogen.
title:SetTextColor(1, 1, 1, 1)
M.timers = {}
pages.TreePage._scriptHooks.OnShow()
for _, fn in ipairs(M.timers) do fn() end
local accent = Themes.Accent(Themes.SPECS.FROST.look.headerColor)
check("Seite gezeigt: Titel wieder im Akzent", list(title._textColor), list({ accent[1], accent[2], accent[3], 1 }))

print("\nKlassisch stellt alles her:")
Themes.Switch("CLASSIC")
check("NineSlice zurueck", alpha(frame.NineSlice), 1)
check("Felsenkachel zurueck", alpha(frame.Bg), 1)
check("Seitenhintergrund zurueck", alpha(pages.TreePage.Background), 1)
check("Trennlinie ungetoent", list(dividers.TreePage._vertex), "1,1,1,1")
check("Trennlinie nicht entsaettigt", dividers.TreePage:IsDesaturated(), false)
check("Kachel aus", art.back:IsShown(), false)
check("Keil aus", art.wedge:IsShown(), false)
check("Titel in Friz", (title:GetFont()), FRIZ)
check("Baumname in Friz", (treeLabel:GetFont()), FRIZ)
check("Reiter ungetoent", list(tab.SelectedTexture._vertex), "1,1,1,1")
check("Schliessen: Blizzards Bild zurueck", alpha(closeTextures[1]), 1)
check("Ring weg", ns.Border.Pieces(art.over)[1]:IsShown(), false)

print("\nSchalter aus unter einem Theme:")
Themes.Switch("TECH")
check("Tech: Titel Space Grotesk", (title:GetFont()), Media.FontPath("Space Grotesk"))
Skin.SetEnabled(false)
check("aus: gespeichert ohne Eintrag", ForeverThemesDB.skinLegacy, nil)
check("aus: NineSlice zurueck", alpha(frame.NineSlice), 1)
check("aus: Titel in Friz", (title:GetFont()), FRIZ)
check("aus: Kachel aus", art.back:IsShown(), false)
frame._scriptHooks.OnShow()
check("aus: Zeigen aendert nichts", alpha(frame.NineSlice), 1)

print("\nFallen:")
local h = assert(io.open(ADDONDIR .. "/Skins/Legacy.lua")); local src = h:read("*a"); h:close()
-- Kommentare zaehlen nicht: sie erklaeren gerade, warum es fehlt.
src = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
check("kein hooksecurefunc", src:find("hooksecurefunc") == nil, true)
check("Schalter in allen Sprachen", ns.Locales.deDE.OPT_SKIN_LEGACY ~= nil and ns.Locales.esES.OPT_SKIN_LEGACY ~= nil
    and ns.Locales.frFR.OPT_SKIN_LEGACY ~= nil and ns.Locales.enUS.OPT_SKIN_LEGACY ~= nil, true)

print(("\n%d bestanden, %d fehlgeschlagen"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
