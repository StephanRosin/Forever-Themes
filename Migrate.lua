local _, ns = ...

-- The first run takes over what the player switched on in the addons whose
-- jobs this one does now, so nothing looks different with it: Forever Unit
-- Frames' "Theme font for Blizzard texts" / "for Platynator" (General in
-- the character's active profile: ForeverUnitFramesDB.profiles[name].general
-- .themeBlizzardFonts / .themePlatynatorFont), InfoPanel's font menus for
-- Blizzard texts and Platynator (InfoPanelDB.blizzardFonts.theme,
-- .platynator.theme: any theme but Classic) and its window skins
-- (InfoPanelDB.skin<Window>, our names). Only switches on, once
-- (ForeverThemesDB.migrated). At PLAYER_LOGIN every saved variable is
-- there; this file's handler runs before the bridges' and skins'.
local Migrate = {}
ns.Migrate = Migrate

local SKINS = { "skinCharacter", "skinSpellbook", "skinTalents", "skinProfessions", "skinLegacy",
    "skinCommunities", "skinCollections" }

-- Unit Frames' General of this character's profile (its UnitProfiles.lua:
-- .active["Name-Realm"], else Default; .profile is an older version's).
local function unitFramesGeneral()
    local db = _G.ForeverUnitFramesDB
    if type(db) ~= "table" then return nil end
    local profiles = type(db.profiles) == "table" and db.profiles or {}
    local name, realm = UnitFullName("player")
    if not realm or realm == "" then realm = GetNormalizedRealmName() end
    local active = type(db.active) == "table" and name and db.active[name .. "-" .. tostring(realm)]
    local profile = profiles[active] or profiles.Default or db.profile
    return type(profile) == "table" and type(profile.general) == "table" and profile.general or nil
end

local function themed(store)
    return type(store) == "table" and type(store.theme) == "string" and store.theme ~= "CLASSIC"
end

function Migrate.Run()
    local db = ns.AccountDB()
    if db.migrated then return end
    db.migrated = true
    local general = unitFramesGeneral() or {}
    local panel = type(_G.InfoPanelDB) == "table" and _G.InfoPanelDB or {}
    if general.themeBlizzardFonts == true or themed(panel.blizzardFonts) then db.blizzardTexts = true end
    if general.themePlatynatorFont == true or themed(panel.platynator) then db.platynatorFont = true end
    for _, key in ipairs(SKINS) do
        if panel[key] == true then db[key] = true end
    end
end

ns.On("PLAYER_LOGIN", Migrate.Run)
