--[[---------------------------------------------------------------------------
Skins/Spellbook.lua -- Blizzard's spellbook in the central theme. In Forever
1.60.1 (Camelot) it is no window of its own: PlayerSpellsFrame
(Blizzard_PlayerSpells, loads on demand; Camelot/Blizzard_PlayerSpellsFrame.xml)
holds the spellbook (.SpellBookFrame) and talents (.TalentsFrame) and shows
one of them depending on the micro button. This module takes the outer frame
(also under the talents) and the spellbook's content; Skins/Talents.lua takes
the talents' content. Option "Theme Blizzard's spellbook" (options,
Blizzard's windows), account-wide (default: Core.lua, Migrate.lua). Model: Skins/Character.lua.

Themed:
  - Frame: NineSlice, portrait, rock ground and streaks hidden; under them
    the theme tile, ring, title strip with Pitwall wedge, ornaments
    (Skin.PaintArt) -- like the Forever addons' panels per theme and colour.
  - The book's parchment pages, bookmark and dog-ear hidden.
  - Title in the theme font and header colour (accent).
  - Page headers (class, general ...): theme font and accent, without
    Blizzard's backing, ornate line in the line colour.
  - Spell names, rank, "Available at", page number in the text font (Friz
    stays) and the theme's value colour: Blizzard's dark brown ink
    (SPELLBOOK_FONT_COLOR) is meant for parchment and would be unreadable on
    the theme tile.
  - Close: the drawn cross in the icon colour.
  - Category tabs (icon tabs): tinted grey, selection in the icon colour.
Blizzard's stays: spell buttons with icon, frame and backing (Blizzard sets
their alpha on hover itself), search box, settings menu, rotation helper,
page buttons, maximize button.

Classic or option off: everything as Blizzard built it (Skin.Restore).

Refreshed when the window and the book show, after every page turn
(PagedSpellsFrame's OnUpdate callback, not a hook), on resize (minimize)
and when theme, colour or option change. Only textures, fonts, alpha. Our
own parts are created when Blizzard_PlayerSpells loads; if it loads in
combat, only after combat (the frame holds the secure rotation helper
button).
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local Themes, Skin = ns.Themes, ns.Skin

local SpellbookSkin = {}
ns.SpellbookSkin = SpellbookSkin

local BLIZZARD_ADDON = "Blizzard_PlayerSpells"
-- PortraitFrameTexturedBaseTemplate: the rock ground starts 21 below the top edge.
local TITLE_HEIGHT = 21
local TAB_TINT = { 0.3, 0.3, 0.3, 1 }
local BODY_FONT = "Friz Quadrata"
-- Blizzard's frame and book art (SharedUIPanelTemplates.xml, Blizzard_SpellBookFrame.xml).
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

-- ForeverThemesDB read directly: AccountDB() created it before ADDON_LOADED.
function SpellbookSkin.Enabled()
    return _G.ForeverThemesDB ~= nil and _G.ForeverThemesDB.skinSpellbook == true
end

local function active()
    return SpellbookSkin.Enabled() and Themes.Current() ~= Themes.CLASSIC
end

-- Theme fonts only have Latin letters (LibForeverThemes.LatinClient):
-- else nil, nil. If the text font is Friz, Friz (Blizzard's own) comes
-- back: the page texts still need the colour.
local function fonts()
    if not LibForeverThemes.LatinClient() then return nil, nil end
    local spec = Themes.Spec(Themes.Current())
    return spec.font, spec.bodyFont or spec.font or BODY_FONT
end

-- Font and colour; without a font (non-Latin client) Blizzard's font stays
-- and only the colour changes -- Blizzard's ink is meant for parchment.
-- Skin.Restore puts both back (snapshot including colour).
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

-- An element of a page: header (Text, SpellBookHeaderTemplate) or
-- spell (Name ..., SpellBookItemTemplate).
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

-- The pages change (page turn, search, category): new elements, new tabs.
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

-- force: even if theme, colour and option are unchanged (window shown,
-- resized: Blizzard resets colours, the rounding needs the dimensions).
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

-- Create our own parts and hook in once Blizzard_PlayerSpells has loaded;
-- never in combat (PLAYER_REGEN_ENABLED catches up).
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
            -- Our own owner: Blizzard registers itself there with the book.
            book.PagedSpellsFrame:RegisterCallback(PagedContentFrameBaseMixin.Event.OnUpdate, skinPages,
                SpellbookSkin)
        end
    end
    forced()
end

-- For the tests: our own art.
function SpellbookSkin.Parts() return art end

ns.On("PLAYER_LOGIN", function() loggedIn = true; SpellbookSkin.Setup() end)
ns.On("ADDON_LOADED", function(_, name) if name == BLIZZARD_ADDON then SpellbookSkin.Setup() end end)
ns.On("PLAYER_REGEN_ENABLED", SpellbookSkin.Setup)
ns.Settings.OnChange(function() SpellbookSkin.Apply() end)
