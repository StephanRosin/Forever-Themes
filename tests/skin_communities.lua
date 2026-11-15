-- Blizzards Gilden- und Communityfenster im Theme (Skins/Skin.lua,
-- Skins/Communities.lua). Eigene Datei, damit wowmock.lua unberuehrt bleibt:
-- das Fenster ist hier nachgestellt, so weit das Addon es anfasst
-- (Blizzard_Communities/CommunitiesFrame.xml, laedt bei Bedarf).
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

-- Das Fenster entsteht erst, wenn Blizzard_Communities laedt (nach dem Login).
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

local pass, fail = 0, 0
local function check(label, got, want)
    if got == want then pass = pass + 1; print(("  OK   %-52s -> %s"):format(label, tostring(got)))
    else fail = fail + 1; print(("  FAIL %-52s -> %s   (erwartet: %s)"):format(label, tostring(got), tostring(want))) end
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

print("\nLaedt bei Bedarf:")
fire("PLAYER_LOGIN")
check("beim Login noch kein Fenster, keine Kunst", Skin.Parts(), nil)
loadBlizzardCommunities()
fire("ADDON_LOADED", "Blizzard_Calendar")
check("fremdes Addon: nichts angelegt", Skin.Parts(), nil)
fire("ADDON_LOADED", "Blizzard_Communities")
local art = Skin.Parts()
check("Blizzard_Communities geladen: angelegt", art ~= nil, true)
fire("ADDON_LOADED", "Blizzard_Communities")
check("zweites Laden legt nicht neu an", Skin.Parts(), art)
local title = frame.TitleContainer.TitleText

print("\nSchalter aus (Standard):")
check("Standard aus", Skin.Enabled(), false)
Themes.Switch("WOOD")
check("Wood ohne Schalter: NineSlice bleibt", alpha(frame.NineSlice), 1)
check("Wood ohne Schalter: keine Kachel", art.back:IsShown(), false)
check("Wood ohne Schalter: Titel in Friz", (title:GetFont()), FRIZ)

print("\nSchalter an:")
layoutCalls = 0
Skin.SetEnabled(true)
check("gespeichert kontoweit", ForeverThemesDB.skinCommunities, true)
check("Kachel sichtbar", art.back:IsShown(), true)
for _, key in ipairs({ "NineSlice", "PortraitContainer", "PortraitOverlay", "Bg", "TopTileStreaks" }) do
    check(key .. " aus", alpha(frame[key]), 0)
end
check("Innenrahmen aus", alpha(frame.Inset.NineSlice), 0)
check("Innenflaeche aus", alpha(frame.Inset.Bg), 0)
check("Liste: blaue Flaeche aus", alpha(frame.CommunitiesList.Bg), 0)
check("Liste: Zierrand aus", alpha(frame.CommunitiesList.FilligreeOverlay), 0)
check("Schliessen: Blizzards Bild aus", alpha(closeTextures[1]), 0)
check("Titel: Cinzel", (title:GetFont()), Media.FontPath("Cinzel"))
check("Offline-Knopf: bodyFont Friz bleibt", (offline.Text:GetFont()), FRIZ)
local icon = Themes.IconColor()
check("Reiter: Auswahl in der Symbolfarbe", list(chatTab._checked._vertex), list({ icon[1], icon[2], icon[3], 1 }))
check("Reiter: Hover in der Symbolfarbe", list(chatTab._highlight._vertex), list({ icon[1], icon[2], icon[3], 1 }))
check("Reiter: Rahmen grau", list(tabBorder._vertex), "0.3,0.3,0.3,1")
check("Reiter: Rahmen entsaettigt", tabBorder:IsDesaturated(), true)
check("Reiter: Symbol unberuehrt", tabIcon._vertex, nil)
check("Gildeninfo: Pergament aus", alpha(infoBack), 0)
check("Gildeninfo: Kopfband aus", alpha(header1), 0)
check("Gildeninfo: Trennbalken bleibt", alpha(infoBar), 1)
check("Gildeninfo: Ueberschrift Cinzel", (infoHead:GetFont()), Media.FontPath("Cinzel"))
check("keine Anordnung an Blizzards Rahmen", layoutCalls, 0)

