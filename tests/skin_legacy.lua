-- Blizzard's legacy frame in the theme (Skins/Skin.lua, Skins/Legacy.lua).
-- Own file so wowmock.lua stays untouched: the frame is rebuilt here
-- as far as the addon touches it (Blizzard_LegacySystem.xml).
local M = dofile("wowmock.lua")

-- Blizzard's frames: counts every change to layout and visibility
-- (forbidden: only textures, fonts, alpha).
local layoutCalls = 0
local function blizzard(name)
    local w = M.newWidget(name)
    for _, method in ipairs({ "SetPoint", "ClearAllPoints", "SetSize", "SetWidth", "SetHeight", "Show", "Hide",
                              "SetShown", "SetParent", "SetScale" }) do
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

local function tex(atlas, alpha)
    local t = blizzard()
    t._atlas, t._alpha = atlas, alpha
    function t:GetAtlas() return self._atlas end
    function t:GetVertexColor() local v = self._vertex or { 1, 1, 1, 1 }; return v[1], v[2], v[3], v[4] end
    function t:SetDesaturated(v) self._desaturated = v end
    function t:IsDesaturated() return self._desaturated == true end
    return t
end

local function regions(frame, list) function frame:GetRegions() return unpack(list) end end

-- The frame only exists once Blizzard_LegacySystem loads (after login).
local frame, closeTextures, tab, pages, dividers
local function loadBlizzardLegacy()
    frame = blizzard("LegacySystemFrame")
    frame._w, frame._h = 920, 575
    frame.NineSlice, frame.PortraitContainer = blizzard(), blizzard()
    frame.Bg, frame.TopTileStreaks = tex(), tex()
    frame.TitleContainer = blizzard()
    frame.TitleContainer.TitleText = frame.TitleContainer:CreateFontString()
    closeTextures = { tex(), tex(), tex(), tex() }
    frame.CloseButton = blizzard("LegacySystemFrameCloseButton")
    function frame.CloseButton:GetNormalTexture() return closeTextures[1] end
    function frame.CloseButton:GetPushedTexture() return closeTextures[2] end
    function frame.CloseButton:GetHighlightTexture() return closeTextures[3] end
    function frame.CloseButton:GetDisabledTexture() return closeTextures[4] end
    tab = blizzard()
    tab.Background, tab.SelectedTexture, tab.TabGlow, tab.HighlightTexture = tex(), tex(), tex(), tex()
    frame.Tabs = { tab }
    pages, dividers = {}, {}
    for _, key in ipairs({ "RewardTrackPage", "ChallengesPage", "TreePage" }) do
        local page = blizzard()
        page.Background = tex("Legacy-Page-BG")
        frame[key] = page
        pages[key] = page
    end
    for _, key in ipairs({ "ChallengesPage", "TreePage" }) do
        local d = tex("Legacy-Tree-Frame-divider-Vertical")
        pages[key].VerticalDivider = blizzard()
        regions(pages[key].VerticalDivider, { d })
        dividers[key] = d
    end
    -- The reward track has no divider (otherwise the mock returns a function).
    pages.RewardTrackPage.VerticalDivider = false
    local track = pages.RewardTrackPage
    track.PointsLabel, track.Points = track:CreateFontString(), track:CreateFontString()
    local panel = blizzard()
    panel.SelectedTreeIcon = blizzard()
    panel.SelectedTreeIcon.SelectedTreeLabel = panel.SelectedTreeIcon:CreateFontString()
    pages.TreePage.LegacyTreeTraitPanel = panel
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

local Themes, Skin, Media = ns.Themes, ns.LegacySkin, ns.Media
local FRIZ = "Fonts\\FRIZQT__.TTF"
local function alpha(region) return region:GetAlpha() end

print("\nLoad on demand:")
fire("PLAYER_LOGIN")
check("login without frame: nothing created", Skin.Parts(), nil)
loadBlizzardLegacy()
fire("ADDON_LOADED", "Blizzard_Calendar")
check("other addon loaded: nothing created", Skin.Parts(), nil)
fire("ADDON_LOADED", "Blizzard_LegacySystem")
local art = Skin.Parts()
check("Blizzard_LegacySystem loaded: created", art ~= nil, true)
fire("ADDON_LOADED", "Blizzard_LegacySystem")
check("second load: same art", Skin.Parts(), art)
local panel = dofile("reference.lua")(ns)
local title = frame.TitleContainer.TitleText
local treeLabel = pages.TreePage.LegacyTreeTraitPanel.SelectedTreeIcon.SelectedTreeLabel
local track = pages.RewardTrackPage

print("\nSwitch off (default):")
check("off by default", Skin.Enabled(), false)
Themes.Switch("WOOD")
check("Wood without switch: NineSlice stays", alpha(frame.NineSlice), 1)
check("Wood without switch: no tile", art.back:IsShown(), false)
check("Wood without switch: title in Friz", (title:GetFont()), FRIZ)

