-- Blizzard's character frame in the theme (Skins/Skin.lua, Skins/Character.lua).
-- Own file so wowmock.lua stays untouched: the frame is rebuilt here
-- as far as the addon touches it (Camelot/CharacterFrame.xml).
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

local frame = blizzard("CharacterFrame")
frame._w, frame._h = 631, 424
frame.NineSlice = blizzard()
frame.PortraitContainer = blizzard()
local generalBg, statBg, stoneBg, divider = tex("UI-Character-Info-General-BG"), tex("UI-Character-Info-Stat-BG"),
    tex("UI-Character-Info-Stat-StoneBG3", 0.5), tex("common-framedivider")
frame.LeftPaneHost = blizzard("CharacterFrameLeftPaneHost")
regions(frame.LeftPaneHost, { generalBg })
frame.RightPaneHost = blizzard("CharacterFrameRightPaneHost")
frame.RightPaneHost.StoneBg = stoneBg
regions(frame.RightPaneHost, { statBg, stoneBg })
local dividerFrame = blizzard()
regions(dividerFrame, { divider })
function frame.RightPaneHost:GetChildren() return dividerFrame end
frame.TitleContainer = blizzard()
frame.TitleContainer.TitleText = frame.TitleContainer:CreateFontString()
local closeTextures = { tex(), tex(), tex(), tex() }
frame.CloseButton = blizzard("CharacterFrameCloseButton")
function frame.CloseButton:GetNormalTexture() return closeTextures[1] end
function frame.CloseButton:GetPushedTexture() return closeTextures[2] end
function frame.CloseButton:GetHighlightTexture() return closeTextures[3] end
function frame.CloseButton:GetDisabledTexture() return closeTextures[4] end
local tab = blizzard()
tab.Background, tab.SelectedTexture, tab.TabGlow, tab.HighlightTexture = tex(), tex(), tex(), tex()
frame.ModeTabs = { Tabs = { tab } }

local stats = blizzard("CharacterStatsPaneScrollBox")
stats.ClassBackground, stats.Border = tex(), tex()
local scrollRows = {}
stats.ScrollBox = blizzard()
local rowCallback
ScrollUtil = { AddInitializedFrameCallback = function(box, fn, owner, iterate)
    rowCallback = fn
    if iterate then for _, row in ipairs(scrollRows) do fn(owner, row) end end
end }
local doll = blizzard("PaperDollFrame")
doll.TopBackgroundStripHost = { TopBackgroundStrip = tex(), TopBackgroundStripBottomEdge = tex() }
doll.TitleManagerPane = { Border = tex() }
blizzard("ReputationFrame")
CharacterLevelText = blizzard():CreateFontString()

local ns = dofile("load.lua")()
-- A stored ForeverThemesDB without the switch (a new one has every skin on).
ForeverThemesDB = {}

local pass, fail = 0, 0
local function check(label, got, want)
    if got == want then pass = pass + 1; print(("  OK   %-52s -> %s"):format(label, tostring(got)))
    else fail = fail + 1; print(("  FAIL %-52s -> %s   (want: %s)"):format(label, tostring(got), tostring(want))) end
end
local function list(t) return t and table.concat(t, ",") or "nil" end

for _, f in ipairs(M.frames) do
    if f._events and f._events["PLAYER_LOGIN"] and f:GetScript("OnEvent") then
        f:GetScript("OnEvent")(f, "PLAYER_LOGIN")
    end
end
local panel = dofile("reference.lua")(ns)
local Themes, Skin, Media = ns.Themes, ns.CharacterSkin, ns.Media
local art, line = Skin.Parts()
local title = frame.TitleContainer.TitleText
local FRIZ = "Fonts\\FRIZQT__.TTF"
local function alpha(region) return region:GetAlpha() end

