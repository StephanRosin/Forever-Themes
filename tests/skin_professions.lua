-- Blizzard's professions frame in the theme (Skins/Skin.lua, Skins/Professions.lua).
-- Own file so wowmock.lua stays untouched: the frame is rebuilt here
-- as far as the addon touches it (Camelot/Blizzard_ProfessionsFrame.xml).
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

local ns = dofile("load.lua")()
-- A stored ForeverThemesDB without the switch (a new one has every skin on).
ForeverThemesDB = {}

local function fire(event, ...)
    for _, f in ipairs(M.frames) do
        if f._events and f._events[event] and f:GetScript("OnEvent") then f:GetScript("OnEvent")(f, event, ...) end
    end
end

local pass, fail = 0, 0
local function check(label, got, want)
    if got == want then pass = pass + 1; print(("  OK   %-52s -> %s"):format(label, tostring(got)))
    else fail = fail + 1; print(("  FAIL %-52s -> %s   (want: %s)"):format(label, tostring(got), tostring(want))) end
end
local function list(t) return t and table.concat(t, ",") or "nil" end
local function alpha(region) return region:GetAlpha() end

local Themes, Skin, Media = ns.Themes, ns.ProfessionsSkin, ns.Media
local FRIZ = "Fonts\\FRIZQT__.TTF"

print("\nLoad on demand:")
fire("PLAYER_LOGIN")
local panel = dofile("reference.lua")(ns)
check("login without frame: nothing created", Skin.Parts(), nil)

-- Blizzard_Professions loads: only now does the frame exist.
local frame = blizzard("ProfessionsFrame")
frame._w, frame._h = 673, 594
frame.NineSlice = blizzard()
frame.PortraitContainer = blizzard()
frame.Bg = tex()
frame.TitleContainer = blizzard()
frame.TitleContainer.TitleText = frame.TitleContainer:CreateFontString()
local closeTextures = { tex(), tex(), tex(), tex() }
frame.CloseButton = blizzard("ProfessionsFrameCloseButton")
function frame.CloseButton:GetNormalTexture() return closeTextures[1] end
function frame.CloseButton:GetPushedTexture() return closeTextures[2] end
function frame.CloseButton:GetHighlightTexture() return closeTextures[3] end
function frame.CloseButton:GetDisabledTexture() return closeTextures[4] end
local function sideTab()
    local t = blizzard()
    t.Background, t.SelectedTexture, t.TabGlow, t.HighlightTexture = tex(), tex(), tex(), tex()
    return t
end
frame.ProfessionsOverviewTab = sideTab()
frame.rightProfessionTabs = { sideTab(), sideTab() }
local pageBg, otherTex = tex("Profession-Background-Template2"), tex("Professions-Recipe-Header")
frame.CraftingPage = blizzard()
function frame.CraftingPage:GetRegions() return pageBg, otherTex end
local recipeList = blizzard()
recipeList.Background, recipeList.BackgroundNineSlice = tex(), blizzard()
local form = blizzard()
form.Background, form.MinimalBackground, form.NineSlice = tex(), tex(), blizzard()
local pageRankBar = blizzard()
pageRankBar.Border, pageRankBar.Fill = tex(), tex()
frame.CraftingPage.RecipeList, frame.CraftingPage.SchematicForm = recipeList, form
frame.CraftingPage.RankBar = pageRankBar
local function newCard()
    local c = blizzard()
    c.Background = tex()
    c._textures = {}
    function c:CreateTexture() local t = M.newWidget(); table.insert(self._textures, t); return t end
    for _, key in ipairs({ "ProfessionName", "missingHeader", "specialization", "missingText" }) do
        c[key] = c:CreateFontString()
    end
    c.StatusBar = blizzard()
    c.StatusBar.Border, c.StatusBar.Fill = tex(), tex()
    c.StatusBar.Rank = { Text = c.StatusBar:CreateFontString() }
    return c
end
local card, cooking = newCard(), newCard()
frame.BookPage = blizzard()
frame.BookPage.ProfessionsContentFrame = { PrimaryProfession1 = card, SecondaryProfession1 = cooking }