print("\nSwitch on:")
layoutCalls = 0
Skin.SetEnabled(true)
check("saved account-wide", ForeverThemesDB.skinLegacy, true)
check("tile visible", art.back:IsShown(), true)
check("NineSlice off", alpha(frame.NineSlice), 0)
check("portrait off", alpha(frame.PortraitContainer), 0)
check("rock tile off", alpha(frame.Bg), 0)
check("streaks off", alpha(frame.TopTileStreaks), 0)
for key, page in pairs(pages) do check(key .. ": background off", alpha(page.Background), 0) end
local line = Themes.Spec("WOOD").art.line
check("divider in the line colour", list(dividers.TreePage._vertex), list(line))
check("divider desaturated", dividers.ChallengesPage:IsDesaturated(), true)
check("close: Blizzard's art off", alpha(closeTextures[1]), 0)
check("title: Cinzel", (title:GetFont()), Media.FontPath("Cinzel"))
check("points heading: bodyFont Friz -> display font", (track.PointsLabel:GetFont()), Media.FontPath("Cinzel"))
check("tree name: display font", (treeLabel:GetFont()), Media.FontPath("Cinzel"))
check("point count untouched", (track.Points:GetFont()), FRIZ)
local icon = Themes.IconColor()
check("tab: selection in the icon colour", list(tab.SelectedTexture._vertex), list({ icon[1], icon[2], icon[3], 1 }))
check("tab: desaturated", tab.SelectedTexture:IsDesaturated(), true)
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
            if art.back._texture ~= panel.bg._texture then mismatch[#mismatch + 1] = where .. " texture" end
            if list(art.back._vertex) ~= list(panel.bg._vertex) then mismatch[#mismatch + 1] = where .. " tint" end
            local mine, theirs = ns.Border.Pieces(art.over)[1], ns.Border.Pieces(panel)[1]
            if list(mine._vertex) ~= list(theirs._vertex) then mismatch[#mismatch + 1] = where .. " border" end
        end
    end
end
check("tile, tint and border like the InfoPanel", table.concat(mismatch, "; "), "")

print("\nTheme switch:")
Themes.SetColor("ORANGE", "PITWALL")
Themes.Switch("PITWALL")
check("Pitwall: wedge", art.wedge:IsShown(), true)
check("Pitwall: wedge in the colour", list(art.wedge._vertex), list(Themes.Wedge({ 0.882, 0.024, 0, 1 })))
check("Pitwall: title Titillium", (title:GetFont()), Media.FontPath("Titillium Web Bold Italic"))
check("Pitwall: tree name in the body font", (treeLabel:GetFont()), Media.FontPath("Titillium Web SemiBold"))
Themes.Switch("FROST")
check("Frost: title Julius", (title:GetFont()), Media.FontPath("Julius Sans One"))
check("Frost: no wedge", art.wedge:IsShown(), false)
check("Frost: divider in Frost's line colour", list(dividers.TreePage._vertex), list(Themes.Spec("FROST").art.line))
-- A page shown: Blizzard resets the title, reapplied one tick later.
title:SetTextColor(1, 1, 1, 1)
M.timers = {}
pages.TreePage._scriptHooks.OnShow()
for _, fn in ipairs(M.timers) do fn() end
local accent = Themes.Accent(Themes.SPECS.FROST.look.headerColor)
check("page shown: title back in the accent", list(title._textColor), list({ accent[1], accent[2], accent[3], 1 }))

print("\nClassic restores everything:")
Themes.Switch("CLASSIC")
check("NineSlice back", alpha(frame.NineSlice), 1)
check("rock tile back", alpha(frame.Bg), 1)
check("page background back", alpha(pages.TreePage.Background), 1)
check("divider untinted", list(dividers.TreePage._vertex), "1,1,1,1")
check("divider not desaturated", dividers.TreePage:IsDesaturated(), false)
check("tile off", art.back:IsShown(), false)
check("wedge off", art.wedge:IsShown(), false)
check("title in Friz", (title:GetFont()), FRIZ)
check("tree name in Friz", (treeLabel:GetFont()), FRIZ)
check("tab untinted", list(tab.SelectedTexture._vertex), "1,1,1,1")
check("close: Blizzard's art back", alpha(closeTextures[1]), 1)
check("ring gone", ns.Border.Pieces(art.over)[1]:IsShown(), false)

print("\nSwitch off under a theme:")
Themes.Switch("TECH")
check("Tech: title Space Grotesk", (title:GetFont()), Media.FontPath("Space Grotesk"))
Skin.SetEnabled(false)
check("off: saved without entry", ForeverThemesDB.skinLegacy, nil)
check("off: NineSlice back", alpha(frame.NineSlice), 1)
check("off: title in Friz", (title:GetFont()), FRIZ)
check("off: tile off", art.back:IsShown(), false)
frame._scriptHooks.OnShow()
check("off: showing changes nothing", alpha(frame.NineSlice), 1)

print("\nTraps:")
local h = assert(io.open(ADDONDIR .. "/Skins/Legacy.lua")); local src = h:read("*a"); h:close()
-- Comments do not count: they explain why it is missing.
src = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
check("no hooksecurefunc", src:find("hooksecurefunc") == nil, true)
check("switch in all languages", ns.Locales.deDE.OPT_SKIN_LEGACY ~= nil and ns.Locales.esES.OPT_SKIN_LEGACY ~= nil
    and ns.Locales.frFR.OPT_SKIN_LEGACY ~= nil and ns.Locales.enUS.OPT_SKIN_LEGACY ~= nil, true)

print(("\n%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