print("\nSwitch off:")
check("created at login", art ~= nil, true)
check("off in a stored DB without it", Skin.Enabled(), false)
Themes.Switch("WOOD")
check("Wood without switch: NineSlice stays", alpha(frame.NineSlice), 1)
check("Wood without switch: no tile", art.back:IsShown(), false)
check("Wood without switch: title in Friz", (title:GetFont()), FRIZ)

print("\nSwitch on:")
-- A header and a stats row, already filled before switching on.
local header = { Background = tex(), Title = blizzard():CreateFontString() }
local statRow = { Label = blizzard():CreateFontString(), Value = blizzard():CreateFontString() }
rowCallback(nil, header)
rowCallback(nil, statRow)
layoutCalls = 0
Skin.SetEnabled(true)
check("saved account-wide", ForeverThemesDB.skinCharacter, true)
check("tile visible", art.back:IsShown(), true)
check("NineSlice off", alpha(frame.NineSlice), 0)
check("portrait off", alpha(frame.PortraitContainer), 0)
check("left background off", alpha(generalBg), 0)
check("right background off", alpha(statBg), 0)
check("stone header off", alpha(stoneBg), 0)
check("Blizzard's divider off", alpha(divider), 0)
check("own divider on", line:IsShown(), true)
check("class art off", alpha(stats.ClassBackground), 0)
check("strip above the model off", alpha(doll.TopBackgroundStripHost.TopBackgroundStrip), 0)
check("close: Blizzard's art off", alpha(closeTextures[1]), 0)
check("title: Cinzel", (title:GetFont()), Media.FontPath("Cinzel"))
check("level: bodyFont Friz -> display font", (CharacterLevelText:GetFont()), Media.FontPath("Cinzel"))
check("stats header: band off", alpha(header.Background), 0)
check("stats header: Cinzel", (header.Title:GetFont()), Media.FontPath("Cinzel"))
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
check("Pitwall: level in the body font", (CharacterLevelText:GetFont()), Media.FontPath("Titillium Web SemiBold"))
check("Pitwall: label in the body font", (statRow.Label:GetFont()), Media.FontPath("Titillium Web SemiBold"))
check("Pitwall: number untouched (may be secret)", (statRow.Value:GetFont()), FRIZ)
Themes.Switch("FROST")
check("Frost: title Julius", (title:GetFont()), Media.FontPath("Julius Sans One"))
check("Frost: no wedge", art.wedge:IsShown(), false)
check("Frost: dark shade", art.shade:IsShown(), true)
-- Blizzard shows a tab and resets the title colour: reapplied one tick later.
title:SetTextColor(1, 1, 1, 1)
M.timers = {}
_G.ReputationFrame._scriptHooks.OnShow()
for _, fn in ipairs(M.timers) do fn() end
local accent = Themes.Accent(Themes.SPECS.FROST.look.headerColor)
check("tab shown: title back in the accent", list(title._textColor), list({ accent[1], accent[2], accent[3], 1 }))
local newRow = { Background = tex(), Title = blizzard():CreateFontString() }
rowCallback(nil, newRow)
check("new stats row: Julius", (newRow.Title:GetFont()), Media.FontPath("Julius Sans One"))

print("\nFramed themes (Azeroth, Goblin):")
local function file(t) return t._texture and t._texture:match("[^\\]+$") end
Themes.Switch("AZEROTH")
local framed = 0
for _, s in ipairs(art.strips) do
    if s:IsShown() and file(s) == "WoodHDWalnut" then framed = framed + 1 end
