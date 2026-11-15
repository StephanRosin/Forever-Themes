-- Blizzard's guild and communities frame in the theme (Skins/Skin.lua,
-- Skins/Communities.lua). Own file so wowmock.lua stays untouched:
-- the frame is rebuilt here as far as the addon touches it
-- (Blizzard_Communities/CommunitiesFrame.xml, loads on demand).
local M = dofile("wowmock.lua")

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

local function tex(layer, alpha)
    local t = blizzard()
    t._layer, t._alpha = layer, alpha
    function t:GetDrawLayer() return self._layer end
    function t:GetObjectType() return "Texture" end
    function t:GetVertexColor() local v = self._vertex or { 1, 1, 1, 1 }; return v[1], v[2], v[3], v[4] end
    function t:SetDesaturated(v) self._desaturated = v end
    function t:IsDesaturated() return self._desaturated == true end
    return t
end

local function text()
    local fs = blizzard():CreateFontString()
    function fs:GetObjectType() return "FontString" end
    return fs
end

local function regions(frame, list) function frame:GetRegions() return unpack(list) end end

-- The frame only exists once Blizzard_Communities loads (after login).
local frame, closeTextures, chatTab, tabBorder, tabIcon, info, infoBack, header1, infoBar, infoHead, offline, faction
local function loadBlizzardCommunities()
    frame = blizzard("CommunitiesFrame")
    frame._w, frame._h = 814, 426
    for _, key in ipairs({ "NineSlice", "PortraitContainer", "PortraitOverlay" }) do frame[key] = blizzard() end
    frame.Bg, frame.TopTileStreaks = tex("BACKGROUND"), tex("BORDER")
    frame.Inset = blizzard("CommunitiesFrameInset")
    frame.Inset.NineSlice, frame.Inset.Bg = blizzard(), tex("BACKGROUND")
    frame.CommunitiesList = blizzard("CommunitiesFrameCommunitiesList")
    frame.CommunitiesList.Bg, frame.CommunitiesList.TopFiligree = tex("ARTWORK"), tex("ARTWORK")
    frame.CommunitiesList.BottomFiligree, frame.CommunitiesList.FilligreeOverlay = tex("ARTWORK"), blizzard()
    frame.TitleContainer = blizzard()
    frame.TitleContainer.TitleText = text()
    closeTextures = { tex(), tex(), tex(), tex() }
    frame.CloseButton = blizzard("CommunitiesFrameCloseButton")
    function frame.CloseButton:GetNormalTexture() return closeTextures[1] end
    function frame.CloseButton:GetPushedTexture() return closeTextures[2] end
    function frame.CloseButton:GetHighlightTexture() return closeTextures[3] end
    function frame.CloseButton:GetDisabledTexture() return closeTextures[4] end
    chatTab = blizzard()
    tabBorder, tabIcon = tex("BORDER"), tex("ARTWORK")
    chatTab.Icon = tabIcon
    chatTab._checked, chatTab._highlight = tex("ARTWORK"), tex("HIGHLIGHT")
    function chatTab:GetCheckedTexture() return self._checked end
    function chatTab:GetHighlightTexture() return self._highlight end
    regions(chatTab, { tabBorder, tabIcon, chatTab._checked, chatTab._highlight })
    frame.ChatTab = chatTab
    frame.MemberList = blizzard()
    offline = blizzard()
    offline.Text = text()
    frame.MemberList.ShowOfflineButton = offline
    frame.GuildBenefitsFrame = { FactionFrame = { Label = text() } }
    info = blizzard("CommunitiesFrameGuildDetailsFrameInfo")
    infoBack, header1, infoBar, infoHead = tex("BACKGROUND"), tex("BACKGROUND", 0.8), tex("ARTWORK"), text()
    info.Header1 = header1
    regions(info, { infoHead, infoBar, infoBack, header1 })
    frame.GuildDetailsFrame = { Info = info }
end

local ns = dofile("load.lua")()
-- A stored ForeverThemesDB without the switch (a new one has every skin on).
ForeverThemesDB = {}

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

local Themes, Skin, Media = ns.Themes, ns.CommunitiesSkin, ns.Media
local FRIZ = "Fonts\\FRIZQT__.TTF"
local function alpha(region) return region:GetAlpha() end

print("\nLoad on demand:")
fire("PLAYER_LOGIN")
check("at login no frame yet, no art", Skin.Parts(), nil)
loadBlizzardCommunities()
fire("ADDON_LOADED", "Blizzard_Calendar")
check("other addon: nothing created", Skin.Parts(), nil)
fire("ADDON_LOADED", "Blizzard_Communities")
local art = Skin.Parts()
check("Blizzard_Communities loaded: created", art ~= nil, true)
fire("ADDON_LOADED", "Blizzard_Communities")
check("second load does not recreate", Skin.Parts(), art)
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
check("saved account-wide", ForeverThemesDB.skinCommunities, true)
check("tile visible", art.back:IsShown(), true)
for _, key in ipairs({ "NineSlice", "PortraitContainer", "PortraitOverlay", "Bg", "TopTileStreaks" }) do
    check(key .. " off", alpha(frame[key]), 0)
