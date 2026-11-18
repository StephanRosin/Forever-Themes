-- Tests for Forever Themes: the hub, the library hand-off, the Blizzard
-- text bridges, options and locales. The window skins have their own files
-- (skin_*.lua). Run with tests/run (Lua 5.1, as in the game).
local M = dofile("wowmock.lua")

local pass, fail = 0, 0
local function check(label, got, want)
    if got == want then
        pass = pass + 1
    else
        fail = fail + 1
        print(("  FAIL %-56s -> %s   (want: %s)"):format(label, tostring(got), tostring(want)))
    end
end
local function section(name) print(name) end

-- Fake Forever addons in the registry, as their Themes.lua register.
-- refuse: a reason Switch and SetColor give while set (COMBAT, WAITING).
local calls = {}
local function addon(folder, theme, color, opts)
    opts = opts or {}
    local a = { theme = theme, colors = { [theme] = color }, refuse = nil }
    local has = opts.themes or { CLASSIC = true, WOOD = true, PITWALL = true, FROST = true, TECH = true }
    local entry = { title = opts.title or folder }
    function entry.Current() return a.theme end
    function entry.Switch(id)
        if not has[id] then return nil, "UNKNOWN" end
        if a.refuse then return nil, a.refuse end
        if id ~= a.theme then calls[#calls + 1] = folder .. ">" .. id end
        a.theme = id
        return true
    end
    if not opts.noColors then
        function entry.Colors(id) return LibForeverThemes.Colors(id or a.theme) end
        function entry.Color(id) id = id or a.theme; return LibForeverThemes.ValidColor(id, a.colors[id]) end
        function entry.SetColor(c, id)
            if a.refuse then return nil, a.refuse end
            calls[#calls + 1] = folder .. ":" .. c
            a.colors[id or a.theme] = c
            return true
        end
    end
    a.entry = entry
    return a
end

-- Registered at file load, as the real addons do (before ours or after).
_G.ForeverThemes = {}
local fuf = addon("ForeverUnitFrames", "PITWALL", "ORANGE", { title = "Forever Unit Frames" })
local ql = addon("ForeverQuestLog", "WOOD", "WALNUT", { title = "Forever Quest Log" })
local cm = addon("ForeverCombatMeter", "PITWALL", "ORANGE", { title = "Forever Combat Meter" })
local db = addon("ForeverDataBar", "WOOD", "OAK", { title = "Forever Data Bar" })
local old = addon("OldAddon", "PITWALL", nil, { noColors = true })
for folder, a in pairs({ ForeverUnitFrames = fuf, ForeverQuestLog = ql, ForeverCombatMeter = cm,
    ForeverDataBar = db, OldAddon = old }) do
    _G.ForeverThemes[folder] = a.entry
end
fuf.refuse = "WAITING"

local ns, files = dofile("load.lua")()
local Lib, Hub, Themes = LibForeverThemes, ns.Hub, ns.Themes

section("Embedded LibForeverThemes")
check("TOC: the library first", files[1], "Libs/LibForeverThemes/LibForeverThemes.lua")
check("library from our copy", Lib.FOLDER, "ForeverThemes")
check("hub API there", type(Lib.Hub()), "table")
local LIBREPO = ADDONDIR .. "/../ForeverThemes"
if io.open(LIBREPO .. "/LibForeverThemes.lua") then
    local diff = io.popen("diff -rq '" .. LIBREPO .. "/LibForeverThemes.lua' '" .. ADDONDIR
        .. "/Libs/LibForeverThemes/LibForeverThemes.lua' && diff -rq '" .. LIBREPO .. "/Media' '" .. ADDONDIR
        .. "/Libs/LibForeverThemes/Media' 2>&1"):read("*a")
    check("copy equals ForeverThemes (there: tools/sync)", diff, "")
end

local function fire(event, ...)
    for _, f in ipairs(M.frames) do
        local fn = f:GetScript("OnEvent")
        if f._events[event] and fn then fn(f, event, ...) end
    end
end
local function runTimers()
    local list = M.timers
    M.timers = {}
    for _, fn in ipairs(list) do fn() end
end

ForeverThemesDB = nil
fire("ADDON_LOADED", "ForeverThemes")
fire("PLAYER_LOGIN")

section("First run: seeded without a visible change")
check("nothing before the moment after login", Themes.IsSet(), false)
runTimers()
check("waits while an addon refuses (Unit Frames WAITING)", Themes.IsSet(), false)
check("no switch while waiting", #calls, 0)
check("the waiting addon is named, not \"?\"", #M.timers, 1)
fuf.refuse = nil
runTimers()
check("seeded: the change told a moment later", #M.timers, 1)
runTimers()
check("central theme: the tie goes to Unit Frames'", ForeverThemesDB.theme, "PITWALL")
check("central colour: the most common on it", Themes.Color(), "ORANGE")
check("Unit Frames follows", Hub.Follows("ForeverUnitFrames"), true)
check("Combat Meter follows", Hub.Follows("ForeverCombatMeter"), true)
check("an addon without colours on the theme follows", Hub.Follows("OldAddon"), true)
check("Quest Log (Wood) keeps its own", Hub.Follows("ForeverQuestLog"), false)
check("Data Bar (Wood) keeps its own", Hub.Follows("ForeverDataBar"), false)
check("nothing switched", table.concat(calls, " "), "")

section("Change: the followers follow")
calls = {}
Themes.Switch("FROST")
table.sort(calls)
check("followers switched, own left alone", table.concat(calls, " "), "ForeverCombatMeter>FROST ForeverUnitFrames>FROST OldAddon>FROST")
calls = {}
Themes.SetColor("NIGHT")
table.sort(calls)
check("colour only where the addon has colours", table.concat(calls, " "), "ForeverCombatMeter:NIGHT ForeverUnitFrames:NIGHT")
calls = {}
Themes.SetColor("NIGHT")
check("the same colour again calls nobody", #calls, 0)
calls = {}
Hub.SetFollows("ForeverQuestLog", true)
check("follow again: switched at once", table.concat(calls, " "), "ForeverQuestLog>FROST ForeverQuestLog:NIGHT")
Hub.SetFollows("ForeverQuestLog", false)
check("own: stored as false", ForeverThemesDB.follow.ForeverQuestLog, false)
calls = {}
Themes.Switch("WOOD")
check("own: not switched", ql.theme, "FROST")

section("A theme an addon lacks is skipped")
local gf = addon("ForeverGroupFinder", "WOOD", "OAK", { themes = { WOOD = true, CLASSIC = true } })
_G.ForeverThemes.ForeverGroupFinder = gf.entry
Themes.Switch("TECH")
check("lacking addon unchanged", gf.theme, "WOOD")
check("no retry for it", #M.timers, 0)
-- The HD themes: offered here; an addon without them (written before) keeps
-- its own theme and colour, quietly, while one that has them follows.
local hd = addon("ForeverHdAddon", "TECH", nil, { themes = { TECH = true, WOOD_HD = true } })
_G.ForeverThemes.ForeverHdAddon = hd.entry
ForeverThemesDB.known.ForeverHdAddon = true
calls = {}
local chatBefore = #M.chat
check("HD theme offered centrally", Themes.Switch("WOOD_HD"), true)
check("HD colour", Themes.SetColor("EBONY"), true)
check("HD addon follows with the colour", hd.theme .. "/" .. hd.entry.Color(), "WOOD_HD/EBONY")
check("addons without HD keep their theme", gf.theme .. " " .. fuf.theme .. " " .. old.theme, "WOOD TECH TECH")
check("no colour sent where the theme was refused", table.concat(calls, " "):find("ForeverUnitFrames:", 1, true), nil)
check("no retry, no message", #M.timers .. " " .. #M.chat - chatBefore, "0 0")
local switched, failed = Lib.ApplyToAll("SomeAddon", "WOOD_HD", "EBONY")
check("Apply to all: addons without HD skipped, no error", switched .. " " .. #failed .. " " .. ql.theme, "0 0 FROST")
_G.ForeverThemes.ForeverHdAddon = nil
Themes.Switch("TECH")

section("Refused in combat: again after combat")
fuf.refuse = "COMBAT"
M.combat = true
Themes.Switch("PITWALL")
check("refused in combat", fuf.theme, "TECH")
check("no timer in combat", #M.timers, 0)
M.combat = false
fuf.refuse = nil
fire("PLAYER_REGEN_ENABLED")
check("after combat: switched", fuf.theme, "PITWALL")

section("Refused for a while: tried again, then named")
fuf.refuse = "WAITING"
Themes.Switch("FROST")
check("a retry is scheduled", #M.timers, 1)
Themes.SetColor("DEEP")
check("one timer, not two", #M.timers, 1)
for _ = 1, 40 do runTimers() end
local said = M.chat[#M.chat] or ""
check("the chat names the refusing addon", said:find("Forever Unit Frames (WAITING)", 1, true) ~= nil, true)
fuf.refuse = nil

section("An addon's error stops nobody")
local broken = addon("Broken", "TECH", "CYAN")
broken.entry.Switch = function() error("boom") end
_G.ForeverThemes.Broken = broken.entry
calls = {}
Themes.Switch("WOOD")
check("the others still switch", fuf.theme, "WOOD")
local reportedBoom = false
for _, line in ipairs(M.chat) do if line:find("boom", 1, true) then reportedBoom = true end end
check("the error is in the chat", reportedBoom, true)
_G.ForeverThemes.Broken = nil

section("Library API for the other addons")
local api = Lib.Hub()
check("Theme()", api.Theme(), "WOOD")
check("Color()", api.Color(), Themes.Color())
check("Follows: own", api.Follows("ForeverQuestLog"), false)
check("Follows: unknown addon follows", api.Follows("SomethingNew"), true)

section("Defaults: the author's choices on a new ForeverThemesDB only")
do
    local saved = _G.ForeverThemes
    _G.ForeverThemes = {}
    ForeverThemesDB = nil
    local fresh = ns.AccountDB()
    local on = 0
    for _, key in ipairs(ns.SKINS) do if fresh[key] == true then on = on + 1 end end
    check("new: every window skin on", on, 7)
    check("new: Blizzard texts on", fresh.blizzardTexts, true)
    check("new: Platynator on", fresh.platynatorFont, true)
    check("new: no theme before the seed", Themes.IsSet(), false)
    Hub.Sync()
    check("no addon to take over: Pitwall", Themes.Current(), "PITWALL")
    check("Pitwall in red", Themes.Color(), "RED")
    check("Comic in black once picked", Themes.Color("COMIC"), "BLACK")
    local stored = { theme = "WOOD", colors = { PITWALL = "ORANGE" } }
    ForeverThemesDB = stored
    check("a stored DB is not filled up", ns.AccountDB().skinTalents, nil)
    check("its colours stay", Themes.Color("PITWALL"), "ORANGE")
    check("its theme stays", Themes.Current(), "WOOD")
    _G.ForeverThemes = saved
end
ForeverThemesDB = { theme = "WOOD", follow = { ForeverQuestLog = false }, migrated = true }

section("Blizzard texts")
local bar = CreateFrame("StatusBar", "PlayerCastingBarFrame")
_G.PlayerCastingBarFrame = bar
bar.Text = bar:CreateFontString()
bar._scriptHooks = {}
local errorsFrame = CreateFrame("MessageFrame", "UIErrorsFrame")
_G.UIErrorsFrame = errorsFrame
function errorsFrame:GetFont() return "Fonts\\FRIZQT__.TTF", 14, "OUTLINE" end
function errorsFrame:SetFont(p, s, f) self._font = { p, s, f } end
function errorsFrame:GetObjectType() return "MessageFrame" end
local combatText = { _font = { "Fonts\\FRIZQT__.TTF", 25, "" } }
_G.CombatTextFont = combatText
function combatText:GetFont() return unpack(self._font) end
function combatText:SetFont(p, s, f) self._font = { p, s, f } end
function combatText:GetFontObject() return nil end
function combatText:GetObjectType() return "Font" end
local swing = CreateFrame("Frame", "SwingTimerMainHandFrame")
_G.SwingTimerMainHandFrame = swing
swing.StatusBar = CreateFrame("StatusBar", nil, swing)
swing.StatusBar.TypeLabel = swing.StatusBar:CreateFontString()
swing.StatusBar.TimeLabel = swing.StatusBar:CreateFontString()
-- Baganator's skin API: the slots there are, a listener for new ones.
local bagSlot = CreateFrame("Button")
bagSlot.Count = bagSlot:CreateFontString()
local bagLevel = bagSlot:CreateFontString()
local bagFrames, bagListeners = { { regionType = "ItemButton", region = bagSlot },
    { regionType = "CornerWidget", region = bagLevel } }, {}
Baganator = { API = { Skins = { GetAllFrames = function() return bagFrames end,
    RegisterListener = function(f) bagListeners[#bagListeners + 1] = f end } } }
local Fonts = ns.BlizzardFonts
check("off by default", Fonts.Enabled(), false)
Themes.Switch("PITWALL")
check("off: cast bar keeps Friz", (bar.Text:GetFont()), "Fonts\\FRIZQT__.TTF")
Fonts.SetEnabled(true)
local body = ns.Media.FontPath("Titillium Web SemiBold")
check("on: cast bar in the theme's text font", (bar.Text:GetFont()), body)
check("on: error line too", errorsFrame._font[1], body)
check("on: floating combat text too", combatText._font[1], body)
check("on: swing timer labels too", (swing.StatusBar.TypeLabel:GetFont()) .. " " .. (swing.StatusBar.TimeLabel:GetFont()),
    body .. " " .. body)
check("on: Baganator's stack count and item level too", (bagSlot.Count:GetFont()) .. " " .. (bagLevel:GetFont()),
    body .. " " .. body)
check("damage numbers kept for the next login", ForeverThemesDB.damageFont, "Titillium Web SemiBold")
Themes.Switch("WOOD")
check("Wood: Friz body gives the title font", (bar.Text:GetFont()), ns.Media.FontPath("Cinzel"))
Themes.Switch("CLASSIC")
check("Classic: cast bar back to Friz", (bar.Text:GetFont()), "Fonts\\FRIZQT__.TTF")
check("Classic: swing timer and bag back", (swing.StatusBar.TimeLabel:GetFont()) .. " " .. (bagSlot.Count:GetFont()),
    "Fonts\\FRIZQT__.TTF Fonts\\FRIZQT__.TTF")
check("Classic: no damage font", ForeverThemesDB.damageFont, nil)
Themes.Switch("FROST")
Fonts.SetEnabled(false)
check("off: back to Friz", (bar.Text:GetFont()), "Fonts\\FRIZQT__.TTF")
check("off: combat text back to Friz, size kept", combatText._font[1] .. combatText._font[2], "Fonts\\FRIZQT__.TTF25")
DAMAGE_TEXT_FONT = nil
ForeverThemesDB.damageFont = "Cinzel"
fire("ADDON_LOADED", "ForeverThemes")
check("damage font set as the addon loads", DAMAGE_TEXT_FONT, ns.Media.FontPath("Cinzel"))

section("Platynator")
PLATYNATOR_CONFIG = { Profiles = { DEFAULT = { designs = {
    mine = { font = { asset = "Roboto Condensed Bold" } },
    copy = { font = { asset = "Cinzel" } },
} } } }
local P = ns.PlatynatorFonts
local designs = PLATYNATOR_CONFIG.Profiles.DEFAULT.designs
Themes.Switch("PITWALL")
check("off: design untouched", designs.mine.font.asset, "Roboto Condensed Bold")
P.SetEnabled(true)
check("on: own design in the theme font", designs.mine.font.asset, "Titillium Web SemiBold")
check("on: chat asks for /reload", M.chat[#M.chat]:find("/reload", 1, true) ~= nil, true)
P.SetEnabled(false)
check("off: own font back", designs.mine.font.asset, "Roboto Condensed Bold")
check("off: a themed copy gets Platynator's own", designs.copy.font.asset, "Roboto Condensed Bold")
PLATYNATOR_CONFIG.Profiles.Raid = { designs = { raid = { font = { asset = "Friz Quadrata TT" } } } }
P.SetEnabled(true)
PLATYNATOR_CURRENT_PROFILE = "Raid"
Themes.Switch("WOOD")
check("another profile themed after a switch", PLATYNATOR_CONFIG.Profiles.Raid.designs.raid.font.asset, "Cinzel")
P.SetEnabled(false)
check("off: the active profile back", PLATYNATOR_CONFIG.Profiles.Raid.designs.raid.font.asset, "Friz Quadrata TT")
check("off: the other profile back too", designs.mine.font.asset, "Roboto Condensed Bold")
PLATYNATOR_CURRENT_PROFILE = nil
Themes.Switch("PITWALL")

section("Theme font: Forever Unit Frames' choice")
-- Its Core/Themes.lua: Themes.Font() is its spec's font, the library's
-- title font except Swiss', Console's and Pitwall's own.
local UNIT_FRAMES_FONT = { WOOD = "Cinzel", TECH = "Space Grotesk", PARCHMENT = "IM Fell English SC",
    RUNESTONE = "Marcellus", GLASS = "Morpheus", COMIC = "Bangers", FROST = "Julius Sans One", PIXEL = "VT323",
    SWISS = "Inter Tight", CONSOLE = "IBM Plex Mono", PITWALL = "Titillium Web" }
local differ = {}
for id, want in pairs(UNIT_FRAMES_FONT) do
    Themes.Switch(id)
    if Lib.FontName(Themes.Font() or "-") ~= Lib.FontName(want) then differ[#differ + 1] = id end
end
table.sort(differ)
check("every theme as Unit Frames", table.concat(differ, ","), "")
-- HD: the same font as its base, so the damage numbers too.
local hdDiffer = {}
for id in pairs(UNIT_FRAMES_FONT) do
    if Themes.SPECS[id .. "_HD"] then
        Themes.Switch(id .. "_HD")
        local hdFont = Themes.Font()
        Themes.Switch(id)
        if hdFont ~= Themes.Font() then hdDiffer[#hdDiffer + 1] = id .. "_HD" end
    end
end
table.sort(hdDiffer)
check("every HD theme in its base's font", table.concat(hdDiffer, ","), "")
Themes.Switch("COMIC_HD")
Fonts.SetEnabled(true)
check("Comic HD: damage numbers kept in Bangers", ForeverThemesDB.damageFont, "Bangers")
Fonts.SetEnabled(false)
Themes.Switch("CLASSIC")
check("Classic: none", Themes.Font(), nil)
Themes.Switch("COMIC")
Fonts.SetEnabled(true)
DAMAGE_TEXT_FONT = nil
fire("PLAYER_LOGIN")
runTimers()
check("Comic: damage numbers in Bangers", DAMAGE_TEXT_FONT, ns.Media.FontPath("Bangers"))
check("Comic: cast bar in Bangers", (bar.Text:GetFont()), ns.Media.FontPath("Bangers"))
local newSlot = CreateFrame("Button")
newSlot.Count = newSlot:CreateFontString()
for _, listener in ipairs(bagListeners) do listener({ regionType = "ItemButton", region = newSlot }) end
check("Comic: a bag slot made later in Bangers", (newSlot.Count:GetFont()), ns.Media.FontPath("Bangers"))
Fonts.SetEnabled(false)

section("Platynator: taken over from Unit Frames")
-- Unit Frames themed the designs under Pitwall (its older font name) and
-- has not stood down yet.
PLATYNATOR_CONFIG = { Profiles = { DEFAULT = { designs = {
    Tank = { font = { asset = "Titillium Web" } },
    _custom = { font = { asset = "Titillium Web" } },
    New = { font = { asset = "Friz Quadrata TT" } },
} } } }
designs = PLATYNATOR_CONFIG.Profiles.DEFAULT.designs
ForeverUnitFramesDB = { platynator = { font = "Titillium Web", snapshot = { DEFAULT = {
    Tank = "Friz Quadrata TT", _custom = "Roboto Condensed Bold" } } } }
ForeverThemesDB.platynator = nil
Themes.Switch("COMIC")
P.SetEnabled(true)
check("on: Bangers", designs.Tank.font.asset, "Bangers")
P.SetEnabled(false)
check("off: Unit Frames' original back", designs.Tank.font.asset, "Friz Quadrata TT")
check("off: its Platynator default back", designs._custom.font.asset, "Roboto Condensed Bold")
check("off: a design it never themed keeps its own", designs.New.font.asset, "Friz Quadrata TT")
ForeverUnitFramesDB = nil
designs.Tank.font.asset = "Friz Quadrata TT"
P.SetEnabled(true)
designs.Tank.font.asset = "Friz Quadrata TT" -- another addon put it back at its login
ForeverThemesDB.platynator = nil
fire("PLAYER_LOGIN")
check("login: not at once", designs.Tank.font.asset, "Friz Quadrata TT")
runTimers()
check("login: a moment later, after the others", designs.Tank.font.asset, "Bangers")
check("login: the original remembered", ForeverThemesDB.platynator.snapshot.DEFAULT.Tank, "Friz Quadrata TT")
P.SetEnabled(false)
PLATYNATOR_CONFIG = nil

section("First run from a fresh ForeverThemesDB, as the game makes it")
-- Login as the client runs it: no ForeverThemesDB, ADDON_LOADED,
-- PLAYER_LOGIN (the take-over), a moment later the hub's seed and then its
-- notice. registry: folder -> fake addon.
function UnitFullName() return "Testchar", "Testrealm" end
local keptDB, keptRegistry = ForeverThemesDB, _G.ForeverThemes
local FRIZ = "Fonts\\FRIZQT__.TTF"
local PITWALL_FONT = "Titillium Web SemiBold"
local function login(registry)
    _G.ForeverThemes = {}
    for folder, a in pairs(registry) do _G.ForeverThemes[folder] = a.entry end
    PLATYNATOR_CONFIG = { Profiles = { DEFAULT = { designs = { Mine = { font = { asset = "Roboto Condensed Bold" } } } } } }
    ForeverThemesDB = nil
    fire("ADDON_LOADED", "ForeverThemes")
    fire("PLAYER_LOGIN")
    runTimers()
    runTimers()
end
local function skinsOn()
    local n = 0
    for _, key in ipairs(ns.SKINS) do if ForeverThemesDB[key] then n = n + 1 end end
    return n
end
local function design() return PLATYNATOR_CONFIG.Profiles.DEFAULT.designs.Mine.font.asset end
local function reloadLines()
    local n = 0
    for _, line in ipairs(M.chat) do if line:find(ns.L.PLATYNATOR_RELOAD, 1, true) then n = n + 1 end end
    return n
end
local function unitFrames(general)
    ForeverUnitFramesDB = { active = { ["Testchar-Testrealm"] = "Healer" },
        profiles = { Default = { general = {} }, Healer = { general = general } } }
end

unitFrames({ themeBlizzardFonts = false, themePlatynatorFont = false })
InfoPanelDB = nil
login({ ForeverUnitFrames = addon("ForeverUnitFrames", "PITWALL", "ORANGE") })
check("Unit Frames on Pitwall: central Pitwall", Themes.Current(), "PITWALL")
check("its colour, not the author's red", Themes.Color(), "ORANGE")
check("its Blizzard texts off: stay off", ForeverThemesDB.blizzardTexts, nil)
check("its Platynator off: stays off", ForeverThemesDB.platynatorFont, nil)
check("no skin switched on", skinsOn(), 0)
check("cast bar untouched", (bar.Text:GetFont()), FRIZ)
check("Platynator design untouched", design(), "Roboto Condensed Bold")
check("the author's Comic black gone", ForeverThemesDB.colors.COMIC, nil)

section("Addons first seen after the seed")
local same = addon("SamePitwall", "PITWALL", "ORANGE")
local other = addon("OtherWood", "WOOD", "OAK")
_G.ForeverThemes.SamePitwall, _G.ForeverThemes.OtherWood = same.entry, other.entry
calls = {}
Hub.Sync()
check("wearing the central theme and colour: follows", Hub.Follows("SamePitwall"), true)
check("another theme: keeps its own", Hub.Follows("OtherWood"), false)
check("neither switched", table.concat(calls, " "), "")
check("both remembered", ForeverThemesDB.known.OtherWood and ForeverThemesDB.known.SamePitwall, true)
local waits = addon("WaitsLater", "WOOD", "OAK")
waits.refuse = "WAITING"
_G.ForeverThemes.WaitsLater = waits.entry
Hub.Sync()
check("waiting: not decided yet", ForeverThemesDB.known.WaitsLater, nil)
check("waiting: asked again", #M.timers, 1)
waits.refuse = nil
runTimers()
check("then decided: own", Hub.Follows("WaitsLater"), false)
calls = {}
Themes.Switch("FROST")
table.sort(calls)
check("a change moves only the followers", table.concat(calls, " "), "ForeverUnitFrames>FROST SamePitwall>FROST")

section("Hub().Sync for the other addons")
calls = {}
same.theme = "WOOD" -- its profile changed
Lib.Hub().Sync()
Lib.Hub().Sync()
check("asked twice: one Sync a moment later", #M.timers, 1)
runTimers()
check("synced: back on the central theme", same.theme, "FROST")
same.theme = "WOOD"
M.combat = true
Lib.Hub().Sync()
check("in combat: no timer", #M.timers, 0)
M.combat = false
fire("PLAYER_REGEN_ENABLED")
check("after combat: synced", same.theme, "FROST")

unitFrames({ themeBlizzardFonts = true, themePlatynatorFont = true })
login({ ForeverUnitFrames = addon("ForeverUnitFrames", "PITWALL", "ORANGE") })
check("its Blizzard texts on: on", ForeverThemesDB.blizzardTexts, true)
check("its Platynator on: on", ForeverThemesDB.platynatorFont, true)
check("still no skin", skinsOn(), 0)
check("seeded: cast bar in the theme font at once", (bar.Text:GetFont()), ns.Media.FontPath(PITWALL_FONT))
check("seeded: Platynator design at once", design(), PITWALL_FONT)

ForeverUnitFramesDB = nil
InfoPanelDB = { skinTalents = true, blizzardFonts = { theme = "WOOD" }, platynator = { theme = "WOOD" } }
local waiting = addon("ForeverUnitFrames", "PITWALL", "ORANGE")
waiting.refuse = "WAITING"
local chatBefore = #M.chat
login({ ForeverUnitFrames = waiting })
check("WAITING: not seeded yet", Themes.IsSet(), false)
check("InfoPanel's switches taken over", tostring(ForeverThemesDB.blizzardTexts) .. " "
    .. tostring(ForeverThemesDB.platynatorFont) .. " " .. skinsOn(), "true true 1")
check("WAITING: cast bar not yet", (bar.Text:GetFont()), FRIZ)
waiting.refuse = nil
runTimers()
runTimers()
check("on retry: seeded", Themes.Current(), "PITWALL")
check("on retry: cast bar in the theme font", (bar.Text:GetFont()), ns.Media.FontPath(PITWALL_FONT))
check("on retry: Platynator design", design(), PITWALL_FONT)
local refused = false
for i = chatBefore + 1, #M.chat do if M.chat[i]:find("?", 1, true) then refused = true end end
check("no \"?\" in the chat", refused, false)

section("A refusal for good does not hold the seed")
local noDesigns = addon("Platynator", "WOOD", nil, { noColors = true })
noDesigns.entry.Switch = function() return nil, "NO_DESIGNS" end
login({ ForeverUnitFrames = addon("ForeverUnitFrames", "TECH", "AMBER"), Platynator = noDesigns })
check("seeded without it", Themes.Current(), "TECH")
check("no retry", #M.timers, 0)
check("left out of the vote: not remembered", ForeverThemesDB.known.Platynator, nil)

section("Platynator: one /reload line")
unitFrames({ themePlatynatorFont = true })
ForeverUnitFramesDB.platynator = { font = PITWALL_FONT } -- it stands down at its login and says so
InfoPanelDB = nil
local before = reloadLines()
login({ ForeverUnitFrames = addon("ForeverUnitFrames", "PITWALL", "ORANGE") })
check("themed", design(), PITWALL_FONT)
check("Unit Frames said it: we stay quiet", reloadLines(), before)
Themes.Switch("WOOD")
check("a later change says it", reloadLines(), before + 1)
ForeverUnitFramesDB = nil

section("No Forever addon: the author's choices")
login({})
check("Pitwall", Themes.Current(), "PITWALL")
check("in red", Themes.Color(), "RED")
check("Comic in black once picked", Themes.Color("COMIC"), "BLACK")
check("every window skin", skinsOn(), 7)
check("Blizzard texts and Platynator", tostring(ForeverThemesDB.blizzardTexts) .. " "
    .. tostring(ForeverThemesDB.platynatorFont), "true true")
check("cast bar in Pitwall's font", (bar.Text:GetFont()), ns.Media.FontPath(PITWALL_FONT))

section("Every Forever addon on Classic")
local c1, c2 = addon("ClassicOne", "CLASSIC"), addon("ClassicTwo", "CLASSIC")
login({ ClassicOne = c1, ClassicTwo = c2 })
check("stays Classic", Themes.Current(), "CLASSIC")
check("they follow", Hub.Follows("ClassicOne"), true)
check("nothing switched", c1.theme .. " " .. c2.theme, "CLASSIC CLASSIC")
check("nothing active", tostring(ForeverThemesDB.blizzardTexts) .. " " .. tostring(ForeverThemesDB.platynatorFont)
    .. " " .. skinsOn(), "nil nil 0")
check("cast bar untouched", (bar.Text:GetFont()), FRIZ)
check("Platynator untouched", design(), "Roboto Condensed Bold")
c1.theme, c2.theme = "CLASSIC", "WOOD"
login({ ClassicOne = c1, ClassicTwo = c2 })
check("Classic and Wood: Wood", Themes.Current(), "WOOD")
check("the Classic one keeps its own", Hub.Follows("ClassicOne"), false)
check("and stays Classic", c1.theme, "CLASSIC")

section("Take-over: only once")
ForeverThemesDB.blizzardTexts = true
ns.Migrate.Run()
check("a later login changes no switch", ForeverThemesDB.blizzardTexts, true)
ForeverUnitFramesDB = { active = {}, profiles = { Default = { general = {} },
    Healer = { general = { themeBlizzardFonts = true } } } }
login({ ForeverUnitFrames = addon("ForeverUnitFrames", "PITWALL", "ORANGE") })
check("another character on Default: no Blizzard texts", ForeverThemesDB.blizzardTexts, nil)
ForeverUnitFramesDB, InfoPanelDB, PLATYNATOR_CONFIG = nil, nil, nil
ForeverThemesDB, _G.ForeverThemes = keptDB, keptRegistry
Fonts.SetEnabled(false)
Themes.Switch("PITWALL")
fire("PLAYER_LOGIN")
runTimers()
runTimers()

section("Options, slash, minimap button")
local spec = ns.OptionsSpec()
local tabs, addonRows = 0, 0
for _, row in ipairs(spec) do
    if row.type == "tab" then tabs = tabs + 1 end
    if type(row.label) == "function" then addonRows = addonRows + 1 end
end
check("four pages", tabs, 4)
check("a row per registered addon", addonRows, 6)
check("/forever", SLASH_FOREVERTHEMES1, "/forever")
check("slash handler", type(SlashCmdList.FOREVERTHEMES), "function")
check("minimap button made", M.byName.ForeverThemesMinimapButton ~= nil, true)
for _, row in ipairs(spec) do
    if type(row.label) == "function" and row.label() == "Forever Quest Log" then
        check("Quest Log row: own", row.get(), "OWN")
        check("Quest Log row: shows its theme", row.hint(), ns.L.ADDON_NOW:format(ns.ThemeLabel(Hub.Current(
            { folder = "ForeverQuestLog", title = "Forever Quest Log", entry = ql.entry }))))
        row.set("FOLLOW")
        check("Quest Log row: follow switches it", ql.theme, "PITWALL")
    end
end

-- The list is made when the window is: an addon registered after our
-- login (InfoPanel's Bartender) is in it.
_G.ForeverThemes.Bartender = addon("Bartender", "PITWALL", nil, { noColors = true, title = "Bartender" }).entry
ns.Window.Open(2)
local listed = false
for _, text in pairs(M.labelText) do if text == "Bartender" then listed = true end end
check("Addons page: a late addon listed", listed, true)
ns.Window.Toggle()
_G.ForeverThemes.Bartender = nil

section("Theme menu for other addons (Data Bar's Theme element)")
-- Blizzard_Menu recorded: the owner and what the menu holds.
local function recorder(log)
    local node = {}
    function node:CreateTitle(text) log[#log + 1] = "title:" .. text; return node end
    function node:CreateRadio(text, isSet, set)
        log[#log + 1] = (isSet() and "*" or "") .. text
        node.sets = node.sets or {}
        node.sets[text] = set
        return node
    end
    function node:CreateButton(text, fn) log[#log + 1] = "button:" .. text; node.click = fn or node.click; return node end
    function node:CreateDivider() end
    return node
end
local owner, log, root = nil, {}, nil
MenuUtil = { CreateContextMenu = function(o, gen) owner = o; root = recorder(log); gen(o, root) end }
local element = CreateFrame("Button", "SomeDataBarElement")
Themes.Switch("PITWALL")
Lib.Hub().OpenMenu(element)
check("owned by the frame given", owner, element)
check("titled", log[1], "title:" .. ns.L.ADDON_NAME)
local marked = 0
for _, line in ipairs(log) do if line:sub(1, 1) == "*" then marked = marked + 1 end end
check("the central theme and its colour marked", marked, 2)
check("a theme per id, then the colours", #log >= 1 + #Themes.IDS + #Themes.Colors("PITWALL"), true)
root.sets[ns.ThemeName("FROST")]()
check("a theme picked switches the central one", Themes.Current(), "FROST")
Lib.Hub().OpenMenu(nil)
check("no anchor: owned by UIParent", owner, UIParent)
MenuUtil = nil
Themes.Switch("PITWALL")

section("Media files exist")
local function exists(path)
    local file = ADDONDIR .. "/" .. path:gsub("^Interface\\AddOns\\ForeverThemes\\", ""):gsub("\\", "/")
    local h = io.open(file)
    if h then h:close() end
    return h ~= nil
end
local absent = {}
for _, id in ipairs(Lib.IDS) do
    local art = Themes.Spec(id).art
    if art then
        for _, color in ipairs(Lib.Colors(id)) do
            local p = Lib.Texture(Lib.Back(art, id, color) .. ".tga")
            if not exists(p) then absent[#absent + 1] = p end
        end
        if art.ornament and not exists(Lib.Texture(art.ornament .. ".tga")) then absent[#absent + 1] = art.ornament end
        if art.wedge and not exists(Lib.Texture(art.wedge .. ".tga")) then absent[#absent + 1] = art.wedge end
    end
end
for r = 1, ns.Corners.MAX_RADIUS do
    if not exists(ns.Corners.MaskFile(r)) then absent[#absent + 1] = ns.Corners.MaskFile(r) end
end
for _, p in ipairs({ ns.Border.SHADOW, ns.Corners.TEXTURE, ns.Corners.INVERSE[1], ns.MinimapButton.ICON }) do
    if not exists(p) then absent[#absent + 1] = p end
end
check("every backdrop, ornament, mask and icon", table.concat(absent, ", "), "")

section("Locales")
for _, code in ipairs({ "deDE", "esES", "frFR" }) do
    local missing = {}
    for key in pairs(ns.Locales.enUS) do
        if key ~= "ADDON_NAME" and ns.Locales[code][key] == nil then missing[#missing + 1] = key end
    end
    table.sort(missing)
    check(code .. ": every key", table.concat(missing, ","), "")
end
-- Every theme the menu offers (the HD ones too) and each colour named in English.
local unnamed = {}
for _, id in ipairs(Lib.SpecIds(Themes.SPECS)) do
    if ns.Locales.enUS["THEME_" .. id] == nil then unnamed[#unnamed + 1] = id end
    for _, c in ipairs(Lib.Colors(id)) do
        if ns.Locales.enUS["THEME_COLOR_" .. id .. "_" .. c] == nil then unnamed[#unnamed + 1] = id .. "_" .. c end
    end
end
check("every theme and colour named", table.concat(unnamed, ","), "")
check("the HD themes offered", Themes.SPECS.FROST_HD ~= nil and Themes.SPECS.COMIC_HD ~= nil, true)
local damage = 0
for _, code in ipairs({ "enUS", "deDE", "esES", "frFR" }) do
    if ns.Locales[code].TIP_BLIZZARD_TEXTS:find("/reload", 1, true) then damage = damage + 1 end
end
check("the damage-number tooltip names /reload everywhere", damage, 4)

section("Traps")
local found = {}
for _, f in ipairs(files) do
    if not f:match("^Libs/") then
        local h = assert(io.open(ADDONDIR .. "/" .. f))
        local raw = h:read("*a")
        h:close()
        local src = raw:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
        if src:find("hooksecurefunc") then found[#found + 1] = f end
        if raw:find("\195\159") then found[#found + 1] = f .. " (sharp s)" end
    end
end
check("no hooksecurefunc, no sharp s", table.concat(found, ","), "")

print(("%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
