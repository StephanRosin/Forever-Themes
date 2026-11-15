-- Blizzards Zauberbuch im Theme (Skins/Skin.lua, Skins/Spellbook.lua).
-- Eigene Datei, damit wowmock.lua unberuehrt bleibt: PlayerSpellsFrame ist
-- hier nachgestellt, so weit das Addon es anfasst (Camelot/Blizzard_PlayerSpellsFrame.xml,
-- SpellBook/Blizzard_SpellBookFrame.xml, SharedUIPanelTemplates.xml).
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

-- Blizzards dunkelbraune Buchtinte.
local INK = { 0.18, 0.12, 0.06, 1 }
local function text()
    local fs = blizzard():CreateFontString()
    function fs:GetTextColor() local c = self._textColor; return c[1], c[2], c[3], c[4] end
    fs:SetTextColor(INK[1], INK[2], INK[3], INK[4])
    return fs
end

PagedContentFrameBaseMixin = { Event = { OnUpdate = "OnUpdate" } }

-- Blizzard_PlayerSpells laedt bei Bedarf: das Fenster entsteht erst dann.
local frame, book, paged, tab, closeTextures, header, item
local function loadBlizzardPlayerSpells()
    frame = blizzard("PlayerSpellsFrame")
    frame._w, frame._h = 1154, 720
    -- The talents skin shares this frame (skin_talents.lua): not built here.
    frame.TalentsFrame = false
    frame.NineSlice, frame.PortraitContainer = blizzard(), blizzard()
    frame.Bg, frame.TopTileStreaks = tex(), tex()
    frame.TitleContainer = blizzard()
    frame.TitleContainer.TitleText = frame.TitleContainer:CreateFontString()
    closeTextures = { tex(), tex(), tex(), tex() }
    frame.CloseButton = blizzard("PlayerSpellsFrameCloseButton")
    function frame.CloseButton:GetNormalTexture() return closeTextures[1] end
    function frame.CloseButton:GetPushedTexture() return closeTextures[2] end
    function frame.CloseButton:GetHighlightTexture() return closeTextures[3] end
    function frame.CloseButton:GetDisabledTexture() return closeTextures[4] end
    book = blizzard()
    frame.SpellBookFrame = book
    book.BookBGHalved, book.BookBGLeft, book.BookBGRight = tex("spellbook-Page-Right-C60"),
        tex("spellbook-Page-Left-C60"), tex("spellbook-Page-Right-C60")
    book.Bookmark, book.BookCornerFlipbook = tex(), tex("spellbook-corner-flipbook-evergreen")
    tab = blizzard()
    tab.SquareBackground, tab.SquareBackgroundActive, tab.SquareBackgroundActiveGlow = tex(), tex(), tex()
    book.CategoryTabSystem = { tabs = { tab } }
    paged = blizzard()
    book.PagedSpellsFrame = paged
    paged.PagingControls = { PageText = text() }
    paged.frames = {}
    function paged:EnumerateFrames() return ipairs(self.frames) end
    function paged:RegisterCallback(event, fn, owner) self._callback = { event, fn, owner } end
    header = { Text = text(), Backplate = tex("spellbook-list-backplate", 0.65), Border = tex("spellbook-divider") }
    item = { Name = text(), SubName = text(), RequiredLevel = text(), Backplate = tex("spellbook-item-backplate", 0.33) }
    paged.frames = { header, item }
end
-- Blizzard blaettert: neue Elemente, dann der OnUpdate-Rueckruf.
local function turnPage(frames)
    paged.frames = frames
    local cb = paged._callback
    cb[2](cb[3])
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

local Themes, Skin, Media = ns.Themes, ns.SpellbookSkin, ns.Media
local panel
local FRIZ = "Fonts\\FRIZQT__.TTF"
local function alpha(region) return region:GetAlpha() end

print("\nBei Bedarf geladen:")
fire("PLAYER_LOGIN")
panel = dofile("reference.lua")(ns)
check("ohne Blizzard_PlayerSpells nichts angelegt", Skin.Parts(), nil)
loadBlizzardPlayerSpells()
M.combat = true
fire("ADDON_LOADED", "Blizzard_PlayerSpells")
check("im Kampf geladen: noch nichts angelegt", Skin.Parts(), nil)
M.combat = false
fire("PLAYER_REGEN_ENABLED")
local art = Skin.Parts()
check("nach dem Kampf angelegt", art ~= nil, true)
fire("ADDON_LOADED", "Blizzard_PlayerSpells")
check("zweites Laden legt nicht neu an", Skin.Parts(), art)
check("Rueckruf beim Blaettern angemeldet", paged._callback and paged._callback[1], "OnUpdate")
check("eigener Besitzer (nicht das Buch)", paged._callback[3] == Skin, true)

