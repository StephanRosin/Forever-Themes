-- Blizzards Talentfenster im Theme (Skins/Skin.lua, Skins/Talents.lua).
-- Eigene Datei, damit wowmock.lua unberuehrt bleibt: das Fenster ist hier
-- nachgestellt, so weit das Addon es anfasst
-- (Camelot/ClassTalents/Blizzard_ClassTalentsFrame.xml).
local M = dofile("wowmock.lua")

-- Blizzards Rahmen: zaehlt jede Aenderung an Anordnung und Sichtbarkeit.
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

-- Der aeussere Rahmen existiert erst, wenn Blizzard_PlayerSpells laedt.
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
    else fail = fail + 1; print(("  FAIL %-52s -> %s   (erwartet: %s)"):format(label, tostring(got), tostring(want))) end
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

print("\nLaden bei Bedarf:")
fire("PLAYER_LOGIN")
check("Login ohne Talentfenster: nichts angelegt", Skin.Parts(), nil)
loadBlizzard()
fire("ADDON_LOADED", "Blizzard_SomethingElse")
check("fremdes Addon geladen: nichts angelegt", Skin.Parts(), nil)
layoutCalls = 0
fire("ADDON_LOADED", "Blizzard_PlayerSpells")
local back, shade = Skin.Parts()
check("Blizzard_PlayerSpells geladen: angelegt", back ~= nil, true)
check("OnShow eingehaengt", frame._scriptHooks.OnShow ~= nil, true)
local panel = dofile("reference.lua")(ns)

print("\nSchalter aus (Standard):")
check("Standard aus", Skin.Enabled(), false)
Themes.Switch("WOOD")
check("Wood ohne Schalter: Hintergrund bleibt", alpha(frame.Background), 1)
check("Wood ohne Schalter: keine Kachel", back:IsShown(), false)
check("Wood ohne Schalter: Baumname in Friz", (header.Name:GetFont()), FRIZ)

print("\nSchalter an:")
Skin.SetEnabled(true)
check("gespeichert kontoweit", ForeverThemesDB.skinTalents, true)
check("Kachel sichtbar", back:IsShown(), true)
check("Hintergrund aus", alpha(frame.Background), 0)
check("Klassenbild aus", alpha(frame.ClassBackground), 0)
check("Innenrahmen aus", alpha(frame.BackgroundBorder), 0)
check("pulsierendes Klassenbild schwarz", list(frame.OverlayBackgroundMid._vertex), "0,0,0,1")
local l = Themes.Spec("WOOD").art.line
check("Trennlinie in der Linienfarbe", list(frame.DividerVerticalLeft._vertex), list(l))
check("Trennlinie entsaettigt", frame.DividerVerticalLeft:IsDesaturated(), true)
check("Baumname: Cinzel", (header.Name:GetFont()), Media.FontPath("Cinzel"))
local hc = Themes.Accent(Themes.SPECS.WOOD.look.headerColor or ns.Settings.DEFAULTS.headerColor)
check("Baumname im Akzent", list(header.Name._textColor), list({ hc[1], hc[2], hc[3], 1 }))
local icon = Themes.IconColor()
check("Ring um das Symbol in der Symbolfarbe", list(header.MainRing._vertex), list({ icon[1], icon[2], icon[3], 1 }))
check("Aktiv: bodyFont Friz -> Zierschrift", (frame.ActiveSpec.ActiveLabel:GetFont()), Media.FontPath("Cinzel"))
check("Unverteilt: bodyFont Friz bleibt", (frame.ClassCurrencyDisplay.UnspentLabel:GetFont()), FRIZ)
check("Punktzahl unberuehrt", (frame.ClassCurrencyDisplay.CurrencyAmount:GetFont()), FRIZ)
check("Reiter: Auswahl in der Symbolfarbe", list(tab.MiddleActive._vertex), list({ icon[1], icon[2], icon[3], 1 }))
check("Reiter: grau", list(tab.Middle._vertex), "0.3,0.3,0.3,1")
check("keine Anordnung an Blizzards Rahmen", layoutCalls, 0)