print("\nWie das Panel, je Theme und Farbe:")
local panel = dofile("reference.lua")(ns)
local mismatch = {}
for _, id in ipairs(Themes.IDS) do
    if id ~= Themes.CLASSIC then
        Themes.Switch(id)
        for _, color in ipairs(Themes.Colors(id)) do
            Themes.SetColor(color, id)
            panel.Paint()
            local where = id .. "/" .. color
            if art.back._texture ~= panel.bg._texture then mismatch[#mismatch + 1] = where .. " Textur" end
            if list(art.back._vertex) ~= list(panel.bg._vertex) then mismatch[#mismatch + 1] = where .. " Toenung" end
            local mine, theirs = ns.Border.Pieces(art.over)[1], ns.Border.Pieces(panel)[1]
            if list(mine._vertex) ~= list(theirs._vertex) then mismatch[#mismatch + 1] = where .. " Rand" end
        end
    end
end
check("Kachel, Toenung und Rand wie das InfoPanel", table.concat(mismatch, "; "), "")

print("\nThemenwechsel:")
Themes.SetColor("ORANGE", "PITWALL")
Themes.Switch("PITWALL")
check("Pitwall: Keil", art.wedge:IsShown(), true)
check("Pitwall: Keil in der Farbe", list(art.wedge._vertex), list(Themes.Wedge({ 0.882, 0.024, 0, 1 })))
check("Pitwall: Titel Titillium", (title:GetFont()), Media.FontPath("Titillium Web Bold Italic"))
check("Pitwall: Offline-Knopf in der Textschrift", (offline.Text:GetFont()), Media.FontPath("Titillium Web SemiBold"))
check("Pitwall: Gildenruf in der Textschrift", (frame.GuildBenefitsFrame.FactionFrame.Label:GetFont()),
    Media.FontPath("Titillium Web SemiBold"))
Themes.Switch("FROST")
check("Frost: Titel Julius", (title:GetFont()), Media.FontPath("Julius Sans One"))
check("Frost: kein Keil", art.wedge:IsShown(), false)
check("Frost: dunkle Flaeche", art.shade:IsShown(), true)
check("Frost: Offline-Knopf wieder Friz (bodyFont)", (offline.Text:GetFont()) ~= Media.FontPath("Titillium Web SemiBold"), true)
-- Minimieren: Blizzard aendert die Groesse, die Kunst wird neu eingepasst.
title:SetTextColor(1, 1, 1, 1)
frame._w, frame._h = 322, 406
frame._scriptHooks.OnSizeChanged()
local accent = Themes.Accent(Themes.SPECS.FROST.look.headerColor)
check("neue Groesse: Titel wieder im Akzent", list(title._textColor), list({ accent[1], accent[2], accent[3], 1 }))
check("neue Groesse: Kachel bleibt", art.back:IsShown(), true)

print("\nKlassisch stellt alles her:")
Themes.Switch("CLASSIC")
check("NineSlice zurueck", alpha(frame.NineSlice), 1)
check("Kopfband auf seine Deckkraft", alpha(header1), 0.8)
check("Liste zurueck", alpha(frame.CommunitiesList.Bg), 1)
check("Kachel aus", art.back:IsShown(), false)
check("Keil aus", art.wedge:IsShown(), false)
check("Titel in Friz", (title:GetFont()), FRIZ)
check("Ueberschrift in Friz", (infoHead:GetFont()), FRIZ)
check("Reiter nicht mehr entsaettigt", tabBorder:IsDesaturated(), false)
check("Reiter ungetoent", list(chatTab._checked._vertex), "1,1,1,1")
check("Schliessen: Blizzards Bild zurueck", alpha(closeTextures[1]), 1)
check("Ring weg", ns.Border.Pieces(art.over)[1]:IsShown(), false)

print("\nSchalter aus unter einem Theme:")
Themes.Switch("TECH")
check("Tech: Titel Space Grotesk", (title:GetFont()), Media.FontPath("Space Grotesk"))
Skin.SetEnabled(false)
check("aus: gespeichert ohne Eintrag", ForeverThemesDB.skinCommunities, nil)
check("aus: NineSlice zurueck", alpha(frame.NineSlice), 1)
check("aus: Titel in Friz", (title:GetFont()), FRIZ)
check("aus: Kachel aus", art.back:IsShown(), false)
frame._scriptHooks.OnShow()
check("aus: Zeigen aendert nichts", alpha(frame.NineSlice), 1)

print("\nFallen:")
local h = assert(io.open(ADDONDIR .. "/Skins/Communities.lua")); local src = h:read("*a"); h:close()
-- Kommentare zaehlen nicht: sie erklaeren gerade, warum es fehlt.
src = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
check("kein hooksecurefunc", src:find("hooksecurefunc") == nil, true)
check("kein GetText (Chat/Gildentexte koennen geheim sein)", src:find("GetText") == nil, true)
local all = true
for _, code in ipairs({ "enUS", "deDE", "esES", "frFR" }) do
    local s = ns.Locales[code].OPT_SKIN_COMMUNITIES
    all = all and s ~= nil and not s:find("\195\159")
end
check("Schalter in allen Sprachen, ohne sz", all, true)

print(("\n%d bestanden, %d fehlgeschlagen"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
