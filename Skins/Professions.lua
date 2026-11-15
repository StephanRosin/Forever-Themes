--[[---------------------------------------------------------------------------
Skins/Professions.lua -- Blizzards Berufsfenster (ProfessionsFrame, Forever
1.60.1: Blizzard_Professions/Camelot/Blizzard_ProfessionsFrame.xml, laedt bei
Bedarf) im zentralen Theme. Schalter "Blizzards Berufsfenster im Theme"
(Optionen, Blizzards Fenster), kontoweit, Standard aus. Gebaut wie
Skins/Character.lua. Forever kennt weder TradeSkillFrame noch CraftFrame, und
das Berufsbuch ist kein eigenes Fenster: es ist die Seite BookPage im
ProfessionsFrame (Blizzard_ProfessionsBook.xml laedt unter Camelot nicht).

Im Theme:
  - Rahmen: NineSlice, Portraet und Blizzards Hintergrund (Bg) aus, dazu die
    Flaeche hinter der Rezeptseite; darunter Theme-Kachel, Ring,
    Titelstreifen (Glanz, Linie, Band, Pitwall-Keil), Ornamente (Skin.PaintArt).
  - Titel in der Theme-Schrift und Kopfzeilenfarbe (Akzent).
  - Berufsbuch: Kartenbild (Rahmen, Berufsillustration, braune Flaeche --
    alles eine Textur, Background) aus; dafuer eine leichte dunkle Flaeche
    mit duennem Ring in der Linienfarbe des Themes. Berufsnamen in
    Theme-Schrift und Akzent, Spezialisierung und Beschreibungen in der
    Textschrift (Friz bleibt).
  - Rezeptseite: Hintergruende von Rezeptliste und Formular (samt
    Berufsbild) aus.
  - Rangleisten (Buch und Rezeptseite): Blizzards Rahmen entsaettigt in der
    Linienfarbe; Fuellung, Zahl und Text bleiben Blizzards.
  - Schliessen: das gezeichnete Kreuz in der Symbolfarbe.
  - Seitenreiter rechts (Uebersicht und je Beruf): grau getoent, Auswahl und
    Hover in der Symbolfarbe. Nur Toenung: ihre Klicks wirken Berufszauber
    (in Forever beim Zeigen sogar alle), daran bleibt alles Blizzards.
Blizzard bleibt: Eintraege der Rezeptliste, Inhalt des Formulars, Fuellung
und Zahl der Rangleisten, Suche, Filter, Zauberknoepfe des Berufsbuchs samt
Rahmen, Bildlaufleisten.

Klassisch oder Schalter aus: alles wie von Blizzard (Skin.Restore).

Eigene Teile entstehen, sobald das Fenster geladen ist (nach dem Login,
ADDON_LOADED oder schon geladen). Die Zauberknoepfe des Berufsbuchs sind
geschuetzt (SecureFrameTemplate): laedt das Fenster im Kampf, warten die
eigenen Teile auf PLAYER_REGEN_ENABLED. Nachgezogen wird bei jedem Zeigen und
wenn sich Theme, Farbe oder Schalter aendern -- nur Texturen, Schriften,
Deckkraft.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local Themes, Skin = ns.Themes, ns.Skin

local ProfessionsSkin = {}
ns.ProfessionsSkin = ProfessionsSkin

-- Bg und die Rezeptseite beginnen 21 unter der Oberkante.
local TITLE_HEIGHT = 21
local TAB_TINT = { 0.3, 0.3, 0.3, 1 }
local BODY_FONT = "Friz Quadrata"
-- Blizzards Flaeche hinter Rezeptliste und Formular (Camelot/Blizzard_ProfessionsFrame.xml).
local PAGE_ATLASES = { ["Profession-Background-Template2"] = true }
-- Die Karten des Berufsbuchs (Camelot/Blizzard_ProfessionsBookTemplates.xml).
local BOOK_CARDS = { "PrimaryProfession1", "PrimaryProfession2", "SecondaryProfession1", "SecondaryProfession2",
    "SecondaryProfession3" }
-- Eigene Kartenflaeche: leicht abgedunkelt, damit die Karten unterscheidbar bleiben.
local CARD_FILL = { 0, 0, 0, 0.25 }
local RIM_WIDTH = 1

local L_OPTION = {
    enUS = "Theme Blizzard's professions window",
    deDE = "Blizzards Berufsfenster im Theme",
    esES = "Aplicar el tema a la ventana de profesiones",
    frFR = "Appliquer le thème à la fenêtre des métiers",
}
for code, text in pairs(L_OPTION) do
    if ns.Locales[code] then ns.Locales[code].OPT_SKIN_PROFESSIONS = text end
end

local rec = Skin.NewRecord()
local art
local cardSurfaces = {}
local loggedIn = false

-- ForeverThemesDB direkt gelesen: AccountDB() legte sie vor ADDON_LOADED an.
function ProfessionsSkin.Enabled()
    return _G.ForeverThemesDB ~= nil and _G.ForeverThemesDB.skinProfessions == true
end

local function active()
    return ProfessionsSkin.Enabled() and Themes.Current() ~= Themes.CLASSIC
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

-- fn(card) fuer jede Karte des Berufsbuchs.
local function eachCard(frame, fn)
    local content = frame.BookPage and frame.BookPage.ProfessionsContentFrame
    for _, key in ipairs(BOOK_CARDS) do
        local card = content and content[key]
        if card then fn(card) end
    end
end

-- Flaeche und Ring einer Karte (eigene Texturen, versteckt); beim Setup, nie im Kampf.
local function newCardSurface(card)
    local surface = { fill = Skin.OwnTexture(card, "BACKGROUND", -8) }
    surface.fill:SetAllPoints(card)
    local edges = { { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" },
        { "TOPRIGHT", "BOTTOMRIGHT" } }
    for i, edge in ipairs(edges) do
        local rim = Skin.OwnTexture(card, "BORDER")
        rim:SetPoint(edge[1])
        rim:SetPoint(edge[2])
        if i <= 2 then rim:SetHeight(RIM_WIDTH) else rim:SetWidth(RIM_WIDTH) end
        surface[i] = rim
    end
    cardSurfaces[card] = surface
end

local function paintCardSurfaces(line)
    for _, surface in pairs(cardSurfaces) do
        surface.fill:SetColorTexture(CARD_FILL[1], CARD_FILL[2], CARD_FILL[3], CARD_FILL[4])
        surface.fill:Show()
        for _, rim in ipairs(surface) do
            rim:SetColorTexture(line[1], line[2], line[3], line[4])
            rim:Show()
        end
    end
end

local function hideCardSurfaces()
    for _, surface in pairs(cardSurfaces) do
        surface.fill:Hide()
        for _, rim in ipairs(surface) do rim:Hide() end
    end
end

local function hideBlizzardArt(frame)
    Skin.Hide(rec, frame.NineSlice)
    Skin.Hide(rec, frame.PortraitContainer)
    Skin.Hide(rec, frame.Bg)
    local page = frame.CraftingPage
    Skin.HideAtlases(rec, page, PAGE_ATLASES)
    if page then
        local list, form = page.RecipeList, page.SchematicForm
        if list then Skin.Hide(rec, list.Background); Skin.Hide(rec, list.BackgroundNineSlice) end
        if form then
            Skin.Hide(rec, form.Background)
            Skin.Hide(rec, form.MinimalBackground)
            Skin.Hide(rec, form.NineSlice)
        end
    end
    eachCard(frame, function(card) Skin.Hide(rec, card.Background) end)
end

-- Rahmen der Rangleisten in der Linienfarbe, voll deckend (sonst verschwindet er).
local function skinRankBars(frame, line)
    local c = { line[1], line[2], line[3], 1 }
    local page = frame.CraftingPage
    if page and page.RankBar then Skin.Tint(rec, page.RankBar.Border, c, true) end
    eachCard(frame, function(card)
        if card.StatusBar then Skin.Tint(rec, card.StatusBar.Border, c, true) end
    end)
end

-- Uebersicht und die Berufsreiter (rightProfessionTabs, LargeSideTabButtonTemplate).
local function skinTabs(frame, accent)
    local tabs = { frame.ProfessionsOverviewTab }
    for _, tab in ipairs(frame.rightProfessionTabs or {}) do tabs[#tabs + 1] = tab end
    for _, tab in ipairs(tabs) do
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
    eachCard(frame, function(card)
        -- Ueberschriften der Karten wie die Kopfzeilen der Werte im Pilot: Theme-Schrift und Akzent.
        Skin.Font(rec, card.ProfessionName, display, flag, color)
        Skin.Font(rec, card.missingHeader, display, flag, color)
        Skin.Font(rec, card.specialization, body)
        Skin.Font(rec, card.missingText, body)
    end)
end

local function restore()
    Skin.Restore(rec)
    if art then Skin.HideArt(art) end
    hideCardSurfaces()
    Skin.CloseButton(rec, _G.ProfessionsFrame and _G.ProfessionsFrame.CloseButton, nil)
end

-- Was gerade gilt, damit eine Einstellungsmeldung nicht jedes Mal neu zeichnet.
local drawn
local function signature()
    if not active() then return "off" end
    return Themes.Current() .. "|" .. tostring(Themes.Color())
end

-- force: auch wenn sich Theme, Farbe und Schalter nicht geaendert haben
-- (Fenster gezeigt: Blizzard setzt Bilder neu).
function ProfessionsSkin.Apply(force)
    local frame = _G.ProfessionsFrame
    if not (frame and art) then return end
    local now = signature()
    if now == drawn and not force then return end
    if now ~= drawn then restore() end
    drawn = now
    if now == "off" then return end
    Skin.PaintArt(art)
    hideBlizzardArt(frame)
    local line = Themes.Spec(Themes.Current()).art.line
    paintCardSurfaces(line)
    skinRankBars(frame, line)
    local accent = Themes.IconColor()
    Skin.CloseButton(rec, frame.CloseButton, accent)
    skinTabs(frame, accent)
    skinTexts(frame)
end

function ProfessionsSkin.SetEnabled(on)
    ns.AccountDB().skinProfessions = on and true or nil
    ProfessionsSkin.Apply()
end

-- Eigene Teile anlegen und einhaengen, sobald das Fenster da ist; nie im Kampf
-- (geschuetzte Kinder), dann bei PLAYER_REGEN_ENABLED.
function ProfessionsSkin.Setup()
    local frame = _G.ProfessionsFrame
    if not (loggedIn and frame) or art or InCombatLockdown() then return end
    art = Skin.NewArt(frame, TITLE_HEIGHT)
    Skin.NewCross(frame.CloseButton)
    eachCard(frame, newCardSurface)
    frame:HookScript("OnShow", function() ProfessionsSkin.Apply(true) end)
    ProfessionsSkin.Apply(true)
end

-- Fuer die Tests: die eigene Kunst.
function ProfessionsSkin.Parts() return art end

ns.On("PLAYER_LOGIN", function() loggedIn = true; ProfessionsSkin.Setup() end)
ns.On("ADDON_LOADED", function(_, name) if name == "Blizzard_Professions" then ProfessionsSkin.Setup() end end)
ns.On("PLAYER_REGEN_ENABLED", ProfessionsSkin.Setup)
ns.Settings.OnChange(function() ProfessionsSkin.Apply() end)