-- Own textures on a card (everything except Blizzard's Background).
local function ownTextures(c)
    local list = {}
    for _, t in ipairs(c._textures or {}) do list[#list + 1] = t end
    return list
end

M.combat = true
fire("ADDON_LOADED", "Blizzard_Professions")
check("loaded in combat: waits", Skin.Parts(), nil)
M.combat = false
fire("PLAYER_REGEN_ENABLED")
local art = Skin.Parts()
check("created after combat", art ~= nil, true)
local title = frame.TitleContainer.TitleText

print("\nSwitch off:")
check("off in a stored DB without it", Skin.Enabled(), false)
Themes.Switch("WOOD")
check("Wood without switch: NineSlice stays", alpha(frame.NineSlice), 1)
check("Wood without switch: no tile", art.back:IsShown(), false)
check("Wood without switch: title in Friz", (title:GetFont()), FRIZ)

print("\nSwitch on:")
layoutCalls = 0
Skin.SetEnabled(true)
check("saved account-wide", ForeverThemesDB.skinProfessions, true)
check("tile visible", art.back:IsShown(), true)
check("NineSlice off", alpha(frame.NineSlice), 0)
check("portrait off", alpha(frame.PortraitContainer), 0)
check("Blizzard's background off", alpha(frame.Bg), 0)
check("recipe page background off", alpha(pageBg), 0)
check("other page textures stay", alpha(otherTex), 1)
check("close: Blizzard's art off", alpha(closeTextures[1]), 0)
check("title: Cinzel", (title:GetFont()), Media.FontPath("Cinzel"))
check("profession name: Cinzel", (card.ProfessionName:GetFont()), Media.FontPath("Cinzel"))
local accentNow = Themes.Accent(Themes.SPECS.WOOD.look.headerColor or ns.Settings.DEFAULTS.headerColor)
check("profession name in the accent", list(card.ProfessionName._textColor),
    list({ accentNow[1], accentNow[2], accentNow[3], 1 }))
check("missing profession: heading Cinzel", (cooking.missingHeader:GetFont()), Media.FontPath("Cinzel"))
check("description: Friz stays", (card.missingText:GetFont()), FRIZ)
check("rank number untouched", (card.StatusBar.Rank.Text:GetFont()), FRIZ)
check("card art off", alpha(card.Background), 0)
check("secondary profession card art off", alpha(cooking.Background), 0)
local surface = ownTextures(card)
check("own card surface and ring (5 textures)", #surface, 5)
local shown = 0
for _, t in ipairs(surface) do if t:IsShown() then shown = shown + 1 end end
check("card surface visible", shown, 5)
local woodLine = Themes.SPECS.WOOD.art.line
check("ring in the line colour", list(surface[2]._colorTexture), list(woodLine))
check("rank bar: border in the line colour", list(card.StatusBar.Border._vertex),
    list({ woodLine[1], woodLine[2], woodLine[3], 1 }))
check("rank bar: border desaturated", card.StatusBar.Border:IsDesaturated(), true)
check("rank bar: fill untouched", alpha(card.StatusBar.Fill), 1)
check("recipe page rank bar tinted", pageRankBar.Border:IsDesaturated(), true)
check("recipe list: background off", alpha(recipeList.Background), 0)
check("form: profession art off", alpha(form.Background), 0)
check("form: minimal background off", alpha(form.MinimalBackground), 0)
check("form: NineSlice off", alpha(form.NineSlice), 0)
local icon = Themes.IconColor()
for i, tab in ipairs({ frame.ProfessionsOverviewTab, frame.rightProfessionTabs[2] }) do
    check("tab " .. i .. ": selection in the icon colour", list(tab.SelectedTexture._vertex),
        list({ icon[1], icon[2], icon[3], 1 }))
    check("tab " .. i .. ": desaturated", tab.SelectedTexture:IsDesaturated(), true)
end
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
check("Pitwall: profession name Titillium", (card.ProfessionName:GetFont()),
    Media.FontPath("Titillium Web Bold Italic"))
check("Pitwall: specialization in the body font", (card.specialization:GetFont()),
    Media.FontPath("Titillium Web SemiBold"))
check("Pitwall: description in the body font", (card.missingText:GetFont()), Media.FontPath("Titillium Web SemiBold"))
Themes.Switch("FROST")
check("Frost: title Julius", (title:GetFont()), Media.FontPath("Julius Sans One"))
check("Frost: no wedge", art.wedge:IsShown(), false)
check("Frost: dark shade", art.shade:IsShown(), true)
-- Blizzard shows the frame again: everything reapplied.
frame.NineSlice:SetAlpha(1)
frame._scriptHooks.OnShow()
check("showing: NineSlice off again", alpha(frame.NineSlice), 0)

print("\nClassic restores everything:")
Themes.Switch("CLASSIC")
check("NineSlice back", alpha(frame.NineSlice), 1)
check("background back", alpha(frame.Bg), 1)
check("recipe page background back", alpha(pageBg), 1)
check("tile off", art.back:IsShown(), false)
check("wedge off", art.wedge:IsShown(), false)
check("title in Friz", (title:GetFont()), FRIZ)
check("profession name in Friz", (card.ProfessionName:GetFont()), FRIZ)
check("card art back", alpha(card.Background), 1)
check("profession art back", alpha(form.Background), 1)
check("card surface off", surface[1]:IsShown(), false)
check("rank bar: border untinted", list(card.StatusBar.Border._vertex), "1,1,1,1")
check("tab no longer desaturated", frame.ProfessionsOverviewTab.SelectedTexture:IsDesaturated(), false)
check("tab untinted", list(frame.ProfessionsOverviewTab.SelectedTexture._vertex), "1,1,1,1")
check("close: Blizzard's art back", alpha(closeTextures[1]), 1)
check("ring gone", ns.Border.Pieces(art.over)[1]:IsShown(), false)

print("\nSwitch off under a theme:")
Themes.Switch("TECH")
check("Tech: title Space Grotesk", (title:GetFont()), Media.FontPath("Space Grotesk"))
Skin.SetEnabled(false)
check("off: saved without entry", ForeverThemesDB.skinProfessions, nil)
check("off: NineSlice back", alpha(frame.NineSlice), 1)
check("off: title in Friz", (title:GetFont()), FRIZ)
check("off: tile off", art.back:IsShown(), false)
frame._scriptHooks.OnShow()
check("off: showing changes nothing", alpha(frame.NineSlice), 1)

print("\nTraps:")
local h = assert(io.open(ADDONDIR .. "/Skins/Professions.lua")); local src = h:read("*a"); h:close()
-- Comments do not count: they explain why it is missing.
src = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
check("no hooksecurefunc", src:find("hooksecurefunc") == nil, true)
check("tabs: no scripts touched", src:find("SetScript") == nil and src:find("OnClick") == nil, true)
check("switch in all languages",
    ns.Locales.deDE.OPT_SKIN_PROFESSIONS ~= nil and ns.Locales.esES.OPT_SKIN_PROFESSIONS ~= nil
    and ns.Locales.frFR.OPT_SKIN_PROFESSIONS ~= nil and ns.Locales.enUS.OPT_SKIN_PROFESSIONS ~= nil, true)

print(("\n%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
