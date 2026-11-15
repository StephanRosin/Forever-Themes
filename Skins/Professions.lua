--[[---------------------------------------------------------------------------
Skins/Professions.lua -- Blizzard's professions window (ProfessionsFrame, Forever
1.60.1: Blizzard_Professions/Camelot/Blizzard_ProfessionsFrame.xml, loads on
demand) in the central theme. Option "Theme Blizzard's professions window"
(options, Blizzard's windows), account-wide, off by default. Built like
Skins/Character.lua. Forever has neither TradeSkillFrame nor CraftFrame, and
the profession book is no window of its own: it is the BookPage page of
ProfessionsFrame (Blizzard_ProfessionsBook.xml does not load under Camelot).

Themed:
  - Frame: NineSlice, portrait and Blizzard's background (Bg) hidden, plus
    the fill behind the recipe page; under them the theme tile, ring, title
    strip (gloss, line, band, Pitwall wedge), ornaments (Skin.PaintArt).
  - Title in the theme font and header colour (accent).
  - Profession book: card image (frame, profession art, brown fill -- all
    one texture, Background) hidden; instead a light dark fill with a thin
    ring in the theme's line colour. Profession names in the theme font and
    accent, specialization and descriptions in the text font (Friz stays).
  - Recipe page: backgrounds of recipe list and form (with the profession
    image) hidden.
  - Rank bars (book and recipe page): Blizzard's frame desaturated in the
    line colour; fill, number and text stay Blizzard's.
  - Close: the drawn cross in the icon colour.
  - Side tabs on the right (overview and one per profession): tinted grey,
    selection and hover in the icon colour. Tint only: their clicks cast
    profession spells (in Forever even all of them on show), so all of that
    stays Blizzard's.
Blizzard's stays: recipe list entries, form content, rank bar fill and
number, search, filter, the profession book's spell buttons with their
frames, scroll bars.

Classic or option off: everything as Blizzard built it (Skin.Restore).

Our own parts are created as soon as the window has loaded (after login,
ADDON_LOADED or already loaded). The profession book's spell buttons are
protected (SecureFrameTemplate): if the window loads in combat, our parts
wait for PLAYER_REGEN_ENABLED. Refreshed on every show and when theme,
colour or option change -- only textures, fonts, alpha.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local Themes, Skin = ns.Themes, ns.Skin

local ProfessionsSkin = {}
ns.ProfessionsSkin = ProfessionsSkin

-- Bg and the recipe page start 21 below the top edge.
local TITLE_HEIGHT = 21
local TAB_TINT = { 0.3, 0.3, 0.3, 1 }
local BODY_FONT = "Friz Quadrata"
-- Blizzard's fill behind recipe list and form (Camelot/Blizzard_ProfessionsFrame.xml).
local PAGE_ATLASES = { ["Profession-Background-Template2"] = true }
-- The profession book's cards (Camelot/Blizzard_ProfessionsBookTemplates.xml).
local BOOK_CARDS = { "PrimaryProfession1", "PrimaryProfession2", "SecondaryProfession1", "SecondaryProfession2",
    "SecondaryProfession3" }
-- Our own card fill: slightly darkened so the cards stay distinguishable.
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

-- ForeverThemesDB read directly: AccountDB() created it before ADDON_LOADED.
function ProfessionsSkin.Enabled()
    return _G.ForeverThemesDB ~= nil and _G.ForeverThemesDB.skinProfessions == true
end

local function active()
    return ProfessionsSkin.Enabled() and Themes.Current() ~= Themes.CLASSIC
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

-- fn(card) for every card of the profession book.
local function eachCard(frame, fn)
    local content = frame.BookPage and frame.BookPage.ProfessionsContentFrame
    for _, key in ipairs(BOOK_CARDS) do
        local card = content and content[key]
        if card then fn(card) end
    end
end

-- A card's fill and ring (our own textures, hidden); at setup, never in combat.
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

-- Rank bar frames in the line colour, fully opaque (else they vanish).
local function skinRankBars(frame, line)
    local c = { line[1], line[2], line[3], 1 }
    local page = frame.CraftingPage
    if page and page.RankBar then Skin.Tint(rec, page.RankBar.Border, c, true) end
    eachCard(frame, function(card)
        if card.StatusBar then Skin.Tint(rec, card.StatusBar.Border, c, true) end
    end)
end

-- Overview and the profession tabs (rightProfessionTabs, LargeSideTabButtonTemplate).
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
        -- Card headings like the stat headers in the pilot: theme font and accent.
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

-- What is currently applied, so a settings notification does not repaint every time.
local drawn
local function signature()
    if not active() then return "off" end
    return Themes.Current() .. "|" .. tostring(Themes.Color())
end

-- force: even if theme, colour and option have not changed
-- (window shown: Blizzard resets images).
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

-- Create our own parts and hook in once the window exists; never in combat
-- (protected children), then on PLAYER_REGEN_ENABLED.
function ProfessionsSkin.Setup()
    local frame = _G.ProfessionsFrame
    if not (loggedIn and frame) or art or InCombatLockdown() then return end
    art = Skin.NewArt(frame, TITLE_HEIGHT)
    Skin.NewCross(frame.CloseButton)
    eachCard(frame, newCardSurface)
    frame:HookScript("OnShow", function() ProfessionsSkin.Apply(true) end)
    ProfessionsSkin.Apply(true)
end

-- For the tests: our own art.
function ProfessionsSkin.Parts() return art end

ns.On("PLAYER_LOGIN", function() loggedIn = true; ProfessionsSkin.Setup() end)
ns.On("ADDON_LOADED", function(_, name) if name == "Blizzard_Professions" then ProfessionsSkin.Setup() end end)
ns.On("PLAYER_REGEN_ENABLED", ProfessionsSkin.Setup)
ns.Settings.OnChange(function() ProfessionsSkin.Apply() end)
