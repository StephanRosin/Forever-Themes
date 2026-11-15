-- Blizzard's spellbook in the theme (Skins/Skin.lua, Skins/Spellbook.lua).
-- Own file so wowmock.lua stays untouched: PlayerSpellsFrame is
-- rebuilt here as far as the addon touches it (Camelot/Blizzard_PlayerSpellsFrame.xml,
-- SpellBook/Blizzard_SpellBookFrame.xml, SharedUIPanelTemplates.xml).
local M = dofile("wowmock.lua")

-- Blizzard's frames: counts every change to layout and visibility
-- (forbidden: only textures, fonts, alpha).
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

-- Blizzard's dark brown book ink.
local INK = { 0.18, 0.12, 0.06, 1 }
local function text()
    local fs = blizzard():CreateFontString()
    function fs:GetTextColor() local c = self._textColor; return c[1], c[2], c[3], c[4] end
    fs:SetTextColor(INK[1], INK[2], INK[3], INK[4])
    return fs
end

PagedContentFrameBaseMixin = { Event = { OnUpdate = "OnUpdate" } }

-- Blizzard_PlayerSpells loads on demand: only then does the frame exist.
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
    item = { Name = text(), SubName = text(), RequiredLevel = text(),
        Backplate = tex("spellbook-item-backplate", 0.33) }
    paged.frames = { header, item }
end
-- Blizzard turns the page: new elements, then the OnUpdate callback.
local function turnPage(frames)
    paged.frames = frames
    local cb = paged._callback
    cb[2](cb[3])
end

local ns = dofile("load.lua")()

local pass, fail = 0, 0
local function check(label, got, want)
    if got == want then pass = pass + 1; print(("  OK   %-52s -> %s"):format(label, tostring(got)))
    else fail = fail + 1; print(("  FAIL %-52s -> %s   (want: %s)"):format(label, tostring(got), tostring(want))) end
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

print("\nLoad on demand:")
fire("PLAYER_LOGIN")
panel = dofile("reference.lua")(ns)
check("nothing created without Blizzard_PlayerSpells", Skin.Parts(), nil)
loadBlizzardPlayerSpells()
M.combat = true
fire("ADDON_LOADED", "Blizzard_PlayerSpells")
check("loaded in combat: nothing created yet", Skin.Parts(), nil)
M.combat = false
fire("PLAYER_REGEN_ENABLED")
local art = Skin.Parts()
check("created after combat", art ~= nil, true)
fire("ADDON_LOADED", "Blizzard_PlayerSpells")
check("second load does not recreate", Skin.Parts(), art)
check("page-turn callback registered", paged._callback and paged._callback[1], "OnUpdate")
check("own owner (not the book)", paged._callback[3] == Skin, true)

print("\nSwitch off (default):")
check("off by default", Skin.Enabled(), false)
Themes.Switch("WOOD")
local title = frame.TitleContainer.TitleText
check("Wood without switch: NineSlice stays", alpha(frame.NineSlice), 1)
check("Wood without switch: no tile", art.back:IsShown(), false)
check("Wood without switch: title in Friz", (title:GetFont()), FRIZ)
check("Wood without switch: spell name in book ink", list(item.Name._textColor), list(INK))

