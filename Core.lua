local ADDON, ns = ...
local L = ns.L

-- Small shared helpers: chat output, an event dispatcher, the saved
-- variables and the change notice the skins and bridges listen to.

function ns.Print(fmt, ...)
    local msg = (select("#", ...) > 0) and string.format(fmt, ...) or fmt
    local frame = DEFAULT_CHAT_FRAME or ChatFrame1
    if frame then frame:AddMessage("|cff66ccff" .. L.ADDON_NAME .. "|r: " .. msg) end
end

-- fn(event, ...) per event. RegisterEvent throws on a name the client does
-- not know, which would stop the rest of the file: pcall.
local handlers = {}
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(handlers[event] or {}) do fn(event, ...) end
end)

function ns.On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        pcall(events.RegisterEvent, events, event)
    end
    table.insert(handlers[event], fn)
end

-- ForeverThemesDB, account wide:
--   theme, colors[theme]   the central theme and the colour chosen per theme
--   follow[folder] = false an addon that keeps its own theme (nil: follows)
--   skin<Window>           a Blizzard window skin switched on
--   blizzardTexts, damageFont, platynator   the Blizzard texts and Platynator bridges
--   minimapShow, minimapAngle, language
--   migrated               the first run's take-over done (Migrate.lua)
function ns.AccountDB()
    ForeverThemesDB = ForeverThemesDB or {}
    return ForeverThemesDB
end

-- The skins were written against an addon with settings; this is the part
-- of that they use: defaults for colours a theme does not set, and a
-- notice after every change of the central theme, colour or a switch.
local Settings = { DEFAULTS = { borderColor = { 0, 0, 0, 1 }, headerColor = { 1, 0.82, 0.29 },
    valueColor = { 0.84, 0.82, 0.78 } } }
ns.Settings = Settings
local listeners = {}
function Settings.OnChange(fn) listeners[#listeners + 1] = fn end
function Settings.Changed()
    for _, fn in ipairs(listeners) do fn() end
end
