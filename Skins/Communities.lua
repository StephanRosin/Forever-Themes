--[[---------------------------------------------------------------------------
Skins/Communities.lua -- Blizzards Fenster "Gilde & Communitys"
(CommunitiesFrame, Forever 1.60.1: Blizzard_Communities/CommunitiesFrame.xml,
laedt bei Bedarf) im zentralen Theme. Der Menueeintrag und die Taste
oeffnen es ueber ToggleGuildFrame -> ToggleCommunitiesFrame (Camelot nutzt
Mainline/Game.lua); FriendsFrame hat hier keinen Gildenreiter. Schalter
"Blizzards Gildenfenster im Theme" (Optionen, Blizzards Fenster), kontoweit,
Standard aus. Gebaut wie Skins/Character.lua.

Im Theme:
  - Rahmen: NineSlice, Portraet samt Wappen (PortraitOverlay), Fels-Kachel,
    Streifen unter dem Titel und der Innenrahmen (Inset) aus, darunter
    Theme-Kachel, Ring, Titelstreifen, Pitwall-Keil, Ornamente
    (Skin.PaintArt) -- wie die Panels der Forever-Addons je Theme und Farbe.
  - Linke Liste (Communitys): Blizzards blaue Flaeche und Zierrand aus.
  - Gildeninfo: Pergament und Kopfbaender aus, die Ueberschriften in der
    Theme-Schrift und im Akzent (wie die Kopfzeilen der Werteliste).
  - Titel in der Theme-Schrift und im Akzent; Bezeichnungen ("Offline
    anzeigen", "Gildenruf:") in der Textschrift (Friz bleibt).
  - Schliessen: das gezeichnete Kreuz in der Symbolfarbe.
  - Seitenreiter rechts: Rahmen grau, Auswahl und Hover in der Symbolfarbe.
Blizzard bleibt: Chat und Eingabezeile, Mitgliederliste samt Spalten,
Neuigkeiten, Vorteile, Gildensuche, Bildlaufleisten, Auswahllisten, Knopf
Maximieren/Minimieren, die Rahmen um Chat und Listen.

Klassisch oder Schalter aus: alles wie von Blizzard (Skin.Restore).

Nachgezogen bei jedem Zeigen, bei jeder Groessenaenderung (Minimieren
wechselt 814x426 <-> 322x406, die Rundung haengt an der Groesse) und wenn
sich Theme, Farbe oder Schalter aendern. Nur Texturen, Schriften, Deckkraft.
Chat- und Gildentexte (MOTD, Infotext, Namen) werden nie angefasst: sie
koennen geheim sein, und Media.ApplyText liest Text erneut.
CommunitiesFrame ist nicht geschuetzt: die eigenen Teile duerfen auch
entstehen, wenn Blizzard_Communities erst im Kampf laedt.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local Themes, Skin = ns.Themes, ns.Skin

local CommunitiesSkin = {}
ns.CommunitiesSkin = CommunitiesSkin

local BLIZZARD_ADDON = "Blizzard_Communities"
-- Fels-Kachel und Streifen beginnen 21 unter der Oberkante (ButtonFrameBaseTemplate).
local TITLE_HEIGHT = 21
local TAB_TINT = { 0.3, 0.3, 0.3, 1 }
local BODY_FONT = "Friz Quadrata"
-- Die Seitenreiter (CommunitiesFrameTabTemplate -> RightSideTabTemplate).
local TABS = { "ChatTab", "RosterTab", "GuildBenefitsTab", "GuildInfoTab", "GuildPreferredPlaySettingsTab" }
local LIST_ART = { "Bg", "TopFiligree", "BottomFiligree", "FilligreeOverlay" }

local L_OPTION = {
    enUS = "Theme Blizzard's guild & communities window",
    deDE = "Blizzards Gildenfenster im Theme",
    esES = "Aplicar el tema a la ventana de hermandad y comunidades",
    frFR = "Appliquer le thème à la fenêtre de guilde et communautés",
}
for code, text in pairs(L_OPTION) do
    if ns.Locales[code] then ns.Locales[code].OPT_SKIN_COMMUNITIES = text end
end

local rec = Skin.NewRecord()
local art

function CommunitiesSkin.Enabled()
    return _G.ForeverThemesDB ~= nil and _G.ForeverThemesDB.skinCommunities == true
end

local function active()
    return CommunitiesSkin.Enabled() and Themes.Current() ~= Themes.CLASSIC
end

-- Wie Character.lua (Kandidat fuer Skin.lua): Zierschrift, Textschrift ohne Friz.
local function fonts()
    if not LibForeverThemes.LatinClient() then return nil, nil end
    local spec = Themes.Spec(Themes.Current())
    local body = spec.bodyFont or spec.font
    return spec.font, body ~= BODY_FONT and body or nil
end

local function titleStyle()
    local look = Themes.Spec(Themes.Current()).look
    local c = Themes.Accent(look.headerColor or ns.Settings.DEFAULTS.headerColor)
    return look.headerFlag or "OUTLINE", { c[1], c[2], c[3], 1 }
end

local function regions(frame)
    return frame and frame.GetRegions and { frame:GetRegions() } or {}
end

-- Gildeninfo (CommunitiesGuildInfoFrameTemplate): Pergament, Kopfbaender und
-- Wappen-Hintergrund liegen im BACKGROUND, die Ueberschriften sind die
-- Schriften der Ebene selbst (MOTD und Infotext sind Kinder, nicht dabei).
local function skinGuildInfo(info, display)
    local flag, color = titleStyle()
    for _, region in ipairs(regions(info)) do
        if region.GetObjectType and region:GetObjectType() == "FontString" then
            Skin.Font(rec, region, display, flag, color)
        elseif region.GetDrawLayer and region:GetDrawLayer() == "BACKGROUND" then
            Skin.Hide(rec, region)
        end
    end
end

local function hideBlizzardArt(frame)
    for _, key in ipairs({ "NineSlice", "PortraitContainer", "PortraitOverlay", "Bg", "TopTileStreaks" }) do
        Skin.Hide(rec, frame[key])
    end
    local inset = frame.Inset
    if inset then Skin.Hide(rec, inset.NineSlice); Skin.Hide(rec, inset.Bg) end
    local list = frame.CommunitiesList
    for _, key in ipairs(list and LIST_ART or {}) do Skin.Hide(rec, list[key]) end
end

local function skinTabs(frame, accent)
    for _, key in ipairs(TABS) do
        local tab = frame[key]
        if type(tab) == "table" then
            -- Der Reiterrahmen (SpellBook-SkillLineTab) ist die einzige Textur im BORDER.
            for _, region in ipairs(regions(tab)) do
                if region.GetDrawLayer and region:GetDrawLayer() == "BORDER" then Skin.Tint(rec, region, TAB_TINT, true) end
            end
            if tab.GetCheckedTexture then Skin.Tint(rec, tab:GetCheckedTexture(), accent, true) end
            if tab.GetHighlightTexture then Skin.Tint(rec, tab:GetHighlightTexture(), accent, true) end
        end
    end
end

local function skinTexts(frame)
    local display, body = fonts()
    local flag, color = titleStyle()
    Skin.Font(rec, frame.TitleContainer and frame.TitleContainer.TitleText, display, flag, color)
    local offline = frame.MemberList and frame.MemberList.ShowOfflineButton
    Skin.Font(rec, offline and offline.Text, body)
    local faction = frame.GuildBenefitsFrame and frame.GuildBenefitsFrame.FactionFrame
    Skin.Font(rec, faction and faction.Label, body)
    local details = frame.GuildDetailsFrame
    if details and details.Info then skinGuildInfo(details.Info, display) end
end

local function restore()
    Skin.Restore(rec)
    if art then Skin.HideArt(art) end
    Skin.CloseButton(rec, _G.CommunitiesFrame and _G.CommunitiesFrame.CloseButton, nil)
end

local drawn
local function signature()
    if not active() then return "off" end
    return Themes.Current() .. "|" .. tostring(Themes.Color())
end

-- force: auch ohne Aenderung von Theme, Farbe, Schalter (Zeigen, neue Groesse).
function CommunitiesSkin.Apply(force)
    local frame = _G.CommunitiesFrame
    if not (frame and art) then return end
    local now = signature()
    if now == drawn and not force then return end
    if now ~= drawn then restore() end
    drawn = now
    if now == "off" then return end
    Skin.PaintArt(art)
    hideBlizzardArt(frame)
    local accent = Themes.IconColor()
    Skin.CloseButton(rec, frame.CloseButton, accent)
    skinTabs(frame, accent)
    skinTexts(frame)
end

function CommunitiesSkin.SetEnabled(on)
    ns.AccountDB().skinCommunities = on and true or nil
    CommunitiesSkin.Apply()
end

-- Beim Login oder wenn Blizzard_Communities nachlaedt: eigene Teile anlegen.
function CommunitiesSkin.Setup()
    local frame = _G.CommunitiesFrame
    if not frame or art then return end
    art = Skin.NewArt(frame, TITLE_HEIGHT)
    Skin.NewCross(frame.CloseButton)
    local function again() CommunitiesSkin.Apply(true) end
    frame:HookScript("OnShow", again)
    frame:HookScript("OnSizeChanged", again)
    CommunitiesSkin.Apply(true)
end

-- Fuer die Tests: die eigene Kunst.
function CommunitiesSkin.Parts() return art end

-- Laedt Blizzard_Communities vor dem Login, richtet PLAYER_LOGIN ein (Themes bereit).
local loggedIn = false
ns.On("PLAYER_LOGIN", function() loggedIn = true; CommunitiesSkin.Setup() end)
ns.On("ADDON_LOADED", function(_, name) if name == BLIZZARD_ADDON and loggedIn then CommunitiesSkin.Setup() end end)
ns.Settings.OnChange(function() CommunitiesSkin.Apply() end)