print("\nSwitch on:")
layoutCalls = 0
Skin.SetEnabled(true)
check("saved account-wide", ForeverThemesDB.skinSpellbook, true)
check("tile visible", art.back:IsShown(), true)
check("NineSlice off", alpha(frame.NineSlice), 0)
check("portrait off", alpha(frame.PortraitContainer), 0)
check("rock background off", alpha(frame.Bg), 0)
check("streaks off", alpha(frame.TopTileStreaks), 0)
check("left parchment off", alpha(book.BookBGLeft), 0)
check("right parchment off", alpha(book.BookBGRight), 0)
check("minimised parchment off", alpha(book.BookBGHalved), 0)
check("bookmark off", alpha(book.Bookmark), 0)
check("dog-ear off", alpha(book.BookCornerFlipbook), 0)
check("close: Blizzard's art off", alpha(closeTextures[1]), 0)
check("title: Cinzel", (title:GetFont()), Media.FontPath("Cinzel"))
local accent = Themes.Accent(Themes.SPECS.WOOD.look.headerColor or ns.Settings.DEFAULTS.headerColor)
check("title in the accent", list(title._textColor), list({ accent[1], accent[2], accent[3], 1 }))
check("header: backplate off", alpha(header.Backplate), 0)
check("header: Cinzel", (header.Text:GetFont()), Media.FontPath("Cinzel"))
check("header: ornament line desaturated", header.Border:IsDesaturated(), true)
-- Wood: body font Friz -> Friz stays, only the colour turns light.
local value = Themes.OnPaper(Themes.SPECS.WOOD.look.valueColor or ns.Settings.DEFAULTS.valueColor)
check("spell name: Friz stays", (item.Name:GetFont()), FRIZ)
check("spell name: value colour instead of book ink", list(item.Name._textColor),
    list({ value[1], value[2], value[3], 1 }))
check("required level: value colour", list(item.RequiredLevel._textColor), list({ value[1], value[2], value[3], 1 }))
check("spell backplate stays Blizzard's", alpha(item.Backplate), 0.33)
check("page number: value colour", list(paged.PagingControls.PageText._textColor),
    list({ value[1], value[2], value[3], 1 }))
local icon = Themes.IconColor()
check("tab: selection in the icon colour", list(tab.SquareBackgroundActive._vertex),
    list({ icon[1], icon[2], icon[3], 1 }))
check("tab: grey", list(tab.SquareBackground._vertex), "0.3,0.3,0.3,1")
check("tab: desaturated", tab.SquareBackgroundActive:IsDesaturated(), true)
check("no layout on Blizzard's frames", layoutCalls, 0)