end
check("azeroth: walnut frame on four sides", framed, 4)
local topLeft = M.anchorXY[art.strips[1]].TOPLEFT
check("azeroth: frame outside the window, 7 wide", topLeft[1] == -topLeft[2] and topLeft[2] >= 7, true)
check("azeroth: banner as the title band", art.band:IsShown() and file(art.band), "AzerothBanner")
check("azeroth: banner ends, the right one mirrored", art.ends[1]:IsShown() and art.ends[2]._texCoord[1], 1)
check("azeroth: band starts past the left end", M.anchorXY[art.band].TOPLEFT[1], art.ends[1]:GetWidth())
check("azeroth: title in gold on the banner, not ink", list(title._textColor), "1,0.82,0,1")
check("azeroth: title Cinzel", (title:GetFont()), Media.FontPath("Cinzel"))
check("azeroth: parchment shaded under Blizzard's light texts", art.shade:IsShown(), true)
check("azeroth: gold corners on the frame", art.ornaments[1]:IsShown() and file(art.ornaments[1]), "Bracket.tga")
Themes.Switch("GOBLIN")
check("goblin: copper frame", art.strips[1]:IsShown() and file(art.strips[1]), "GoblinCopper")
check("goblin: hazard strip 5 high, repeating", file(art.band) .. " " .. art.band:GetHeight() .. " "
    .. tostring(art.band:GetHorizTile()), "GoblinHazard 5 true")
check("goblin: no banner ends", art.ends[1]:IsShown(), false)
check("goblin: title Bungee, a point smaller (runs wide)", table.concat({ title:GetFont() }, " ", 1, 2),
    Media.FontPath("Bungee") .. " 9")
check("goblin: level line in Rubik at Blizzard's size", table.concat({ CharacterLevelText:GetFont() }, " ", 1, 2),
    Media.FontPath("Rubik Medium") .. " 10")
Themes.Switch("PITWALL")
check("pitwall after them: no frame, no ends", art.strips[1]:IsShown() or art.ends[1]:IsShown(), false)
check("pitwall after them: the band a colour again", art.band:GetHorizTile() == false and art.band._texture == nil, true)
Themes.Switch("FROST")

print("\nClassic restores everything:")
Themes.Switch("CLASSIC")
check("NineSlice back", alpha(frame.NineSlice), 1)
check("stone header at its own alpha", alpha(stoneBg), 0.5)
check("divider back", alpha(divider), 1)
check("own divider off", line:IsShown(), false)
check("tile off", art.back:IsShown(), false)
check("wedge off", art.wedge:IsShown(), false)
check("title in Friz", (title:GetFont()), FRIZ)
check("label in Friz", (statRow.Label:GetFont()), FRIZ)
check("tab no longer desaturated", tab.SelectedTexture:IsDesaturated(), false)
check("tab untinted", list(tab.SelectedTexture._vertex), "1,1,1,1")
check("close: Blizzard's art back", alpha(closeTextures[1]), 1)
check("ring gone", ns.Border.Pieces(art.over)[1]:IsShown(), false)
check("frame gone", art.strips[1]:IsShown(), false)

print("\nSwitch off under a theme:")
Themes.Switch("TECH")
check("Tech: title Space Grotesk", (title:GetFont()), Media.FontPath("Space Grotesk"))
Skin.SetEnabled(false)
check("off: saved without entry", ForeverThemesDB.skinCharacter, nil)
check("off: NineSlice back", alpha(frame.NineSlice), 1)
check("off: title in Friz", (title:GetFont()), FRIZ)
check("off: tile off", art.back:IsShown(), false)
frame._scriptHooks.OnShow()
check("off: showing changes nothing", alpha(frame.NineSlice), 1)

print("\nTraps:")
local found = {}
for _, f in ipairs({ "Skins/Skin.lua", "Skins/Character.lua" }) do
    local h = assert(io.open(ADDONDIR .. "/" .. f)); local src = h:read("*a"); h:close()
    -- Comments do not count: they explain why it is missing.
    src = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
    if src:find("hooksecurefunc") then found[#found + 1] = f end
end
check("no hooksecurefunc", table.concat(found, ","), "")
check("switch in all languages", ns.Locales.deDE.OPT_SKIN_CHARACTER ~= nil and ns.Locales.esES.OPT_SKIN_CHARACTER ~= nil
    and ns.Locales.frFR.OPT_SKIN_CHARACTER ~= nil and ns.Locales.enUS.OPT_SKIN_CHARACTER ~= nil, true)

print(("\n%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
