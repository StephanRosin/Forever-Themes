-- Blizzards Berufsfenster im Theme (Skins/Skin.lua, Skins/Professions.lua).
-- Eigene Datei, damit wowmock.lua unberuehrt bleibt: das Fenster ist hier
-- nachgestellt, so weit das Addon es anfasst (Camelot/Blizzard_ProfessionsFrame.xml).
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

local ns = dofile("load.lua")()

local function fire(event, ...)
    for _, f in ipairs(M.frames) do
        if f._events and f._events[event] and f:GetScript("OnEvent") then f:GetScript("OnEvent")(f, event, ...) end
    end
end

local pass, fail = 0, 0
local function check(label, got, want)
    if got == want then pass = pass + 1; print(("  OK   %-52s -> %s"):format(label, tostring(got)))
    else fail = fail + 1; print(("  FAIL %-52s -> %s   (erwartet: %s)"):format(label, tostring(got), tostring(want))) end
end
local function list(t) return t and table.concat(t, ",") or "nil" end
local function alpha(region) return region:GetAlpha() end

local Themes, Skin, Media = ns.Themes, ns.ProfessionsSkin, ns.Media
local FRIZ = "Fonts\\FRIZQT__.TTF"

print("\nLaedt bei Bedarf:")
fire("PLAYER_LOGIN")
local panel = dofile("reference.lua")(ns)
check("Login ohne Fenster: nichts angelegt", Skin.Parts(), nil)

-- Blizzard_Professions laedt: das Fenster entsteht erst jetzt.
local frame = blizzard("ProfessionsFrame")
frame._w, frame._h = 673, 594
frame.NineSlice = blizzard()
frame.PortraitContainer = blizzard()
frame.Bg = tex()
frame.TitleContainer = blizzard()
frame.TitleContainer.TitleText = frame.TitleContainer:CreateFontString()
local closeTextures = { tex(), tex(), tex(), tex() }
frame.CloseButton = blizzard("ProfessionsFrameCloseButton")
function frame.CloseButton:GetNormalTexture() return closeTextures[1] end
function frame.CloseButton:GetPushedTexture() return closeTextures[2] end
function frame.CloseButton:GetHighlightTexture() return closeTextures[3] end
function frame.CloseButton:GetDisabledTexture() return closeTextures[4] end
local function sideTab()
    local t = blizzard()
    t.Background, t.SelectedTexture, t.TabGlow, t.HighlightTexture = tex(), tex(), tex(), tex()
    return t
end
frame.ProfessionsOverviewTab = sideTab()
frame.rightProfessionTabs = { sideTab(), sideTab() }
local pageBg, otherTex = tex("Profession-Background-Template2"), tex("Professions-Recipe-Header")
frame.CraftingPage = blizzard()
function frame.CraftingPage:GetRegions() return pageBg, otherTex end
local recipeList = blizzard()
recipeList.Background, recipeList.BackgroundNineSlice = tex(), blizzard()
local form = blizzard()
form.Background, form.MinimalBackground, form.NineSlice = tex(), tex(), blizzard()
local pageRankBar = blizzard()
pageRankBar.Border, pageRankBar.Fill = tex(), tex()
frame.CraftingPage.RecipeList, frame.CraftingPage.SchematicForm = recipeList, form
frame.CraftingPage.RankBar = pageRankBar
local function newCard()
    local c = blizzard()
    c.Background = tex()
    c._textures = {}
    function c:CreateTexture() local t = M.newWidget(); table.insert(self._textures, t); return t end
    for _, key in ipairs({ "ProfessionName", "missingHeader", "specialization", "missingText" }) do
        c[key] = c:CreateFontString()
    end
    c.StatusBar = blizzard()
    c.StatusBar.Border, c.StatusBar.Fill = tex(), tex()
    c.StatusBar.Rank = { Text = c.StatusBar:CreateFontString() }
    return c
end
local card, cooking = newCard(), newCard()
frame.BookPage = blizzard()
frame.BookPage.ProfessionsContentFrame = { PrimaryProfession1 = card, SecondaryProfession1 = cooking }

