-- Blizzard's talent frame in the theme (Skins/Skin.lua, Skins/Talents.lua).
-- Own file so wowmock.lua stays untouched: the frame is rebuilt here
-- as far as the addon touches it
-- (Camelot/ClassTalents/Blizzard_ClassTalentsFrame.xml).
local M = dofile("wowmock.lua")

-- Blizzard's frames: counts every change to layout and visibility.
local layoutCalls = 0
local function blizzard(name)
    local w = M.newWidget(name)
    for _, method in ipairs({ "SetPoint", "ClearAllPoints", "SetSize", "SetWidth", "SetHeight", "Show", "Hide",
                              "SetShown", "SetParent", "SetScale", "SetAllPoints" }) do
        local orig = w[method]
        w[method] = function(self, ...)
            layoutCalls = layoutCalls + 1
            if orig then return orig(self, ...) end
        end
    end
    w._scriptHooks = {}
    function w:HookScript(script, fn) self._scriptHooks[script] = fn end
    if name then _G[name] = w end
    return w
end

local function tex(alpha)
    local t = blizzard()
    t._alpha = alpha
    function t:GetVertexColor() local v = self._vertex or { 1, 1, 1, 1 }; return v[1], v[2], v[3], v[4] end
    function t:SetDesaturated(v) self._desaturated = v end
    function t:IsDesaturated() return self._desaturated == true end
    return t
end

-- The outer frame only exists once Blizzard_PlayerSpells loads.
local frame, tab, header
local function loadBlizzard()
    local outer = blizzard("PlayerSpellsFrame")
    -- The spellbook skin shares this frame (skin_spellbook.lua): its parts
    -- are not built here.
    outer.CloseButton, outer.SpellBookFrame = false, false
    frame = blizzard()
    outer.TalentsFrame = frame
    for _, key in ipairs({ "Background", "ClassBackground", "BackgroundBorder", "DividerHorizontalLeft",
                           "DividerHorizontalRight", "DividerVerticalLeft", "DividerVerticalRight" }) do
        frame[key] = tex()
    end
    frame.OverlayBackgroundRight, frame.OverlayBackgroundMid = tex(0), tex(0)
    tab = blizzard()
    for _, key in ipairs({ "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive",
                           "LeftHighlight", "MiddleHighlight", "RightHighlight" }) do
        tab[key] = tex()
    end
    frame.TabSystem = blizzard()
    frame.TabSystem.tabs = { tab }
    frame.ActiveSpec = { ActiveLabel = blizzard():CreateFontString() }
    frame.ClassCurrencyDisplay = { UnspentLabel = blizzard():CreateFontString(),
        CurrencyAmount = blizzard():CreateFontString() }
    header = { Name = blizzard():CreateFontString(), Text = blizzard():CreateFontString(),
        MainRing = tex(), TextBackground = tex(), Divider = tex() }
    frame.treeHeaders = { header }
end

local ns = dofile("load.lua")()

local pass, fail = 0, 0
local function check(label, got, want)
    if got == want then pass = pass + 1; print(("  OK   %-52s -> %s"):format(label, tostring(got)))
    else fail = fail + 1; print(("  FAIL %-52s -> %s   (want: %s)"):format(label, tostring(got), tostring(want))) end
end
local function list(t) return t and table.concat(t, ",") or "nil" end
local function fire(event, ...)
    for _, f in ipairs(M.frames) do
        if f._events and f._events[event] and f:GetScript("OnEvent") then f:GetScript("OnEvent")(f, event, ...) end
    end
end

local Themes, Skin, Media = ns.Themes, ns.TalentsSkin, ns.Media
local FRIZ = "Fonts\\FRIZQT__.TTF"
local function alpha(region) return region:GetAlpha() end

print("\nLoad on demand:")
fire("PLAYER_LOGIN")
check("login without talent frame: nothing created", Skin.Parts(), nil)
loadBlizzard()
fire("ADDON_LOADED", "Blizzard_SomethingElse")
check("other addon loaded: nothing created", Skin.Parts(), nil)
layoutCalls = 0
fire("ADDON_LOADED", "Blizzard_PlayerSpells")
local back, shade = Skin.Parts()
check("Blizzard_PlayerSpells loaded: created", back ~= nil, true)
check("OnShow hooked", frame._scriptHooks.OnShow ~= nil, true)
local panel = dofile("reference.lua")(ns)

print("\nSwitch off (default):")
check("off by default", Skin.Enabled(), false)
Themes.Switch("WOOD")
check("Wood without switch: background stays", alpha(frame.Background), 1)
check("Wood without switch: no tile", back:IsShown(), false)
check("Wood without switch: tree name in Friz", (header.Name:GetFont()), FRIZ)