print("\nLike the panel, per theme and colour:")
local mismatch = {}
for _, id in ipairs(Themes.IDS) do
    if id ~= Themes.CLASSIC then
        Themes.Switch(id)
        for _, color in ipairs(Themes.Colors(id)) do
            Themes.SetColor(color, id)
            panel.Paint()
            local where = id .. "/" .. color
            if art.back._texture ~= panel.bg._texture then mismatch[#mismatch + 1] = where .. " texture" end
            if list(art.back._vertex) ~= list(panel.bg._vertex) then mismatch[#mismatch + 1] = where .. " tint" end
            local mine, theirs = ns.Border.Pieces(art.over)[1], ns.Border.Pieces(panel)[1]
            if list(mine._vertex) ~= list(theirs._vertex) then mismatch[#mismatch + 1] = where .. " border" end
        end
    end
end
check("tile, tint and border like the InfoPanel", table.concat(mismatch, "; "), "")

print("\nTheme switch:")
Themes.SetColor("ORANGE", "PITWALL")
Themes.Switch("PITWALL")
check("Pitwall: wedge", art.wedge:IsShown(), true)
check("Pitwall: wedge in the colour", list(art.wedge._vertex), list(Themes.Wedge({ 0.882, 0.024, 0, 1 })))
check("Pitwall: title Titillium", (title:GetFont()), Media.FontPath("Titillium Web Bold Italic"))
check("Pitwall: spell name in the body font", (item.Name:GetFont()), Media.FontPath("Titillium Web SemiBold"))
check("Pitwall: page number in the body font", (paged.PagingControls.PageText:GetFont()),
    Media.FontPath("Titillium Web SemiBold"))
Themes.Switch("FROST")
check("Frost: title Julius", (title:GetFont()), Media.FontPath("Julius Sans One"))
check("Frost: no wedge", art.wedge:IsShown(), false)
check("Frost: dark shade", art.shade:IsShown(), true)
-- Page turn: new elements are styled too.
local newItem = { Name = text(), SubName = text(), RequiredLevel = text() }
local newHeader = { Text = text(), Backplate = tex(), Border = tex() }
turnPage({ newHeader, newItem })
check("page turned: new spell in Julius", (newItem.Name:GetFont()), Media.FontPath("Julius Sans One"))
check("page turned: new header without backplate", alpha(newHeader.Backplate), 0)
-- Blizzard resets the title colour on show: showing reapplies it.
title:SetTextColor(1, 1, 1, 1)
frame._scriptHooks.OnShow()
local frost = Themes.Accent(Themes.SPECS.FROST.look.headerColor)
check("frame shown: title back in the accent", list(title._textColor), list({ frost[1], frost[2], frost[3], 1 }))
check("size changed: hooked", frame._scriptHooks.OnSizeChanged ~= nil, true)
check("book shown: hooked", book._scriptHooks.OnShow ~= nil, true)

print("\nClassic restores everything:")
Themes.Switch("CLASSIC")
check("NineSlice back", alpha(frame.NineSlice), 1)
check("parchment back", alpha(book.BookBGLeft), 1)
check("header: backplate at its own alpha", alpha(header.Backplate), 0.65)
check("tile off", art.back:IsShown(), false)
check("wedge off", art.wedge:IsShown(), false)
check("title in Friz", (title:GetFont()), FRIZ)
check("spell name in Friz", (item.Name:GetFont()), FRIZ)
check("spell name back in book ink", list(item.Name._textColor), list(INK))
check("page number back in book ink", list(paged.PagingControls.PageText._textColor), list(INK))
check("tab no longer desaturated", tab.SquareBackgroundActive:IsDesaturated(), false)
check("tab untinted", list(tab.SquareBackgroundActive._vertex), "1,1,1,1")
check("close: Blizzard's art back", alpha(closeTextures[1]), 1)
check("ring gone", ns.Border.Pieces(art.over)[1]:IsShown(), false)

print("\nSwitch off under a theme:")
Themes.Switch("TECH")
check("Tech: title Space Grotesk", (title:GetFont()), Media.FontPath("Space Grotesk"))
Skin.SetEnabled(false)
check("off: saved without entry", ForeverThemesDB.skinSpellbook, nil)
check("off: NineSlice back", alpha(frame.NineSlice), 1)
check("off: title in Friz", (title:GetFont()), FRIZ)
check("off: spell name in book ink", list(newItem.Name._textColor), list(INK))
check("off: tile off", art.back:IsShown(), false)
frame._scriptHooks.OnShow()
turnPage({ header, item })
check("off: showing and turning pages change nothing", alpha(frame.NineSlice), 1)
check("off: turning pages keeps the ink", list(item.Name._textColor), list(INK))

print("\nNon-Latin client:")
M.locale = "koKR"
Skin.SetEnabled(true)
check("koKR: spell name in Blizzard's font", (item.Name:GetFont()), FRIZ)
local tech = Themes.OnPaper(Themes.SPECS.TECH.look.valueColor or ns.Settings.DEFAULTS.valueColor)
check("koKR: but in the value colour", list(item.Name._textColor), list({ tech[1], tech[2], tech[3], 1 }))
Skin.SetEnabled(false)
check("koKR off: book ink back", list(item.Name._textColor), list(INK))
M.locale = nil

print("\nTraps:")
local h = assert(io.open(ADDONDIR .. "/Skins/Spellbook.lua")); local src = h:read("*a"); h:close()
-- Comments do not count: they explain why it is missing.
src = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
check("no hooksecurefunc", src:find("hooksecurefunc") == nil, true)
check("switch in all languages", ns.Locales.deDE.OPT_SKIN_SPELLBOOK ~= nil and ns.Locales.esES.OPT_SKIN_SPELLBOOK ~= nil
    and ns.Locales.frFR.OPT_SKIN_SPELLBOOK ~= nil and ns.Locales.enUS.OPT_SKIN_SPELLBOOK ~= nil, true)

print(("\n%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
