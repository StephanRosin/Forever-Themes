--[[---------------------------------------------------------------------------
Hub.lua -- the central theme carried to every Forever addon.

The addons register in _G.ForeverThemes (LibForeverThemes.Register):
{ title, Current, Switch, Colors, Color, SetColor }. Each one follows the
central theme and colour (the default) or keeps its own
(ForeverThemesDB.follow[folder] = false); the hub then leaves it alone. An
addon follows through the same Switch / SetColor calls as "Apply to all";
one without the theme refuses (UNKNOWN) and is skipped.

When: after login (a moment later: the addons set up in their own
PLAYER_LOGIN), after every change of the central theme or colour, or of a
follow flag, and when an addon asks (LibForeverThemes.Hub().Sync, e.g.
after its profile changed). An addon may refuse for a while (COMBAT, Unit
Frames' WAITING for its backup): tried again after combat and every
RETRY_SECONDS, at most MAX_RETRIES times, then the chat names it.

First run (no central theme yet): nothing may change for the player. The
central theme is the most common one among the addons that wear a theme
(Classic does not count; tie: Unit Frames', else the first in the theme
order), its colour the most common among those wearing it; every addon whose
theme or colour differs keeps its own. All of them on Classic: the central
theme is Classic. No Forever addon at all: DEFAULT_THEME. This
waits until every addon answers (Switch to its own current theme is a
no-op that still reports a refusal), so a theme is never read from an addon
that has not loaded its settings yet; only COMBAT and WAITING are waited
for, an addon refusing anything else is left out of the vote.

The follow flags are account wide, the addons and their profiles are not:
the folders seen at the seed are remembered (ForeverThemesDB.known). An
addon first seen later (installed later, or only on another character)
follows only when it already wears the central theme and colour, else it
keeps its own. Forever Unit Frames keeps a theme per profile: following
changes the theme of the character's active profile only.
-----------------------------------------------------------------------------]]

local _, ns = ...
local Lib = LibForeverThemes
local Themes = ns.Themes

local Hub = {}
ns.Hub = Hub

local TIE_BREAKER = "ForeverUnitFrames"
local DEFAULT_THEME = "PITWALL"
local RETRY_SECONDS, MAX_RETRIES = 2, 30

-- The registered addons, by title: { folder, title, entry }.
function Hub.Addons()
    local list = {}
    for folder, entry in pairs(_G.ForeverThemes or {}) do
        if type(entry) == "table" and type(entry.Current) == "function"
            and type(entry.Switch) == "function" then
            list[#list + 1] = { folder = folder, title = tostring(entry.title or folder), entry = entry }
        end
    end
    table.sort(list, function(a, b) return a.title < b.title end)
    return list
end

local function hasColors(entry)
    return type(entry.Colors) == "function" and type(entry.Color) == "function"
        and type(entry.SetColor) == "function"
end

local function listed(ids, id)
    for _, v in ipairs(ids or {}) do
        if v == id then return true end
    end
    return false
end

-- A call into another addon: its error stops nothing here, it is reported.
local reported = {}
local function call(addon, fn, ...)
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
    if not reported[addon.folder] then
        reported[addon.folder] = true
        ns.Print(ns.L.MSG_ADDON_ERROR, addon.title, tostring(a))
    end
    return nil, "ERROR"
end

function Hub.Follows(folder)
    local follow = ns.AccountDB().follow
    return not (follow and follow[folder] == false)
end

function Hub.SetFollows(folder, on)
    local store = ns.AccountDB()
    store.follow = store.follow or {}
    store.known = store.known or {}
    store.known[folder] = true
    if on then
        store.follow[folder] = nil
        Hub.Sync()
    else
        store.follow[folder] = false
    end
end

-- The addon's theme and colour (colour nil: none).
function Hub.Current(addon)
    local theme = call(addon, addon.entry.Current)
    local color = theme and hasColors(addon.entry) and call(addon, addon.entry.Color, theme) or nil
    return theme, color
end

-- Refusals that pass: asked again later. Any other (UNKNOWN, ERROR, an
-- addon's own like NO_DESIGNS) is for good.
local WAIT = { COMBAT = true, WAITING = true }

-- Whether the addon takes a switch now (see the header): true; false and
-- "Title (WHY)" while it waits; nil when it refuses for good.
local function ready(addon)
    local theme = call(addon, addon.entry.Current)
    local done, why = call(addon, addon.entry.Switch, theme)
    if done ~= nil then return true end
    if WAIT[why] then return false, ("%s (%s)"):format(addon.title, why) end
    return nil
end

-- One addon onto theme and color. Returns a reason to try again, or nil.
local function follow(addon, theme, color)
    local entry = addon.entry
    if call(addon, entry.Current) ~= theme then
        local done, why = call(addon, entry.Switch, theme)
        if not done then
            if why == "UNKNOWN" or why == "ERROR" then return nil end
            return why or "?"
        end
    end
    if not (color and hasColors(entry)) or not listed(call(addon, entry.Colors, theme), color)
        or call(addon, entry.Color, theme) == color then
        return nil
    end
    local done, why = call(addon, entry.SetColor, color, theme)
    if not done and why ~= "UNKNOWN" and why ~= "ERROR" then return why or "?" end
    return nil
end

local function mostCommon(counts, preferred, order)
    local best, bestCount = nil, 0
    for _, id in ipairs(order) do
        local n = counts[id] or 0
        if n > bestCount or (n == bestCount and n > 0 and id == preferred) then best, bestCount = id, n end
    end
    return best
end

-- The seeded theme, and the bridges and skins told once: Themes.Switch
-- does that for a choice, the seed writes the store itself. A moment later:
-- not inside Sync, which the notice runs again.
local function seeded(store, theme)
    store.theme = theme
    C_Timer.After(0, ns.Settings.Changed)
end

-- The first run's central theme from the addons (see the header). Returns
-- false and who is waiting while an addon is not ready, true when done or
-- nothing to do.
function Hub.Seed()
    if Themes.IsSet() then return true end
    local addons = Hub.Addons()
    local themes, current = {}, {}
    local store = ns.AccountDB()
    store.known = {}
    for _, addon in ipairs(addons) do
        local ok, waiting = ready(addon)
        if ok == false then return false, waiting end
        if ok then
            local theme, color = Hub.Current(addon)
            current[addon.folder] = { theme = theme, color = color }
            store.known[addon.folder] = true
            if theme and theme ~= Themes.CLASSIC then themes[theme] = (themes[theme] or 0) + 1 end
        end
    end
    local preferred = current[TIE_BREAKER] or {}
    local theme = mostCommon(themes, preferred.theme, Lib.IDS)
    if not theme then
        -- Forever addons all on Classic stay Classic: installing the hub
        -- changes nothing a player already sees. Pitwall only for a start
        -- without any themed Forever addon at all.
        seeded(store, #addons > 0 and Themes.CLASSIC or DEFAULT_THEME)
        return true
    end
    local colors = {}
    for _, now in pairs(current) do
        if now.theme == theme and now.color then colors[now.color] = (colors[now.color] or 0) + 1 end
    end
    local color = mostCommon(colors, preferred.theme == theme and preferred.color or nil, Lib.Colors(theme))
    store.follow = store.follow or {}
    for folder, now in pairs(current) do
        if now.theme ~= theme or (color and now.color and now.color ~= color) then store.follow[folder] = false end
    end
    if color then
        store.colors = store.colors or {}
        store.colors[theme] = color
    end
    seeded(store, theme)
    return true
end

-- An addon not seen before (see the header): follows when it wears theme
-- and color already, else keeps its own. Returns "Title (WHY)" while it
-- waits; an addon refusing for good is asked again next time.
local function adopt(addon, store, theme, color)
    local ok, waiting = ready(addon)
    if not ok then return waiting end
    local now, nowColor = Hub.Current(addon)
    if now ~= theme or (color and nowColor and nowColor ~= color) then
        store.follow = store.follow or {}
        store.follow[addon.folder] = false
    end
    store.known[addon.folder] = true
    return nil
end

local tries, waiting, scheduled = 0, false, false

-- Seed if needed, then every following addon onto the central theme.
function Hub.Sync()
    local pending = {}
    local done, who = Hub.Seed()
    if not done then
        pending[1] = who
    else
        local store, theme, color = ns.AccountDB(), Themes.Current(), Themes.Color()
        -- Seeded by 1.0.1, before folders were remembered: those there now count as seen.
        if not store.known then
            store.known = {}
            for _, addon in ipairs(Hub.Addons()) do store.known[addon.folder] = true end
        end
        for _, addon in ipairs(Hub.Addons()) do
            local why = not store.known[addon.folder] and adopt(addon, store, theme, color)
            if why then
                pending[#pending + 1] = why
            elseif store.known[addon.folder] and Hub.Follows(addon.folder) then
                why = follow(addon, theme, color)
                if why then pending[#pending + 1] = ("%s (%s)"):format(addon.title, why) end
            end
        end
    end
    if #pending == 0 then
        tries = 0
        return
    end
    tries = tries + 1
    if tries > MAX_RETRIES then
        tries = 0
        ns.Print(ns.L.MSG_REFUSED, table.concat(pending, ", "))
        return
    end
    if InCombatLockdown() then waiting = true; return end
    if scheduled then return end
    scheduled = true
    C_Timer.After(RETRY_SECONDS, function() scheduled = false; Hub.Sync() end)
end

-- Sync soon, for the other addons (their profile changed, was reset or
-- imported): any number of asks in one moment make one Sync, in combat
-- after it. Before login nothing: the login's Sync comes anyway.
local asked, loggedIn = false, false
function Hub.Request()
    if not loggedIn then return end
    if InCombatLockdown() then waiting = true; return end
    if asked then return end
    asked = true
    C_Timer.After(0, function() asked = false; Hub.Sync() end)
end

ns.On("PLAYER_REGEN_ENABLED", function()
    if waiting then waiting = false; Hub.Sync() end
end)
ns.On("PLAYER_LOGIN", function()
    loggedIn = true
    C_Timer.After(0, Hub.Sync)
end)
ns.Settings.OnChange(Hub.Sync)

-- For the other addons: LibForeverThemes.Hub() (DESIGN.md of the library).
Lib.SetHub({
    Follows = Hub.Follows,
    Sync = Hub.Request,
    Theme = function() return Themes.Current() end,
    Color = function() return Themes.Color() end,
    OpenMenu = function(anchor) ns.Menu.Open(anchor) end,
    OpenOptions = function() ns.Window.Open() end,
})
