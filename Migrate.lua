local _, ns = ...

-- The first run (ForeverThemesDB.migrated not set yet) decides the switches
-- this addon took over from the others, so installing it changes nothing a
-- player sees. With any Forever addon registered, every switch is exactly
-- what those addons had, off included: Forever Unit Frames' "Theme font for
-- Blizzard texts" / "for Platynator" (General in the character's active
-- profile: ForeverUnitFramesDB.profiles[name].general.themeBlizzardFonts /
-- .themePlatynatorFont), InfoPanel's font menus for Blizzard texts and
-- Platynator (InfoPanelDB.blizzardFonts.theme, .platynator.theme: any theme
-- but Classic) and its window skins (InfoPanelDB.skin<Window>, our names);
-- the author's colours (Core.lua) go too. Without any Forever addon the
-- author's choices from ns.NewAccountDB stay. At PLAYER_LOGIN every saved
-- variable is there and the addons have registered (at file load); this
-- file's handler runs before the bridges' and skins'.
local Migrate = {}
ns.Migrate = Migrate

local SKINS = ns.SKINS

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

-- true or nil, as the switches are stored.
local function on(value) return value and true or nil end

function Migrate.Run()
    local db = ns.AccountDB()
    if db.migrated then return end
    db.migrated = true
    if #ns.Hub.Addons() == 0 then return end
    local general = unitFramesGeneral() or {}
    local panel = type(_G.InfoPanelDB) == "table" and _G.InfoPanelDB or {}
    db.blizzardTexts = on(general.themeBlizzardFonts == true or themed(panel.blizzardFonts))
    db.platynatorFont = on(general.themePlatynatorFont == true or themed(panel.platynator))
    for _, key in ipairs(SKINS) do db[key] = on(panel[key] == true) end
    if not db.theme then db.colors = nil end
end

ns.On("PLAYER_LOGIN", Migrate.Run)
