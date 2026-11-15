--[[---------------------------------------------------------------------------
Skins/Collections.lua -- Blizzards Sammlungsfenster (CollectionsJournal aus
Blizzard_Collections, Forever 1.60.1: Shared/Blizzard_Collections.xml,
Reiter Camelot/Blizzard_CollectionsTabs.xml, Inhalte Mainline/ und
Classic/Blizzard_PetCollection.xml) im zentralen Theme. Schalter
"Blizzards Sammlungsfenster im Theme" (Optionen, Blizzards Fenster), kontoweit,
Standard aus. Gebaut wie Skins/Character.lua (dort die Regeln).

Im Theme:
  - Rahmen: NineSlice, Portraet, Felsenkachel (Bg) und Streifen unter dem
    Titel aus, darunter Theme-Kachel, Ring, Titelstreifen samt Pitwall-Keil,
    Ornamente (Skin.PaintArt).
  - Die Innenrahmen der Reiter (Reittiere, Haustiere, Spielzeug, Erbstuecke,
    Vorlagen): Blizzards Kachel, Rand und Schatten aus.
  - Titel in der Theme-Schrift und im Akzent, die Bezeichnung der Zaehler
    (Reittiere/Haustiere gesamt) in der Textschrift (Friz bleibt Blizzards).
  - Schliessen: das gezeichnete Kreuz; Seitenreiter wie im Charakterfenster.
Blizzard bleibt: Modelle samt Hintergrund, Listen, Spielzeug- und
Vorlagenraster, Haustierkarte, Zaehlerkasten und Zahl, Suchfeld, Filter,
die Reiter Gegenstaende/Sets der Vorlagen, Bildlaufleisten, alle
Zauberknoepfe (geschuetzt).

Blizzard_Collections laedt bei Bedarf: eingehaengt beim ADDON_LOADED (oder
beim Login, falls schon geladen). Faellt das in den Kampf, wartet das
Anlegen auf PLAYER_REGEN_ENABLED: unter dem Fenster liegen geschuetzte
Zauberknoepfe, eigene Rahmen entstehen darum nie im Kampf.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local Themes, Skin = ns.Themes, ns.Skin

local CollectionsSkin = {}
ns.CollectionsSkin = CollectionsSkin

-- Blizzards Bg beginnt 21 unter der Oberkante (PortraitFrameTexturedBaseTemplate).
local TITLE_HEIGHT = 21
local TAB_TINT = { 0.3, 0.3, 0.3, 1 }
local BODY_FONT = "Friz Quadrata"
local COLLECTIONS_ADDON = "Blizzard_Collections"
-- Kachel, Ecken und Schatten der CollectionsBackgroundTemplate (SharedCollectionTemplates.xml).
local INSET_ATLASES = { ["collections-background-tile"] = true, ["collections-background-corner"] = true,
    ["collections-background-shadow-large"] = true, ["collections-background-shadow-small"] = true }
-- Die Seiten der Reiter (CollectionsJournal_UpdateSelectedTab).
-- Die Zaehler (CollectionsCountTemplate) je Reiter.
local COUNTERS = { MountJournal = "MountCount", PetJournal = "PetCount" }
local SUBFRAMES = { "MountJournal", "PetJournal", "ToyBox", "HeirloomsJournal", "WardrobeCollectionFrame" }

local L_OPTION = {
    enUS = "Theme Blizzard's collections window",
    deDE = "Blizzards Sammlungsfenster im Theme",
    esES = "Aplicar el tema a la ventana de colecciones",
    frFR = "Appliquer le thème à la fenêtre des collections",
}
for code, text in pairs(L_OPTION) do
    if ns.Locales[code] then ns.Locales[code].OPT_SKIN_COLLECTIONS = text end
end

local rec = Skin.NewRecord()
local art
local hooked = {}

-- ForeverThemesDB direkt gelesen: AccountDB() legte sie vor ADDON_LOADED an.
function CollectionsSkin.Enabled()
    return _G.ForeverThemesDB ~= nil and _G.ForeverThemesDB.skinCollections == true
end

local function active()
    return CollectionsSkin.Enabled() and Themes.Current() ~= Themes.CLASSIC
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

-- Ein Innenrahmen (InsetFrameTemplate, CollectionsBackgroundTemplate).
local function hideInset(inset)
    if type(inset) ~= "table" then return end
    Skin.Hide(rec, inset.Bg)
    Skin.Hide(rec, inset.NineSlice)
    Skin.HideAtlases(rec, inset, INSET_ATLASES)
end

-- Die Innenrahmen je Reiter; fehlt ein Reiter (andere Spielversion), bleibt er aus.
local function insets()
    local g = _G
    local mount, pet, wardrobe = g.MountJournal or {}, g.PetJournal or {}, g.WardrobeCollectionFrame or {}
    local sets = wardrobe.SetsCollectionFrame or {}
    return { mount.LeftInset, mount.BottomLeftInset, mount.RightInset, pet.LeftInset, pet.RightInset,
        g.ToyBox and g.ToyBox.iconsFrame, g.HeirloomsJournal and g.HeirloomsJournal.iconsFrame,
        wardrobe.ItemsCollectionFrame, sets.LeftInset, sets.RightInset }
end

local function hideBlizzardArt(frame)
    Skin.Hide(rec, frame.NineSlice)
    Skin.Hide(rec, frame.PortraitContainer)
    Skin.Hide(rec, frame.Bg)
    Skin.Hide(rec, frame.TopTileStreaks)
    -- Luecken (nil) in der Liste: pairs statt ipairs.
    for _, inset in pairs(insets()) do hideInset(inset) end
end

local function skinTabs(frame, accent)
    local tabs = frame.TabContainer and frame.TabContainer.Tabs
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
    Skin.Font(rec, frame.TitleContainer and frame.TitleContainer.TitleText, display, flag, color)
    -- Nur die Bezeichnung: die Zahl liest Media.ApplyText zurueck (GetText).
    for name, key in pairs(COUNTERS) do
        local count = _G[name] and _G[name][key]
        if type(count) == "table" then Skin.Font(rec, count.Label, body) end
    end
end

local function restore()
    Skin.Restore(rec)
    if art then Skin.HideArt(art) end
    Skin.CloseButton(rec, _G.CollectionsJournal and _G.CollectionsJournal.CloseButton, nil)
end

-- Was gerade gilt, damit eine Einstellungsmeldung nicht jedes Mal neu zeichnet.
local drawn
local function signature()
    if not active() then return "off" end
    return Themes.Current() .. "|" .. tostring(Themes.Color())
end

-- force: auch ohne Aenderung von Theme, Farbe und Schalter (Fenster gezeigt).
function CollectionsSkin.Apply(force)
    local frame = _G.CollectionsJournal
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

function CollectionsSkin.SetEnabled(on)
    ns.AccountDB().skinCollections = on and true or nil
    CollectionsSkin.Apply()
end

-- Reiterwechsel setzt den Titel (SetTitle): einen Takt spaeter nachziehen.
local function later() C_Timer.After(0, function() CollectionsSkin.Apply(true) end) end

-- Eigene Teile anlegen und einhaengen; nur ausserhalb des Kampfes.
function CollectionsSkin.Setup()
    local frame = _G.CollectionsJournal
    if not frame or art then return end
    art = Skin.NewArt(frame, TITLE_HEIGHT)
    Skin.NewCross(frame.CloseButton)
    frame:HookScript("OnShow", function() CollectionsSkin.Apply(true) end)
    for _, name in ipairs(SUBFRAMES) do
        local sub = _G[name]
        if sub and sub.HookScript and not hooked[name] then
            hooked[name] = true
            sub:HookScript("OnShow", later)
        end
    end
    CollectionsSkin.Apply(true)
end

-- Fuer die Tests: die eigene Kunst.
function CollectionsSkin.Parts() return art end

local loggedIn, waiting = false, false
local function trySetup()
    if not (loggedIn and _G.CollectionsJournal) or art then return end
    if InCombatLockdown() then waiting = true; return end
    CollectionsSkin.Setup()
end

ns.On("PLAYER_LOGIN", function() loggedIn = true; trySetup() end)
ns.On("ADDON_LOADED", function(_, name) if name == COLLECTIONS_ADDON then trySetup() end end)
ns.On("PLAYER_REGEN_ENABLED", function() if waiting then waiting = false; trySetup() end end)
ns.Settings.OnChange(function() CollectionsSkin.Apply() end)
