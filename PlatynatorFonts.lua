local _, ns = ...

-- "Theme font for Platynator" (ForeverThemesDB.platynatorFont, from Forever
-- Unit Frames' Core/PlatynatorFonts.lua): every own design in Platynator's
-- active profile (design.font.asset) takes the central theme's font
-- (Themes.Font); outline and shadow stay Platynator's. While this addon is
-- loaded it owns this (LibForeverThemes.Hub(); the Unit Frames' and
-- InfoPanel's bridges stand down). Its
-- shipped designs ("_deer", "_hare_simplified", ...) are not stored and
-- stay as they are. The first change remembers each design's font
-- (ForeverThemesDB.platynator.snapshot[profile][design]); Classic or
-- the switch off puts exactly that back and forgets it.
--
-- Platynator has no public way to redraw its designs (its callback
-- registry is private, Platynator.API knows only text and import): the
-- font shows after a /reload, the chat says so. When Platynator loads,
-- our theme fonts go to LibSharedMedia (where Platynator looks fonts up
-- by name) and designs made since the last change get the font, before
-- Platynator reads them.
local PlatynatorFonts = {}
ns.PlatynatorFonts = PlatynatorFonts

-- Platynator's own font (its Core/Constants.lua DefaultFont).
local PLATYNATOR_DEFAULT = "Roboto Condensed Bold"

-- The active profile's own designs and its name; nil when Platynator's
-- saved variables do not look as expected.
local function designs()
    local config = _G.PLATYNATOR_CONFIG
    local name = _G.PLATYNATOR_CURRENT_PROFILE or "DEFAULT"
    local profile = type(config) == "table" and type(config.Profiles) == "table" and config.Profiles[name]
    if type(profile) ~= "table" or type(profile.designs) ~= "table" then return nil end
    return profile.designs, name
end

local function fontOf(design)
    return type(design) == "table" and type(design.font) == "table"
        and type(design.font.asset) == "string" and design.font
end

-- Every font a theme can put there: the library's and Morpheus (Glass).
local function themeFonts()
    local set = { Morpheus = true }
    for _, f in ipairs(LibForeverThemes.FONTS) do set[f.name] = true end
    return set
end

local function registerFonts()
    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    if not lsm then return end
    for font in pairs(themeFonts()) do
        lsm:Register("font", font, ns.Media.FontPath(font), lsm.LOCALE_BIT_western)
    end
end

-- font into every design; new designs go into the snapshot. A design that
-- already has a theme font is a copy of a themed design (or was themed by
-- another Forever addon): it gets Platynator's own font back later.
local function apply(store, font)
    local list, profile = designs()
    if not list then return end
    local ours = themeFonts()
    store.snapshot = store.snapshot or {}
    local snap = store.snapshot[profile] or {}
    store.snapshot[profile] = snap
    for name, design in pairs(list) do
        local f = fontOf(design)
        if f then
            if snap[name] == nil then snap[name] = ours[f.asset] and PLATYNATOR_DEFAULT or f.asset end
            f.asset = font
        end
    end
end

local function restore(store)
    local list, profile = designs()
    local snap = list and store.snapshot and store.snapshot[profile]
    for name, asset in pairs(snap or {}) do
        local f = fontOf(list[name])
        if f then f.asset = asset end
    end
    store.snapshot = nil
end

function PlatynatorFonts.Enabled() return ns.AccountDB().platynatorFont == true end

function PlatynatorFonts.SetEnabled(on)
    ns.AccountDB().platynatorFont = on and true or nil
    PlatynatorFonts.Refresh()
end

-- After a switch or a theme change: the designs follow when the font
-- changed. Nothing without Platynator.
function PlatynatorFonts.Refresh()
    if not designs() then return end
    local font = PlatynatorFonts.Enabled() and ns.Themes.Font() or nil
    local db = ns.AccountDB()
    local store = db.platynator or {}
    if font == store.font then return end
    db.platynator = store
    if font then apply(store, font) else restore(store) end
    store.font = font
    ns.Print(ns.L.PLATYNATOR_RELOAD)
end

-- Platynator loading: fonts to LibSharedMedia, new designs get the font.
-- ForeverThemesDB read as it is: Platynator may load before us.
function PlatynatorFonts.OnLoaded()
    registerFonts()
    local store = ForeverThemesDB and ForeverThemesDB.platynator
    if store and store.font then apply(store, store.font) end
end

ns.On("ADDON_LOADED", function(_, name) if name == "Platynator" then PlatynatorFonts.OnLoaded() end end)
-- Platynator loaded before us: done now (once more does no harm).
ns.On("PLAYER_LOGIN", function()
    if _G.Platynator then PlatynatorFonts.OnLoaded() end
    PlatynatorFonts.Refresh()
end)
ns.Settings.OnChange(function() PlatynatorFonts.Refresh() end)