print("\nWie das Panel, je Theme und Farbe:")
local mismatch = {}
for _, id in ipairs(Themes.IDS) do
    if id ~= Themes.CLASSIC then
        Themes.Switch(id)
        for _, color in ipairs(Themes.Colors(id)) do
            Themes.SetColor(color, id)
            panel.Paint()
            local where = id .. "/" .. color
            if back._texture ~= panel.bg._texture then mismatch[#mismatch + 1] = where .. " Textur" end
            if list(back._vertex) ~= list(panel.bg._vertex) then mismatch[#mismatch + 1] = where .. " Toenung" end
            local wanted = Themes.Spec(id).art.contentShade
            if shade:IsShown() ~= (wanted ~= nil) then mismatch[#mismatch + 1] = where .. " Flaeche" end
        end
    end
end
check("Kachel, Toenung und Flaeche gleich", table.concat(mismatch, "; "), "")

print("\nThemenwechsel:")
Themes.SetColor("ORANGE", "PITWALL")
Themes.Switch("PITWALL")
check("Pitwall: Baumname Titillium", (header.Name:GetFont()), Media.FontPath("Titillium Web Bold Italic"))
check("Pitwall: Punktzahl in der Textschrift", (header.Text:GetFont()), Media.FontPath("Titillium Web SemiBold"))
check("Pitwall: Aktiv in der Textschrift", (frame.ActiveSpec.ActiveLabel:GetFont()),
    Media.FontPath("Titillium Web SemiBold"))
Themes.Switch("FROST")
check("Frost: Baumname Julius", (header.Name:GetFont()), Media.FontPath("Julius Sans One"))
check("Frost: dunkle Flaeche", shade:IsShown(), true)
-- Reiter gezeigt: Blizzard legt die Koepfe neu an, einen Takt spaeter nachgezogen.
local newHeader = { Name = blizzard():CreateFontString(), Text = blizzard():CreateFontString(),
    MainRing = tex(), TextBackground = tex(), Divider = tex() }
frame.treeHeaders[2] = newHeader
M.timers = {}
frame._scriptHooks.OnShow()
for _, fn in ipairs(M.timers) do fn() end
check("neuer Baumkopf nach dem Zeigen: Julius", (newHeader.Name:GetFont()), Media.FontPath("Julius Sans One"))

print("\nKlassisch stellt alles her:")
Themes.Switch("CLASSIC")
check("Hintergrund zurueck", alpha(frame.Background), 1)
check("Klassenbild zurueck", alpha(frame.ClassBackground), 1)
check("pulsierendes Klassenbild ungetoent", list(frame.OverlayBackgroundMid._vertex), "1,1,1,1")
check("pulsierendes Klassenbild behaelt Deckkraft", alpha(frame.OverlayBackgroundMid), 0)
check("Trennlinie ungetoent", list(frame.DividerVerticalLeft._vertex), "1,1,1,1")
check("Trennlinie nicht entsaettigt", frame.DividerVerticalLeft:IsDesaturated(), false)
check("Kachel aus", back:IsShown(), false)
check("Flaeche aus", shade:IsShown(), false)
check("Baumname in Friz", (header.Name:GetFont()), FRIZ)
check("Aktiv in Friz", (frame.ActiveSpec.ActiveLabel:GetFont()), FRIZ)
check("Reiter ungetoent", list(tab.MiddleActive._vertex), "1,1,1,1")

print("\nSchalter aus unter einem Theme:")
Themes.Switch("TECH")
check("Tech: Baumname Space Grotesk", (header.Name:GetFont()), Media.FontPath("Space Grotesk"))
Skin.SetEnabled(false)
check("aus: gespeichert ohne Eintrag", ForeverThemesDB.skinTalents, nil)
check("aus: Hintergrund zurueck", alpha(frame.Background), 1)
check("aus: Baumname in Friz", (header.Name:GetFont()), FRIZ)
check("aus: Kachel aus", back:IsShown(), false)
M.timers = {}
frame._scriptHooks.OnShow()
for _, fn in ipairs(M.timers) do fn() end
check("aus: Zeigen aendert nichts", alpha(frame.Background), 1)
check("nie Anordnung an Blizzards Rahmen", layoutCalls, 0)

print("\nFallen:")
local h = assert(io.open(ADDONDIR .. "/Skins/Talents.lua")); local src = h:read("*a"); h:close()
src = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
check("kein hooksecurefunc", src:find("hooksecurefunc") == nil, true)
check("kein CreateFrame (Kinder eines Blizzard-Rahmens)", src:find("CreateFrame") == nil, true)
check("Schalter in allen Sprachen", ns.Locales.deDE.OPT_SKIN_TALENTS ~= nil and ns.Locales.esES.OPT_SKIN_TALENTS ~= nil
    and ns.Locales.frFR.OPT_SKIN_TALENTS ~= nil and ns.Locales.enUS.OPT_SKIN_TALENTS ~= nil, true)

print(("\n%d bestanden, %d fehlgeschlagen"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