-- Eigene Texturen auf einer Karte (alles ausser Blizzards Background).
local function ownTextures(c)
    local list = {}
    for _, t in ipairs(c._textures or {}) do list[#list + 1] = t end
    return list
end

M.combat = true
fire("ADDON_LOADED", "Blizzard_Professions")
check("im Kampf geladen: wartet", Skin.Parts(), nil)
M.combat = false
fire("PLAYER_REGEN_ENABLED")
local art = Skin.Parts()
check("nach dem Kampf angelegt", art ~= nil, true)
local title = frame.TitleContainer.TitleText

print("\nSchalter aus (Standard):")
check("Standard aus", Skin.Enabled(), false)
Themes.Switch("WOOD")
check("Wood ohne Schalter: NineSlice bleibt", alpha(frame.NineSlice), 1)
check("Wood ohne Schalter: keine Kachel", art.back:IsShown(), false)
check("Wood ohne Schalter: Titel in Friz", (title:GetFont()), FRIZ)

print("\nSchalter an:")
layoutCalls = 0
Skin.SetEnabled(true)
check("gespeichert kontoweit", ForeverThemesDB.skinProfessions, true)
check("Kachel sichtbar", art.back:IsShown(), true)
check("NineSlice aus", alpha(frame.NineSlice), 0)
check("Portraet aus", alpha(frame.PortraitContainer), 0)
check("Blizzards Hintergrund aus", alpha(frame.Bg), 0)
check("Flaeche der Rezeptseite aus", alpha(pageBg), 0)
check("andere Texturen der Seite bleiben", alpha(otherTex), 1)
check("Schliessen: Blizzards Bild aus", alpha(closeTextures[1]), 0)
check("Titel: Cinzel", (title:GetFont()), Media.FontPath("Cinzel"))
check("Berufsname: Cinzel", (card.ProfessionName:GetFont()), Media.FontPath("Cinzel"))
local accentNow = Themes.Accent(Themes.SPECS.WOOD.look.headerColor or ns.Settings.DEFAULTS.headerColor)
check("Berufsname im Akzent", list(card.ProfessionName._textColor), list({ accentNow[1], accentNow[2], accentNow[3], 1 }))
check("fehlender Beruf: Ueberschrift Cinzel", (cooking.missingHeader:GetFont()), Media.FontPath("Cinzel"))
check("Beschreibung: Friz bleibt", (card.missingText:GetFont()), FRIZ)
check("Rangzahl unberuehrt", (card.StatusBar.Rank.Text:GetFont()), FRIZ)
check("Kartenbild aus", alpha(card.Background), 0)
check("Kartenbild der Zweitberufe aus", alpha(cooking.Background), 0)
local surface = ownTextures(card)
check("eigene Kartenflaeche und Ring (5 Texturen)", #surface, 5)
local shown = 0
for _, t in ipairs(surface) do if t:IsShown() then shown = shown + 1 end end
check("Kartenflaeche sichtbar", shown, 5)
local woodLine = Themes.SPECS.WOOD.art.line
check("Ring in der Linienfarbe", list(surface[2]._colorTexture), list(woodLine))
check("Rangleiste: Rahmen in der Linienfarbe", list(card.StatusBar.Border._vertex),
    list({ woodLine[1], woodLine[2], woodLine[3], 1 }))
check("Rangleiste: Rahmen entsaettigt", card.StatusBar.Border:IsDesaturated(), true)
check("Rangleiste: Fuellung unberuehrt", alpha(card.StatusBar.Fill), 1)
check("Rangleiste der Rezeptseite getoent", pageRankBar.Border:IsDesaturated(), true)
check("Rezeptliste: Hintergrund aus", alpha(recipeList.Background), 0)
check("Formular: Berufsbild aus", alpha(form.Background), 0)
check("Formular: kleiner Hintergrund aus", alpha(form.MinimalBackground), 0)
check("Formular: NineSlice aus", alpha(form.NineSlice), 0)
local icon = Themes.IconColor()
for i, tab in ipairs({ frame.ProfessionsOverviewTab, frame.rightProfessionTabs[2] }) do
    check("Reiter " .. i .. ": Auswahl in der Symbolfarbe", list(tab.SelectedTexture._vertex),
        list({ icon[1], icon[2], icon[3], 1 }))
    check("Reiter " .. i .. ": entsaettigt", tab.SelectedTexture:IsDesaturated(), true)
end
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
check("Pitwall: Berufsname Titillium", (card.ProfessionName:GetFont()), Media.FontPath("Titillium Web Bold Italic"))
check("Pitwall: Spezialisierung in der Textschrift", (card.specialization:GetFont()), Media.FontPath("Titillium Web SemiBold"))
check("Pitwall: Beschreibung in der Textschrift", (card.missingText:GetFont()), Media.FontPath("Titillium Web SemiBold"))
Themes.Switch("FROST")
check("Frost: Titel Julius", (title:GetFont()), Media.FontPath("Julius Sans One"))
check("Frost: kein Keil", art.wedge:IsShown(), false)
check("Frost: dunkle Flaeche", art.shade:IsShown(), true)
-- Blizzard zeigt das Fenster wieder: alles nachgezogen.
frame.NineSlice:SetAlpha(1)
frame._scriptHooks.OnShow()
check("Zeigen: NineSlice wieder aus", alpha(frame.NineSlice), 0)

print("\nKlassisch stellt alles her:")
Themes.Switch("CLASSIC")
check("NineSlice zurueck", alpha(frame.NineSlice), 1)
check("Hintergrund zurueck", alpha(frame.Bg), 1)
check("Flaeche der Rezeptseite zurueck", alpha(pageBg), 1)
check("Kachel aus", art.back:IsShown(), false)
check("Keil aus", art.wedge:IsShown(), false)
check("Titel in Friz", (title:GetFont()), FRIZ)
check("Berufsname in Friz", (card.ProfessionName:GetFont()), FRIZ)
check("Kartenbild zurueck", alpha(card.Background), 1)
check("Berufsbild zurueck", alpha(form.Background), 1)
check("Kartenflaeche aus", surface[1]:IsShown(), false)
check("Rangleiste: Rahmen ungetoent", list(card.StatusBar.Border._vertex), "1,1,1,1")
check("Reiter nicht mehr entsaettigt", frame.ProfessionsOverviewTab.SelectedTexture:IsDesaturated(), false)
check("Reiter ungetoent", list(frame.ProfessionsOverviewTab.SelectedTexture._vertex), "1,1,1,1")
check("Schliessen: Blizzards Bild zurueck", alpha(closeTextures[1]), 1)
check("Ring weg", ns.Border.Pieces(art.over)[1]:IsShown(), false)

print("\nSchalter aus unter einem Theme:")
Themes.Switch("TECH")
check("Tech: Titel Space Grotesk", (title:GetFont()), Media.FontPath("Space Grotesk"))
Skin.SetEnabled(false)
check("aus: gespeichert ohne Eintrag", ForeverThemesDB.skinProfessions, nil)
check("aus: NineSlice zurueck", alpha(frame.NineSlice), 1)
check("aus: Titel in Friz", (title:GetFont()), FRIZ)
check("aus: Kachel aus", art.back:IsShown(), false)
frame._scriptHooks.OnShow()
check("aus: Zeigen aendert nichts", alpha(frame.NineSlice), 1)

print("\nFallen:")
local h = assert(io.open(ADDONDIR .. "/Skins/Professions.lua")); local src = h:read("*a"); h:close()
-- Kommentare zaehlen nicht: sie erklaeren gerade, warum es fehlt.
src = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
check("kein hooksecurefunc", src:find("hooksecurefunc") == nil, true)
check("Reiter: keine Skripte angefasst", src:find("SetScript") == nil and src:find("OnClick") == nil, true)
check("Schalter in allen Sprachen", ns.Locales.deDE.OPT_SKIN_PROFESSIONS ~= nil and ns.Locales.esES.OPT_SKIN_PROFESSIONS ~= nil
    and ns.Locales.frFR.OPT_SKIN_PROFESSIONS ~= nil and ns.Locales.enUS.OPT_SKIN_PROFESSIONS ~= nil, true)

print(("\n%d bestanden, %d fehlgeschlagen"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
