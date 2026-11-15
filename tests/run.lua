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
fuf.refuse = nil
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

section("Seeding with no addon yet")
do
    local saved = _G.ForeverThemes
    _G.ForeverThemes = {}
    ForeverThemesDB = {}
    Hub.Sync()
    check("nothing to seed from: stays unset", Themes.IsSet(), false)
    check("Classic meanwhile", Themes.Current(), "CLASSIC")
    _G.ForeverThemes = saved
end
ForeverThemesDB = { theme = "WOOD", follow = { ForeverQuestLog = false } }

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
local Fonts = ns.BlizzardFonts
check("off by default", Fonts.Enabled(), false)
Themes.Switch("PITWALL")
check("off: cast bar keeps Friz", (bar.Text:GetFont()), "Fonts\\FRIZQT__.TTF")
Fonts.SetEnabled(true)
local body = ns.Media.FontPath("Titillium Web SemiBold")
check("on: cast bar in the theme's text font", (bar.Text:GetFont()), body)
check("on: error line too", errorsFrame._font[1], body)
check("damage numbers kept for the next login", ForeverThemesDB.damageFont, "Titillium Web SemiBold")
Themes.Switch("WOOD")
check("Wood: Friz body gives the title font", (bar.Text:GetFont()), ns.Media.FontPath("Cinzel"))
Themes.Switch("CLASSIC")
check("Classic: cast bar back to Friz", (bar.Text:GetFont()), "Fonts\\FRIZQT__.TTF")
check("Classic: no damage font", ForeverThemesDB.damageFont, nil)
Themes.Switch("FROST")
Fonts.SetEnabled(false)
check("off: back to Friz", (bar.Text:GetFont()), "Fonts\\FRIZQT__.TTF")
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
