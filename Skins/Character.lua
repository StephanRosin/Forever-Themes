--[[---------------------------------------------------------------------------
Skins/Character.lua -- Blizzards Charakterfenster (CharacterFrame, Forever
1.60.1: Blizzard_UIPanels_Game/Camelot/CharacterFrame.xml) im zentralen
Theme. Schalter "Blizzards Charakterfenster im Theme" (Optionen, unter
Blizzards Fenster), kontoweit, Standard aus. Haengt nur an Skins/Skin.lua,
Themes und einer Zeile in Options.lua.

Im Theme:
  - Rahmen: NineSlice und Portraet aus, darunter Theme-Kachel, Ring,
    Titelstreifen (Glanz, Linie, Band, Pitwall-Keil), Ornamente
    (Skin.PaintArt) -- Hintergrund und Toenung wie die Panels der Forever-Addons je Theme und Farbe.
  - Hintergruende der linken und rechten Seite, Steinkopf, Klassenbild und
    Innenrahmen der Werte-, Titel- und Ausruestungslisten aus; die
    Trennlinie zwischen den Seiten in der Linienfarbe des Themes.
  - Titel in der Theme-Schrift und Kopfzeilenfarbe (Akzent), Stufenzeile und
    Bezeichnungen der Werte in der Textschrift (bodyFont; wo das Friz ist, bleibt Blizzards;
    die Stufenzeile nimmt dort die Zierschrift).
  - Kopfzeilen der Werte (Gegenstandsstufe, Attribute ...) ohne Blizzards
    Band, Titel in Theme-Schrift und Akzent.
  - Schliessen: das gezeichnete Kreuz in der Symbolfarbe.
  - Seitenreiter: grau getoent, Auswahl und Hover in der Symbolfarbe.
Blizzard bleibt: 3D-Modell samt Hintergrund, Ausruestungsplaetze, Reiter
der Werteseite, Inhalt von Ruf, Fertigkeiten, PvP, Waehrung, Statistik,
Bildlaufleisten, die Zahlen der Werteliste.

Klassisch oder Schalter aus: alles wie von Blizzard (Skin.Restore).

Nachgezogen wird bei jedem Zeigen des Fensters und eines Reiters (einen
Takt spaeter: Blizzard setzt die Titelfarbe danach neu), bei jeder neu
belegten Zeile der Werteliste (ScrollUtil-Rueckruf, kein Hook) und wenn sich
Theme, Farbe oder Schalter aendern. Nur Texturen, Schriften, Deckkraft: das
darf auch im Kampf laufen. Werte werden nie gelesen (Forever macht sie
geheim).
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local Themes, Skin = ns.Themes, ns.Skin

local CharacterSkin = {}
ns.CharacterSkin = CharacterSkin

-- Die linke Seite beginnt 20 unter der Oberkante (LeftPaneHost, y = -20).
local TITLE_HEIGHT = 20
local TAB_TINT = { 0.3, 0.3, 0.3, 1 }
local BODY_FONT = "Friz Quadrata"
local DIVIDER_WIDTH = 1
-- Blizzards Flaechen hinter den Seiten (CharacterFrame.xml, Camelot).
local PANE_ATLASES = { ["UI-Character-Info-General-BG"] = true, ["UI-Character-Info-Stat-BG"] = true,
    ["UI-Character-Info-Stat-StoneBG3"] = true }
local DIVIDER_ATLASES = { ["common-framedivider"] = true }
-- Die Seiten, die CharacterFrame:ShowSubFrame zeigt (CharacterFrameConstants.lua).
local SUBFRAMES = { "PaperDollFrame", "ReputationFrame", "TokenFrame", "PVPRankFrame", "SkillsFrame",
    "StatisticsFrame" }

local L_OPTION = {
    enUS = "Theme Blizzard's character window",
    deDE = "Blizzards Charakterfenster im Theme",
    esES = "Aplicar el tema a la ventana de personaje",
    frFR = "Appliquer le thème à la fenêtre du personnage",
}
for code, text in pairs(L_OPTION) do
    if ns.Locales[code] then ns.Locales[code].OPT_SKIN_CHARACTER = text end
end

local rec = Skin.NewRecord()
local art, divider
local statRows = setmetatable({}, { __mode = "k" })
local hooked = {}

-- ForeverThemesDB direkt gelesen: AccountDB() legte sie vor ADDON_LOADED an.
function CharacterSkin.Enabled()
    return _G.ForeverThemesDB ~= nil and _G.ForeverThemesDB.skinCharacter == true
end

local function active()
    return CharacterSkin.Enabled() and Themes.Current() ~= Themes.CLASSIC
end

-- Theme-Schriften haben nur lateinische Buchstaben (LibForeverThemes.LatinClient).
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

-- Eine Zeile der Werteliste: Kopfzeile (Title) oder Wert (Label, Value).
local function skinStatRow(row)
    statRows[row] = true
    if not active() then return end
    local display, body = fonts()
    if row.Title then
        Skin.Hide(rec, row.Background)
        local flag, color = titleStyle()
        Skin.Font(rec, row.Title, display, flag, color)
    else
        -- Nur die Bezeichnung: Media.ApplyText liest den Text spaeter noch
        -- einmal (GetText), und der Wert kann geheim sein.
        Skin.Font(rec, row.Label, body)
    end
end

local function hideBlizzardArt(frame)
    Skin.Hide(rec, frame.NineSlice)
    Skin.Hide(rec, frame.PortraitContainer)
    Skin.HideAtlases(rec, frame.LeftPaneHost, PANE_ATLASES)
    local right = frame.RightPaneHost
    Skin.HideAtlases(rec, right, PANE_ATLASES)
    for _, child in ipairs(right and { right:GetChildren() } or {}) do Skin.HideAtlases(rec, child, DIVIDER_ATLASES) end
    local stats, pet = _G.CharacterStatsPaneScrollBox, _G.CharacterStatsPanePetScrollBox
    if stats then Skin.Hide(rec, stats.ClassBackground); Skin.Hide(rec, stats.Border) end
    if pet then Skin.Hide(rec, pet.Border) end
    local doll = _G.PaperDollFrame
    if doll then
        local strip = doll.TopBackgroundStripHost
        if strip then Skin.Hide(rec, strip.TopBackgroundStrip); Skin.Hide(rec, strip.TopBackgroundStripBottomEdge) end
        for _, key in ipairs({ "TitleManagerPane", "EquipmentManagerPane" }) do
            local pane = doll[key]
            if type(pane) == "table" then Skin.Hide(rec, pane.Border) end
        end
    end
end

local function skinTabs(frame, accent)
    local tabs = frame.ModeTabs and frame.ModeTabs.Tabs
    for _, tab in ipairs(tabs or {}) do
        Skin.Tint(rec, tab.Background, TAB_TINT, true)
        Skin.Tint(rec, tab.SelectedTexture, accent, true)
        Skin.Tint(rec, tab.TabGlow, accent, true)
        Skin.Tint(rec, tab.HighlightTexture, accent, true)
    end
end

local function skinTexts(frame)
    local display, body = fonts()
    local flag, color = titleStyle()
    local title = frame.TitleContainer and frame.TitleContainer.TitleText
    Skin.Font(rec, title, display, flag, color)
    -- Die Stufenzeile steht oben bei der Ueberschrift: ist die Textschrift
    -- Friz (Blizzards eigene), nimmt sie die Zierschrift, sonst sieht sie
    -- ungethemt aus (wie Themes.ForeignFont).
    Skin.Font(rec, _G.CharacterLevelText, body or display)
    Skin.Font(rec, _G.PetCharacterLevelText, body or display)
end

local function paintDivider()
    if not divider then return end
    local l = Themes.Spec(Themes.Current()).art.line
    divider:SetColorTexture(l[1], l[2], l[3], l[4])
    divider:Show()
end

local function restore()
    Skin.Restore(rec)
    if art then Skin.HideArt(art) end
    if divider then divider:Hide() end
    Skin.CloseButton(rec, _G.CharacterFrame and _G.CharacterFrame.CloseButton, nil)
end

-- Was gerade gilt, damit eine Einstellungsmeldung (Ziehen des Panels ...)
-- nicht jedes Mal neu zeichnet.
local drawn
local function signature()
    if not active() then return "off" end
    return Themes.Current() .. "|" .. tostring(Themes.Color())
end

-- force: auch wenn sich Theme, Farbe und Schalter nicht geaendert haben
-- (Fenster gezeigt: Blizzard setzt Farben und Bilder neu).
function CharacterSkin.Apply(force)
    local frame = _G.CharacterFrame
    if not (frame and art) then return end
    local now = signature()
    if now == drawn and not force then return end
    -- Ein anderes Theme: Blizzards Stand zurueck, dann neu (Schriften ohne Theme-Schrift ...).
    if now ~= drawn then restore() end
    drawn = now
    if now == "off" then return end
    Skin.PaintArt(art)
    hideBlizzardArt(frame)
    paintDivider()
    local accent = Themes.IconColor()
    Skin.CloseButton(rec, frame.CloseButton, accent)
    skinTabs(frame, accent)
    skinTexts(frame)
    for row in pairs(statRows) do skinStatRow(row) end
end

function CharacterSkin.SetEnabled(on)
    ns.AccountDB().skinCharacter = on and true or nil
    CharacterSkin.Apply()
end

-- Reiter: Blizzard setzt die Titelfarbe nach dem Zeigen (RefreshDisplay),
-- darum einen Takt spaeter.
local function later() C_Timer.After(0, function() CharacterSkin.Apply(true) end) end

local function hookSubframes()
    for _, name in ipairs(SUBFRAMES) do
        local sub = _G[name]
        if sub and sub.HookScript and not hooked[name] then
            hooked[name] = true
            sub:HookScript("OnShow", later)
        end
    end
end

local function hookStatRows()
    local box = _G.CharacterStatsPaneScrollBox and _G.CharacterStatsPaneScrollBox.ScrollBox
    if not (box and ScrollUtil and ScrollUtil.AddInitializedFrameCallback) or hooked.stats then return end
    hooked.stats = true
    ScrollUtil.AddInitializedFrameCallback(box, function(_, row) skinStatRow(row) end, CharacterSkin, true)
end

-- Beim Login: eigene Teile anlegen (nicht erst im Kampf) und einhaengen.
function CharacterSkin.Setup()
    local frame = _G.CharacterFrame
    if not frame or art then return end
    art = Skin.NewArt(frame, TITLE_HEIGHT)
    if frame.RightPaneHost then
        divider = Skin.OwnTexture(frame.RightPaneHost, "OVERLAY")
        divider:SetPoint("TOPLEFT")
        divider:SetPoint("BOTTOMLEFT")
        divider:SetWidth(DIVIDER_WIDTH)
    end
    Skin.NewCross(frame.CloseButton)
    frame:HookScript("OnShow", function() CharacterSkin.Apply(true) end)
    hookSubframes()
    hookStatRows()
    CharacterSkin.Apply(true)
end

-- Fuer die Tests: die eigene Kunst und die Trennlinie.
function CharacterSkin.Parts() return art, divider end

ns.On("PLAYER_LOGIN", CharacterSkin.Setup)
-- Waehrung und Statistik koennen spaeter laden.
ns.On("ADDON_LOADED", function() if art then hookSubframes() end end)
ns.Settings.OnChange(function() CharacterSkin.Apply() end)
