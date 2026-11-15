--[[---------------------------------------------------------------------------
Hub.lua -- the central theme carried to every Forever addon.

The addons register in _G.ForeverThemes (LibForeverThemes.Register):
{ title, Current, Switch, Colors, Color, SetColor }. Each one follows the
central theme and colour (the default) or keeps its own
(ForeverThemesDB.follow[folder] = false); the hub then leaves it alone. An
addon follows through the same Switch / SetColor calls as "Apply to all";
one without the theme refuses (UNKNOWN) and is skipped.

When: after login (a moment later: the addons set up in their own
PLAYER_LOGIN) and after every change of the central theme or colour, or of a
follow flag. An addon may refuse for a while (COMBAT, Unit Frames' WAITING
for its backup): tried again after combat and every RETRY_SECONDS, at most
MAX_RETRIES times, then the chat names it.

First run (no central theme yet): nothing may change for the player. The
central theme is the most common one among the addons that wear a theme
(Classic does not count; tie: Unit Frames', else the first in the theme
order), its colour the most common among those wearing it; every addon whose
theme or colour differs keeps its own. All of them on Classic: the central
theme is Classic. No Forever addon at all: DEFAULT_THEME. This
waits until every addon answers (Switch to its own current theme is a
no-op that still reports a refusal), so a theme is never read from an addon
that has not loaded its settings yet.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
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
        if folder ~= ADDON and type(entry) == "table" and type(entry.Current) == "function"
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

-- Whether the addon takes a switch now (see the header).
local function ready(addon)
    local theme = call(addon, addon.entry.Current)
    local done, why = call(addon, addon.entry.Switch, theme)
    return done ~= nil, why
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

-- The first run's central theme from the addons (see the header). Returns
-- false while an addon is not ready, true when done or nothing to do.
function Hub.Seed()
    if Themes.IsSet() then return true end
    local addons = Hub.Addons()
    local themes, current = {}, {}
    for _, addon in ipairs(addons) do
        if not ready(addon) then return false end
        local theme, color = Hub.Current(addon)
        current[addon.folder] = { theme = theme, color = color }
        if theme and theme ~= Themes.CLASSIC then themes[theme] = (themes[theme] or 0) + 1 end
    end
    local store = ns.AccountDB()
    local preferred = current[TIE_BREAKER] or {}
    local theme = mostCommon(themes, preferred.theme, Lib.IDS)
    if not theme then
        -- Forever addons all on Classic stay Classic: installing the hub
        -- changes nothing a player already sees. Pitwall only for a start
        -- without any themed Forever addon at all.
        store.theme = #addons > 0 and Themes.CLASSIC or DEFAULT_THEME
        return true
    end
    local colors = {}
    for _, now in pairs(current) do
        if now.theme == theme and now.color then colors[now.color] = (colors[now.color] or 0) + 1 end
    end
    local color = mostCommon(colors, preferred.theme == theme and preferred.color or nil, Lib.Colors(theme))
    store.follow = store.follow or {}
    for _, addon in ipairs(addons) do
        local now = current[addon.folder]
        if now.theme ~= theme or (color and now.color and now.color ~= color) then store.follow[addon.folder] = false end
    end
    if color then
        store.colors = store.colors or {}
        store.colors[theme] = color
    end
    store.theme = theme
    return true
end

local tries, waiting, scheduled = 0, false, false

-- Seed if needed, then every following addon onto the central theme.
function Hub.Sync()
    local pending = {}
    if not Hub.Seed() then
        pending[1] = "?"
    elseif Themes.IsSet() then
        local theme, color = Themes.Current(), Themes.Color()
        for _, addon in ipairs(Hub.Addons()) do
            if Hub.Follows(addon.folder) then
                local why = follow(addon, theme, color)
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

ns.On("PLAYER_REGEN_ENABLED", function()
    if waiting then waiting = false; Hub.Sync() end
end)
ns.On("PLAYER_LOGIN", function() C_Timer.After(0, Hub.Sync) end)
ns.Settings.OnChange(Hub.Sync)

-- For the other addons: LibForeverThemes.Hub() (DESIGN.md of the library).
Lib.SetHub({
    Follows = Hub.Follows,
    Theme = function() return Themes.Current() end,
    Color = function() return Themes.Color() end,
    OpenMenu = function(anchor) ns.Menu.Open(anchor) end,
    OpenOptions = function() ns.Window.Open() end,
})