print("\nSchalter aus (Standard):")
check("Standard aus", Skin.Enabled(), false)
Themes.Switch("WOOD")
local title = frame.TitleContainer.TitleText
check("Wood ohne Schalter: NineSlice bleibt", alpha(frame.NineSlice), 1)
check("Wood ohne Schalter: keine Kachel", art.back:IsShown(), false)
check("Wood ohne Schalter: Titel in Friz", (title:GetFont()), FRIZ)
check("Wood ohne Schalter: Zaubername Buchtinte", list(item.Name._textColor), list(INK))

print("\nSchalter an:")
layoutCalls = 0
Skin.SetEnabled(true)
check("gespeichert kontoweit", ForeverThemesDB.skinSpellbook, true)
check("Kachel sichtbar", art.back:IsShown(), true)
check("NineSlice aus", alpha(frame.NineSlice), 0)
check("Portraet aus", alpha(frame.PortraitContainer), 0)
check("Felsgrund aus", alpha(frame.Bg), 0)
check("Streifen aus", alpha(frame.TopTileStreaks), 0)
check("Pergament links aus", alpha(book.BookBGLeft), 0)
check("Pergament rechts aus", alpha(book.BookBGRight), 0)
check("Pergament minimiert aus", alpha(book.BookBGHalved), 0)
check("Lesezeichen aus", alpha(book.Bookmark), 0)
check("Eselsohr aus", alpha(book.BookCornerFlipbook), 0)
check("Schliessen: Blizzards Bild aus", alpha(closeTextures[1]), 0)
check("Titel: Cinzel", (title:GetFont()), Media.FontPath("Cinzel"))
local accent = Themes.Accent(Themes.SPECS.WOOD.look.headerColor or ns.Settings.DEFAULTS.headerColor)
check("Titel im Akzent", list(title._textColor), list({ accent[1], accent[2], accent[3], 1 }))
check("Kopfzeile: Unterlage aus", alpha(header.Backplate), 0)
check("Kopfzeile: Cinzel", (header.Text:GetFont()), Media.FontPath("Cinzel"))
check("Kopfzeile: Zierlinie entsaettigt", header.Border:IsDesaturated(), true)
-- Holz: Textschrift Friz -> Friz bleibt, nur die Farbe wird hell.
local value = Themes.OnPaper(Themes.SPECS.WOOD.look.valueColor or ns.Settings.DEFAULTS.valueColor)
check("Zaubername: Friz bleibt", (item.Name:GetFont()), FRIZ)
check("Zaubername: Wertefarbe statt Buchtinte", list(item.Name._textColor), list({ value[1], value[2], value[3], 1 }))
check("Verfuegbar ab: Wertefarbe", list(item.RequiredLevel._textColor), list({ value[1], value[2], value[3], 1 }))
check("Zauber-Unterlage bleibt Blizzard", alpha(item.Backplate), 0.33)
check("Seitenzahl: Wertefarbe", list(paged.PagingControls.PageText._textColor), list({ value[1], value[2], value[3], 1 }))
local icon = Themes.IconColor()
check("Reiter: Auswahl in der Symbolfarbe", list(tab.SquareBackgroundActive._vertex), list({ icon[1], icon[2], icon[3], 1 }))
check("Reiter: grau", list(tab.SquareBackground._vertex), "0.3,0.3,0.3,1")
check("Reiter: entsaettigt", tab.SquareBackgroundActive:IsDesaturated(), true)
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
check("Pitwall: Zaubername in der Textschrift", (item.Name:GetFont()), Media.FontPath("Titillium Web SemiBold"))
check("Pitwall: Seitenzahl in der Textschrift", (paged.PagingControls.PageText:GetFont()),
    Media.FontPath("Titillium Web SemiBold"))
