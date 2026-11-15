--[[---------------------------------------------------------------------------
Skins/Collections.lua -- Blizzard's collections window (CollectionsJournal from
Blizzard_Collections, Forever 1.60.1: Shared/Blizzard_Collections.xml, tabs
Camelot/Blizzard_CollectionsTabs.xml, content Mainline/ and
Classic/Blizzard_PetCollection.xml) in the central theme. Option
"Theme Blizzard's collections window" (options, Blizzard's windows),
account-wide, off by default. Built like Skins/Character.lua (the rules are
there).

Themed:
  - Frame: NineSlice, portrait, rock tile (Bg) and the streaks under the
    title hidden; under them the theme tile, ring, title strip with Pitwall
    wedge, ornaments (Skin.PaintArt).
  - The tabs' insets (mounts, pets, toys, heirlooms, appearances): Blizzard's
    tile, edge and shadow hidden.
  - Title in the theme font and accent, the counters' labels (total mounts /
    pets) in the text font (Friz stays Blizzard's).
  - Close: the drawn cross; side tabs as in the character window.
Blizzard's stays: models and their background, lists, toy and appearance
grids, pet card, counter box and number, search box, filter, the
appearances' items/sets tabs, scroll bars, all spell buttons (protected).

Blizzard_Collections loads on demand: hooked on ADDON_LOADED (or at login
if already loaded). If that falls into combat, creating the parts waits for
PLAYER_REGEN_ENABLED: protected spell buttons sit under the window, so our
own frames are never created in combat.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local Themes, Skin = ns.Themes, ns.Skin

local CollectionsSkin = {}
ns.CollectionsSkin = CollectionsSkin

-- Blizzard's Bg starts 21 below the top edge (PortraitFrameTexturedBaseTemplate).
local TITLE_HEIGHT = 21
local TAB_TINT = { 0.3, 0.3, 0.3, 1 }
local BODY_FONT = "Friz Quadrata"
local COLLECTIONS_ADDON = "Blizzard_Collections"
-- Tile, corners and shadow of CollectionsBackgroundTemplate (SharedCollectionTemplates.xml).
local INSET_ATLASES = { ["collections-background-tile"] = true, ["collections-background-corner"] = true,
    ["collections-background-shadow-large"] = true, ["collections-background-shadow-small"] = true }
-- The tabs' pages (CollectionsJournal_UpdateSelectedTab).
-- The counters (CollectionsCountTemplate) per tab.
local COUNTERS = { MountJournal = "MountCount", PetJournal = "PetCount" }
local SUBFRAMES = { "MountJournal", "PetJournal", "ToyBox", "HeirloomsJournal", "WardrobeCollectionFrame" }

local L_OPTION = {
    enUS = "Theme Blizzard's collections window",
    deDE = "Blizzards Sammlungsfenster im Theme",
    esES = "Aplicar el tema a la ventana de colecciones",
    frFR = "Appliquer le thème à la fenêtre des collections",
}
for code, text in pairs(L_OPTION) do
    if ns.Locales[code] then ns.Locales[code].OPT_SKIN_COLLECTIONS = text end
end

local rec = Skin.NewRecord()
local art
local hooked = {}

-- ForeverThemesDB read directly: AccountDB() created it before ADDON_LOADED.
function CollectionsSkin.Enabled()
    return _G.ForeverThemesDB ~= nil and _G.ForeverThemesDB.skinCollections == true
end

local function active()
    return CollectionsSkin.Enabled() and Themes.Current() ~= Themes.CLASSIC
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

-- An inset (InsetFrameTemplate, CollectionsBackgroundTemplate).
local function hideInset(inset)
    if type(inset) ~= "table" then return end
    Skin.Hide(rec, inset.Bg)
    Skin.Hide(rec, inset.NineSlice)
    Skin.HideAtlases(rec, inset, INSET_ATLASES)
end

-- The insets per tab; a missing tab (other game version) is skipped.
local function insets()
    local g = _G
    local mount, pet, wardrobe = g.MountJournal or {}, g.PetJournal or {}, g.WardrobeCollectionFrame or {}
    local sets = wardrobe.SetsCollectionFrame or {}
    return { mount.LeftInset, mount.BottomLeftInset, mount.RightInset, pet.LeftInset, pet.RightInset,
        g.ToyBox and g.ToyBox.iconsFrame, g.HeirloomsJournal and g.HeirloomsJournal.iconsFrame,
        wardrobe.ItemsCollectionFrame, sets.LeftInset, sets.RightInset }
end

local function hideBlizzardArt(frame)
    Skin.Hide(rec, frame.NineSlice)
    Skin.Hide(rec, frame.PortraitContainer)
    Skin.Hide(rec, frame.Bg)
    Skin.Hide(rec, frame.TopTileStreaks)
    -- The list has gaps (nil): pairs, not ipairs.
    for _, inset in pairs(insets()) do hideInset(inset) end
end

local function skinTabs(frame, accent)
    local tabs = frame.TabContainer and frame.TabContainer.Tabs
    for _, tab in ipairs(tabs or {}) do
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
    -- Only the label: Media.ApplyText would read the number back (GetText).
    for name, key in pairs(COUNTERS) do
        local count = _G[name] and _G[name][key]
        if type(count) == "table" then Skin.Font(rec, count.Label, body) end
    end
end

local function restore()
    Skin.Restore(rec)
    if art then Skin.HideArt(art) end
    Skin.CloseButton(rec, _G.CollectionsJournal and _G.CollectionsJournal.CloseButton, nil)
end

-- What is currently applied, so a settings notification does not repaint every time.
local drawn
local function signature()
    if not active() then return "off" end
    return Themes.Current() .. "|" .. tostring(Themes.Color())
end

-- force: even if theme, colour and option are unchanged (window shown).
function CollectionsSkin.Apply(force)
    local frame = _G.CollectionsJournal
    if not (frame and art) then return end
    local now = signature()
    if now == drawn and not force then return end
    if now ~= drawn then restore() end
    drawn = now
    if now == "off" then return end
    Skin.PaintArt(art)
    hideBlizzardArt(frame)
    local accent = Themes.IconColor()
    Skin.CloseButton(rec, frame.CloseButton, accent)
    skinTabs(frame, accent)
    skinTexts(frame)
end

function CollectionsSkin.SetEnabled(on)
    ns.AccountDB().skinCollections = on and true or nil
    CollectionsSkin.Apply()
end

-- Switching tabs sets the title (SetTitle): refresh one frame later.
local function later() C_Timer.After(0, function() CollectionsSkin.Apply(true) end) end

-- Create our own parts and hook in; only out of combat.
function CollectionsSkin.Setup()
    local frame = _G.CollectionsJournal
    if not frame or art then return end
    art = Skin.NewArt(frame, TITLE_HEIGHT)
    Skin.NewCross(frame.CloseButton)
    frame:HookScript("OnShow", function() CollectionsSkin.Apply(true) end)
    for _, name in ipairs(SUBFRAMES) do
        local sub = _G[name]
        if sub and sub.HookScript and not hooked[name] then
            hooked[name] = true
            sub:HookScript("OnShow", later)
        end
    end
    CollectionsSkin.Apply(true)
end

-- For the tests: our own art.
function CollectionsSkin.Parts() return art end

local loggedIn, waiting = false, false
local function trySetup()
    if not (loggedIn and _G.CollectionsJournal) or art then return end
    if InCombatLockdown() then waiting = true; return end
    CollectionsSkin.Setup()
end

ns.On("PLAYER_LOGIN", function() loggedIn = true; trySetup() end)
ns.On("ADDON_LOADED", function(_, name) if name == COLLECTIONS_ADDON then trySetup() end end)
ns.On("PLAYER_REGEN_ENABLED", function() if waiting then waiting = false; trySetup() end end)
ns.Settings.OnChange(function() CollectionsSkin.Apply() end)
