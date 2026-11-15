--[[---------------------------------------------------------------------------
Skins/Spellbook.lua -- Blizzards Zauberbuch im zentralen Theme. In Forever
1.60.1 (Camelot) ist es kein eigenes Fenster: PlayerSpellsFrame
(Blizzard_PlayerSpells, laedt bei Bedarf; Camelot/Blizzard_PlayerSpellsFrame.xml)
traegt Zauberbuch (.SpellBookFrame) und Talente (.TalentsFrame) und zeigt je
nach Mikroknopf eines davon. Dieses Modul nimmt den aeusseren Rahmen (auch
unter den Talenten) und den Inhalt des Zauberbuchs; den Inhalt der Talente
nimmt Skins/Talents.lua. Schalter "Blizzards Zauberbuch im Theme"
(Optionen, Blizzards Fenster), kontoweit, Standard aus. Vorbild: Skins/Character.lua.

Im Theme:
  - Rahmen: NineSlice, Portraet, Felsgrund und Streifen aus, darunter
    Theme-Kachel, Ring, Titelstreifen samt Pitwall-Keil, Ornamente
    (Skin.PaintArt) -- wie die Panels der Forever-Addons je Theme und Farbe.
  - Pergamentseiten, Lesezeichen und Eselsohr des Buchs aus.
  - Titel in der Theme-Schrift und Kopfzeilenfarbe (Akzent).
  - Kopfzeilen der Seiten (Klasse, Allgemein ...): Theme-Schrift und Akzent,
    ohne Blizzards Unterlage, Zierlinie in der Linienfarbe.
  - Zaubernamen, Rang, "Verfuegbar ab", Seitenzahl in der Textschrift (Friz
    bleibt) und der Wertefarbe des Themes: Blizzards dunkelbraune Tinte
    (SPELLBOOK_FONT_COLOR) ist fuer Pergament gedacht und waere auf der
    Theme-Kachel unlesbar.
  - Schliessen: das gezeichnete Kreuz in der Symbolfarbe.
  - Kategoriereiter (Symbolreiter): grau getoent, Auswahl in der Symbolfarbe.
Blizzard bleibt: Zauberknoepfe samt Symbol, Rahmen und Unterlage (Blizzard
setzt deren Deckkraft beim Hover selbst), Suchfeld, Einstellungsmenue,
Rotationshelfer, Blaettern-Knoepfe, Maximieren-Knopf.

Klassisch oder Schalter aus: alles wie von Blizzard (Skin.Restore).

Nachgezogen wird beim Zeigen des Fensters und des Buchs, nach jedem
Blaettern (OnUpdate-Rueckruf des PagedSpellsFrame, kein Hook), bei
Groessenaenderung (Minimieren) und wenn sich Theme, Farbe oder Schalter
aendern. Nur Texturen, Schriften, Deckkraft. Die eigenen Teile entstehen
beim Laden von Blizzard_PlayerSpells; laedt es im Kampf, erst nach dem Kampf
(im Rahmen steckt der sichere Rotationshelfer-Knopf).
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local Themes, Skin = ns.Themes, ns.Skin

local SpellbookSkin = {}
ns.SpellbookSkin = SpellbookSkin

local BLIZZARD_ADDON = "Blizzard_PlayerSpells"
-- PortraitFrameTexturedBaseTemplate: der Felsgrund beginnt 21 unter der Oberkante.
local TITLE_HEIGHT = 21
local TAB_TINT = { 0.3, 0.3, 0.3, 1 }
local BODY_FONT = "Friz Quadrata"
-- Blizzards Rahmen- und Buchkunst (SharedUIPanelTemplates.xml, Blizzard_SpellBookFrame.xml).
local FRAME_ART = { "NineSlice", "PortraitContainer", "Bg", "TopTileStreaks" }
local BOOK_ART = { "BookBGHalved", "BookBGLeft", "BookBGRight", "Bookmark", "BookCornerFlipbook" }
local ITEM_TEXTS = { "Name", "SubName", "RequiredLevel" }

local L_OPTION = {
    enUS = "Theme Blizzard's spellbook",
    deDE = "Blizzards Zauberbuch im Theme",
    esES = "Aplicar el tema al libro de hechizos",
    frFR = "Appliquer le thème au grimoire",
}
for code, text in pairs(L_OPTION) do
    if ns.Locales[code] then ns.Locales[code].OPT_SKIN_SPELLBOOK = text end
end

local rec = Skin.NewRecord()
local art, loggedIn, hooked
local pageFrames = setmetatable({}, { __mode = "k" })

-- ForeverThemesDB direkt gelesen: AccountDB() legte sie vor ADDON_LOADED an.
function SpellbookSkin.Enabled()
    return _G.ForeverThemesDB ~= nil and _G.ForeverThemesDB.skinSpellbook == true
end

local function active()
    return SpellbookSkin.Enabled() and Themes.Current() ~= Themes.CLASSIC
end

-- Theme-Schriften haben nur lateinische Buchstaben (LibForeverThemes.LatinClient):
-- sonst nil, nil. Ist die Textschrift Friz, kommt Friz (Blizzards eigene)
-- zurueck: die Seitentexte brauchen trotzdem die Farbe.
local function fonts()
    if not LibForeverThemes.LatinClient() then return nil, nil end
    local spec = Themes.Spec(Themes.Current())
    return spec.font, spec.bodyFont or spec.font or BODY_FONT
end

-- Schrift und Farbe; ohne Schrift (nicht lateinischer Client) bleibt
-- Blizzards Schrift und nur die Farbe wechselt -- Blizzards Tinte ist fuer
-- Pergament. Skin.Restore stellt beides her (Snapshot samt Farbe).
local function ink(fs, fontName, flag, color)
    if fontName then return Skin.Font(rec, fs, fontName, flag, color) end
    if not (fs and fs.SetTextColor) then return end
    rec.font[fs] = rec.font[fs] or ns.Media.Snapshot(fs)
    fs:SetTextColor(color[1], color[2], color[3], color[4])
end

local function titleStyle()
    local look = Themes.Spec(Themes.Current()).look
    local c = Themes.Accent(look.headerColor or ns.Settings.DEFAULTS.headerColor)
    return look.headerFlag or "OUTLINE", { c[1], c[2], c[3], 1 }
end

local function textColor()
    local look = Themes.Spec(Themes.Current()).look
    local c = Themes.OnPaper(look.valueColor or ns.Settings.DEFAULTS.valueColor)
    return { c[1], c[2], c[3], 1 }
end

local function lineColor()
    local l = Themes.Spec(Themes.Current()).art.line
    return { l[1], l[2], l[3], l[4] }
end

-- Ein Element einer Seite: Kopfzeile (Text, SpellBookHeaderTemplate) oder
-- Zauber (Name ..., SpellBookItemTemplate).
local function skinPageFrame(f)
    pageFrames[f] = true
    if not active() then return end
    local display, body = fonts()
    if f.Text then
        Skin.Hide(rec, f.Backplate)
        Skin.Tint(rec, f.Border, lineColor(), true)
        local flag, color = titleStyle()
        ink(f.Text, display, flag, color)
    else
        local color = textColor()
        for _, key in ipairs(ITEM_TEXTS) do ink(f[key], body, nil, color) end
    end
end

local function skinTabs(book, accent)
    local system = book.CategoryTabSystem
    for _, tab in ipairs(system and system.tabs or {}) do
        Skin.Tint(rec, tab.SquareBackground, TAB_TINT, true)
        Skin.Tint(rec, tab.SquareBackgroundActive, accent, true)
        Skin.Tint(rec, tab.SquareBackgroundActiveGlow, accent, true)
    end
end

-- Die Seiten wechseln (Blaettern, Suche, Kategorie): neue Elemente, neue Reiter.
local function skinPages()
    local book = _G.PlayerSpellsFrame and _G.PlayerSpellsFrame.SpellBookFrame
    local paged = book and book.PagedSpellsFrame
    if not paged then return end
    for _, f in paged:EnumerateFrames() do skinPageFrame(f) end
    if not active() then return end
    local accent = Themes.IconColor()
    skinTabs(book, { accent[1], accent[2], accent[3], 1 })
    local paging = paged.PagingControls
    ink(paging and paging.PageText, select(2, fonts()), nil, textColor())
end

local function hideBlizzardArt(frame)
    for _, key in ipairs(FRAME_ART) do Skin.Hide(rec, frame[key]) end
    local book = frame.SpellBookFrame
    for _, key in ipairs(book and BOOK_ART or {}) do Skin.Hide(rec, book[key]) end
end

local function restore()
    Skin.Restore(rec)
    if art then Skin.HideArt(art) end
    Skin.CloseButton(rec, _G.PlayerSpellsFrame and _G.PlayerSpellsFrame.CloseButton, nil)
end

local drawn
local function signature()
    if not active() then return "off" end
    return Themes.Current() .. "|" .. tostring(Themes.Color())
end

-- force: auch ohne Aenderung von Theme, Farbe und Schalter (Fenster gezeigt,
-- Groesse geaendert: Blizzard setzt Farben neu, die Rundung braucht die Masse).
function SpellbookSkin.Apply(force)
    local frame = _G.PlayerSpellsFrame
    if not (frame and art) then return end
    local now = signature()
    if now == drawn and not force then return end
    if now ~= drawn then restore() end
    drawn = now
    if now == "off" then return end
    Skin.PaintArt(art)
    hideBlizzardArt(frame)
    Skin.CloseButton(rec, frame.CloseButton, Themes.IconColor())
    local display = fonts()
    local flag, color = titleStyle()
    Skin.Font(rec, frame.TitleContainer and frame.TitleContainer.TitleText, display, flag, color)
    for f in pairs(pageFrames) do skinPageFrame(f) end
    skinPages()
end

function SpellbookSkin.SetEnabled(on)
    ns.AccountDB().skinSpellbook = on and true or nil
    SpellbookSkin.Apply()
end

local function forced() SpellbookSkin.Apply(true) end

-- Eigene Teile anlegen und einhaengen, sobald Blizzard_PlayerSpells geladen
-- ist; nie im Kampf (PLAYER_REGEN_ENABLED holt es nach).
function SpellbookSkin.Setup()
    local frame = _G.PlayerSpellsFrame
    if not (loggedIn and frame) or art or InCombatLockdown() then return end
    art = Skin.NewArt(frame, TITLE_HEIGHT)
    Skin.NewCross(frame.CloseButton)
    if not hooked then
        hooked = true
        frame:HookScript("OnShow", forced)
        frame:HookScript("OnSizeChanged", forced)
        local book = frame.SpellBookFrame
        if book then
            book:HookScript("OnShow", forced)
            -- Eigener Besitzer: Blizzard meldet sich dort mit dem Buch selbst an.
            book.PagedSpellsFrame:RegisterCallback(PagedContentFrameBaseMixin.Event.OnUpdate, skinPages,
                SpellbookSkin)
        end
    end
    forced()
end

-- Fuer die Tests: die eigene Kunst.
function SpellbookSkin.Parts() return art end

ns.On("PLAYER_LOGIN", function() loggedIn = true; SpellbookSkin.Setup() end)
ns.On("ADDON_LOADED", function(_, name) if name == BLIZZARD_ADDON then SpellbookSkin.Setup() end end)
ns.On("PLAYER_REGEN_ENABLED", SpellbookSkin.Setup)
ns.Settings.OnChange(function() SpellbookSkin.Apply() end)