Themes.Switch("FROST")
check("Frost: Titel Julius", (title:GetFont()), Media.FontPath("Julius Sans One"))
check("Frost: kein Keil", art.wedge:IsShown(), false)
check("Frost: dunkle Flaeche", art.shade:IsShown(), true)
-- Blaettern: neue Elemente werden nachgezogen.
local newItem = { Name = text(), SubName = text(), RequiredLevel = text() }
local newHeader = { Text = text(), Backplate = tex(), Border = tex() }
turnPage({ newHeader, newItem })
check("geblaettert: neuer Zauber in Julius", (newItem.Name:GetFont()), Media.FontPath("Julius Sans One"))
check("geblaettert: neue Kopfzeile ohne Unterlage", alpha(newHeader.Backplate), 0)
-- Blizzard setzt die Titelfarbe beim Zeigen neu: Zeigen zieht nach.
title:SetTextColor(1, 1, 1, 1)
frame._scriptHooks.OnShow()
local frost = Themes.Accent(Themes.SPECS.FROST.look.headerColor)
check("Fenster gezeigt: Titel wieder im Akzent", list(title._textColor), list({ frost[1], frost[2], frost[3], 1 }))
check("Groesse geaendert: eingehaengt", frame._scriptHooks.OnSizeChanged ~= nil, true)
check("Buch gezeigt: eingehaengt", book._scriptHooks.OnShow ~= nil, true)

print("\nKlassisch stellt alles her:")
Themes.Switch("CLASSIC")
check("NineSlice zurueck", alpha(frame.NineSlice), 1)
check("Pergament zurueck", alpha(book.BookBGLeft), 1)
check("Kopfzeile: Unterlage auf ihre Deckkraft", alpha(header.Backplate), 0.65)
check("Kachel aus", art.back:IsShown(), false)
check("Keil aus", art.wedge:IsShown(), false)
check("Titel in Friz", (title:GetFont()), FRIZ)
check("Zaubername in Friz", (item.Name:GetFont()), FRIZ)
check("Zaubername wieder Buchtinte", list(item.Name._textColor), list(INK))
check("Seitenzahl wieder Buchtinte", list(paged.PagingControls.PageText._textColor), list(INK))
check("Reiter nicht mehr entsaettigt", tab.SquareBackgroundActive:IsDesaturated(), false)
check("Reiter ungetoent", list(tab.SquareBackgroundActive._vertex), "1,1,1,1")
check("Schliessen: Blizzards Bild zurueck", alpha(closeTextures[1]), 1)
check("Ring weg", ns.Border.Pieces(art.over)[1]:IsShown(), false)

print("\nSchalter aus unter einem Theme:")
Themes.Switch("TECH")
check("Tech: Titel Space Grotesk", (title:GetFont()), Media.FontPath("Space Grotesk"))
Skin.SetEnabled(false)
check("aus: gespeichert ohne Eintrag", ForeverThemesDB.skinSpellbook, nil)
check("aus: NineSlice zurueck", alpha(frame.NineSlice), 1)
check("aus: Titel in Friz", (title:GetFont()), FRIZ)
check("aus: Zaubername Buchtinte", list(newItem.Name._textColor), list(INK))
check("aus: Kachel aus", art.back:IsShown(), false)
frame._scriptHooks.OnShow()
turnPage({ header, item })
check("aus: Zeigen und Blaettern aendern nichts", alpha(frame.NineSlice), 1)
check("aus: Blaettern laesst die Tinte", list(item.Name._textColor), list(INK))

print("\nNicht lateinischer Client:")
M.locale = "koKR"
Skin.SetEnabled(true)
check("koKR: Zaubername in Blizzards Schrift", (item.Name:GetFont()), FRIZ)
local tech = Themes.OnPaper(Themes.SPECS.TECH.look.valueColor or ns.Settings.DEFAULTS.valueColor)
check("koKR: aber in der Wertefarbe", list(item.Name._textColor), list({ tech[1], tech[2], tech[3], 1 }))
Skin.SetEnabled(false)
check("koKR aus: Buchtinte zurueck", list(item.Name._textColor), list(INK))
M.locale = nil

print("\nFallen:")
local h = assert(io.open(ADDONDIR .. "/Skins/Spellbook.lua")); local src = h:read("*a"); h:close()
-- Kommentare zaehlen nicht: sie erklaeren gerade, warum es fehlt.
src = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
check("kein hooksecurefunc", src:find("hooksecurefunc") == nil, true)
check("Schalter in allen Sprachen", ns.Locales.deDE.OPT_SKIN_SPELLBOOK ~= nil and ns.Locales.esES.OPT_SKIN_SPELLBOOK ~= nil
    and ns.Locales.frFR.OPT_SKIN_SPELLBOOK ~= nil and ns.Locales.enUS.OPT_SKIN_SPELLBOOK ~= nil, true)

print(("\n%d bestanden, %d fehlgeschlagen"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