end
check("inner frame off", alpha(frame.Inset.NineSlice), 0)
check("inset background off", alpha(frame.Inset.Bg), 0)
check("list: blue background off", alpha(frame.CommunitiesList.Bg), 0)
check("list: filigree off", alpha(frame.CommunitiesList.FilligreeOverlay), 0)
check("close: Blizzard's art off", alpha(closeTextures[1]), 0)
check("title: Cinzel", (title:GetFont()), Media.FontPath("Cinzel"))
check("offline button: bodyFont Friz stays", (offline.Text:GetFont()), FRIZ)
local icon = Themes.IconColor()
check("tab: selection in the icon colour", list(chatTab._checked._vertex), list({ icon[1], icon[2], icon[3], 1 }))
check("tab: hover in the icon colour", list(chatTab._highlight._vertex), list({ icon[1], icon[2], icon[3], 1 }))
check("tab: border grey", list(tabBorder._vertex), "0.3,0.3,0.3,1")
check("tab: border desaturated", tabBorder:IsDesaturated(), true)
check("tab: icon untouched", tabIcon._vertex, nil)
check("guild info: parchment off", alpha(infoBack), 0)
check("guild info: header band off", alpha(header1), 0)
check("guild info: divider bar stays", alpha(infoBar), 1)
check("guild info: heading Cinzel", (infoHead:GetFont()), Media.FontPath("Cinzel"))
check("no layout on Blizzard's frames", layoutCalls, 0)

print("\nLike the panel, per theme and colour:")
local panel = dofile("reference.lua")(ns)
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
check("Pitwall: offline button in the body font", (offline.Text:GetFont()), Media.FontPath("Titillium Web SemiBold"))
check("Pitwall: guild reputation in the body font", (frame.GuildBenefitsFrame.FactionFrame.Label:GetFont()),
    Media.FontPath("Titillium Web SemiBold"))
Themes.Switch("FROST")
check("Frost: title Julius", (title:GetFont()), Media.FontPath("Julius Sans One"))
check("Frost: no wedge", art.wedge:IsShown(), false)
check("Frost: dark shade", art.shade:IsShown(), true)
check("Frost: offline button back to Friz (bodyFont)", 
    (offline.Text:GetFont()) ~= Media.FontPath("Titillium Web SemiBold"), true)
-- Minimise: Blizzard changes the size, the art is refitted.
title:SetTextColor(1, 1, 1, 1)
frame._w, frame._h = 322, 406
frame._scriptHooks.OnSizeChanged()
local accent = Themes.Accent(Themes.SPECS.FROST.look.headerColor)
check("new size: title back in the accent", list(title._textColor), list({ accent[1], accent[2], accent[3], 1 }))
check("new size: tile stays", art.back:IsShown(), true)

print("\nClassic restores everything:")
Themes.Switch("CLASSIC")
check("NineSlice back", alpha(frame.NineSlice), 1)
check("header band at its own alpha", alpha(header1), 0.8)
check("list back", alpha(frame.CommunitiesList.Bg), 1)
check("tile off", art.back:IsShown(), false)
check("wedge off", art.wedge:IsShown(), false)
check("title in Friz", (title:GetFont()), FRIZ)
check("heading in Friz", (infoHead:GetFont()), FRIZ)
check("tab no longer desaturated", tabBorder:IsDesaturated(), false)
check("tab untinted", list(chatTab._checked._vertex), "1,1,1,1")
check("close: Blizzard's art back", alpha(closeTextures[1]), 1)
check("ring gone", ns.Border.Pieces(art.over)[1]:IsShown(), false)

print("\nSwitch off under a theme:")
Themes.Switch("TECH")
check("Tech: title Space Grotesk", (title:GetFont()), Media.FontPath("Space Grotesk"))
Skin.SetEnabled(false)
check("off: saved without entry", ForeverThemesDB.skinCommunities, nil)
check("off: NineSlice back", alpha(frame.NineSlice), 1)
check("off: title in Friz", (title:GetFont()), FRIZ)
check("off: tile off", art.back:IsShown(), false)
frame._scriptHooks.OnShow()
check("off: showing changes nothing", alpha(frame.NineSlice), 1)

print("\nTraps:")
local h = assert(io.open(ADDONDIR .. "/Skins/Communities.lua")); local src = h:read("*a"); h:close()
-- Comments do not count: they explain why it is missing.
src = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
check("no hooksecurefunc", src:find("hooksecurefunc") == nil, true)
check("no GetText (chat/guild texts may be secret)", src:find("GetText") == nil, true)
local all = true
for _, code in ipairs({ "enUS", "deDE", "esES", "frFR" }) do
    local s = ns.Locales[code].OPT_SKIN_COMMUNITIES
    all = all and s ~= nil and not s:find("\195\159")
end
check("switch in all languages, no sharp s", all, true)

print(("\n%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