print("\nSwitch on:")
Skin.SetEnabled(true)
check("saved account-wide", ForeverThemesDB.skinTalents, true)
check("tile visible", back:IsShown(), true)
check("background off", alpha(frame.Background), 0)
check("class art off", alpha(frame.ClassBackground), 0)
check("inner frame off", alpha(frame.BackgroundBorder), 0)
check("pulsing class art black", list(frame.OverlayBackgroundMid._vertex), "0,0,0,1")
local l = Themes.Spec("WOOD").art.line
check("divider in the line colour", list(frame.DividerVerticalLeft._vertex), list(l))
check("divider desaturated", frame.DividerVerticalLeft:IsDesaturated(), true)
check("tree name: Cinzel", (header.Name:GetFont()), Media.FontPath("Cinzel"))
local hc = Themes.Accent(Themes.SPECS.WOOD.look.headerColor or ns.Settings.DEFAULTS.headerColor)
check("tree name in the accent", list(header.Name._textColor), list({ hc[1], hc[2], hc[3], 1 }))
local icon = Themes.IconColor()
check("ring around the icon in the icon colour", list(header.MainRing._vertex), list({ icon[1], icon[2], icon[3], 1 }))
check("active: bodyFont Friz -> display font", (frame.ActiveSpec.ActiveLabel:GetFont()), Media.FontPath("Cinzel"))
check("unspent: bodyFont Friz stays", (frame.ClassCurrencyDisplay.UnspentLabel:GetFont()), FRIZ)
check("point count untouched", (frame.ClassCurrencyDisplay.CurrencyAmount:GetFont()), FRIZ)
check("tab: selection in the icon colour", list(tab.MiddleActive._vertex), list({ icon[1], icon[2], icon[3], 1 }))
check("tab: grey", list(tab.Middle._vertex), "0.3,0.3,0.3,1")
check("no layout on Blizzard's frames", layoutCalls, 0)

print("\nLike the panel, per theme and colour:")
local mismatch = {}
for _, id in ipairs(Themes.IDS) do
    if id ~= Themes.CLASSIC then
        Themes.Switch(id)
        for _, color in ipairs(Themes.Colors(id)) do
            Themes.SetColor(color, id)
            panel.Paint()
            local where = id .. "/" .. color
            if back._texture ~= panel.bg._texture then mismatch[#mismatch + 1] = where .. " texture" end
            if list(back._vertex) ~= list(panel.bg._vertex) then mismatch[#mismatch + 1] = where .. " tint" end
            local wanted = Themes.Spec(id).art.contentShade
            if shade:IsShown() ~= (wanted ~= nil) then mismatch[#mismatch + 1] = where .. " shade" end
        end
    end
end
check("tile, tint and shade match", table.concat(mismatch, "; "), "")

print("\nTheme switch:")
Themes.SetColor("ORANGE", "PITWALL")
Themes.Switch("PITWALL")
check("Pitwall: tree name Titillium", (header.Name:GetFont()), Media.FontPath("Titillium Web Bold Italic"))
check("Pitwall: point count in the body font", (header.Text:GetFont()), Media.FontPath("Titillium Web SemiBold"))
check("Pitwall: active in the body font", (frame.ActiveSpec.ActiveLabel:GetFont()),
    Media.FontPath("Titillium Web SemiBold"))
Themes.Switch("FROST")
check("Frost: tree name Julius", (header.Name:GetFont()), Media.FontPath("Julius Sans One"))
check("Frost: dark shade", shade:IsShown(), true)
-- Tab shown: Blizzard recreates the headers, reapplied one tick later.
local newHeader = { Name = blizzard():CreateFontString(), Text = blizzard():CreateFontString(),
    MainRing = tex(), TextBackground = tex(), Divider = tex() }
frame.treeHeaders[2] = newHeader
M.timers = {}
frame._scriptHooks.OnShow()
for _, fn in ipairs(M.timers) do fn() end
check("new tree header after showing: Julius", (newHeader.Name:GetFont()), Media.FontPath("Julius Sans One"))

print("\nClassic restores everything:")
Themes.Switch("CLASSIC")
check("background back", alpha(frame.Background), 1)
check("class art back", alpha(frame.ClassBackground), 1)
check("pulsing class art untinted", list(frame.OverlayBackgroundMid._vertex), "1,1,1,1")
check("pulsing class art keeps its alpha", alpha(frame.OverlayBackgroundMid), 0)
check("divider untinted", list(frame.DividerVerticalLeft._vertex), "1,1,1,1")
check("divider not desaturated", frame.DividerVerticalLeft:IsDesaturated(), false)
check("tile off", back:IsShown(), false)
check("shade off", shade:IsShown(), false)
check("tree name in Friz", (header.Name:GetFont()), FRIZ)
check("active in Friz", (frame.ActiveSpec.ActiveLabel:GetFont()), FRIZ)
check("tab untinted", list(tab.MiddleActive._vertex), "1,1,1,1")

print("\nSwitch off under a theme:")
Themes.Switch("TECH")
check("Tech: tree name Space Grotesk", (header.Name:GetFont()), Media.FontPath("Space Grotesk"))
Skin.SetEnabled(false)
check("off: saved without entry", ForeverThemesDB.skinTalents, nil)
check("off: background back", alpha(frame.Background), 1)
check("off: tree name in Friz", (header.Name:GetFont()), FRIZ)
check("off: tile off", back:IsShown(), false)
M.timers = {}
frame._scriptHooks.OnShow()
for _, fn in ipairs(M.timers) do fn() end
check("off: showing changes nothing", alpha(frame.Background), 1)
check("never layout on Blizzard's frames", layoutCalls, 0)

print("\nTraps:")
local h = assert(io.open(ADDONDIR .. "/Skins/Talents.lua")); local src = h:read("*a"); h:close()
src = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
check("no hooksecurefunc", src:find("hooksecurefunc") == nil, true)
check("no CreateFrame (children of a Blizzard frame)", src:find("CreateFrame") == nil, true)
check("switch in all languages", ns.Locales.deDE.OPT_SKIN_TALENTS ~= nil and ns.Locales.esES.OPT_SKIN_TALENTS ~= nil
    and ns.Locales.frFR.OPT_SKIN_TALENTS ~= nil and ns.Locales.enUS.OPT_SKIN_TALENTS ~= nil, true)

print(("\n%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
