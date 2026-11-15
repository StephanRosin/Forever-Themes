-- Blizzard's collections frame in the theme (Skins/Skin.lua, Skins/Collections.lua).
-- Own file so wowmock.lua stays untouched: the frame is rebuilt here
-- as far as the addon touches it (Shared/Blizzard_Collections.xml).
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

-- InsetFrameTemplate; tile: plus the tile of CollectionsBackgroundTemplate.
local function inset(tile)
    local f = blizzard()
    f.Bg, f.NineSlice = tex(), blizzard()
    f.BackgroundTile = tile and tex("collections-background-tile") or nil
    f.Shadow = tile and tex("collections-background-shadow-large", 0.6) or nil
    regions(f, tile and { f.Bg, f.BackgroundTile, f.Shadow } or { f.Bg })
    return f
end

-- The frame only exists once Blizzard_Collections loads (on demand).
local frame, closeTextures, tab
local function loadCollections()
    frame = blizzard("CollectionsJournal")
    frame._w, frame._h = 703, 606
    frame.NineSlice, frame.PortraitContainer = blizzard(), blizzard()
    frame.Bg, frame.TopTileStreaks = tex(), tex()
    frame.TitleContainer = blizzard()
    frame.TitleContainer.TitleText = frame.TitleContainer:CreateFontString()
    closeTextures = { tex(), tex(), tex(), tex() }
    frame.CloseButton = blizzard("CollectionsJournalCloseButton")
    function frame.CloseButton:GetNormalTexture() return closeTextures[1] end
    function frame.CloseButton:GetPushedTexture() return closeTextures[2] end
    function frame.CloseButton:GetHighlightTexture() return closeTextures[3] end
    function frame.CloseButton:GetDisabledTexture() return closeTextures[4] end
    tab = blizzard()
    tab.Background, tab.SelectedTexture, tab.TabGlow, tab.HighlightTexture = tex(), tex(), tex(), tex()
    frame.TabContainer = { Tabs = { tab } }

    local mount = blizzard("MountJournal")
    mount.LeftInset, mount.BottomLeftInset, mount.RightInset = inset(), inset(), inset()
    mount.MountCount = { Label = blizzard():CreateFontString(), Count = blizzard():CreateFontString() }
    local pet = blizzard("PetJournal")
    pet.LeftInset, pet.RightInset = inset(), inset()
    pet.PetCount = { Label = blizzard():CreateFontString(), Count = blizzard():CreateFontString() }
    blizzard("ToyBox").iconsFrame = inset(true)
    blizzard("HeirloomsJournal").iconsFrame = inset(true)
    local wardrobe = blizzard("WardrobeCollectionFrame")
    wardrobe.ItemsCollectionFrame = inset(true)
    wardrobe.SetsCollectionFrame = { LeftInset = inset(), RightInset = inset(true) }
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

local Themes, Skin, Media = ns.Themes, ns.CollectionsSkin, ns.Media
local FRIZ = "Fonts\\FRIZQT__.TTF"
local function alpha(region) return region:GetAlpha() end

print("\nLoad on demand:")
fire("PLAYER_LOGIN")
check("login without frame: nothing created", Skin.Parts(), nil)
loadCollections()
M.combat = true
fire("ADDON_LOADED", "Blizzard_Collections")
check("loaded in combat: waits", Skin.Parts(), nil)
fire("ADDON_LOADED", "Blizzard_Calendar")
M.combat = false
fire("PLAYER_REGEN_ENABLED")
local art = Skin.Parts()
check("created after combat", art ~= nil, true)
check("show hooked", frame._scriptHooks.OnShow ~= nil, true)
check("tab page hooked", _G.ToyBox._scriptHooks.OnShow ~= nil, true)
fire("ADDON_LOADED", "Blizzard_Collections")
check("second load creates nothing new", Skin.Parts(), art)

local panel = dofile("reference.lua")(ns)
local title = frame.TitleContainer.TitleText
local mountLabel, mountCount = _G.MountJournal.MountCount.Label, _G.MountJournal.MountCount.Count
local toys, sets = _G.ToyBox.iconsFrame, _G.WardrobeCollectionFrame.SetsCollectionFrame

print("\nSwitch off:")
check("off in a stored DB without it", Skin.Enabled(), false)
Themes.Switch("WOOD")
check("Wood without switch: NineSlice stays", alpha(frame.NineSlice), 1)
check("Wood without switch: no tile", art.back:IsShown(), false)
check("Wood without switch: title in Friz", (title:GetFont()), FRIZ)

print("\nSwitch on:")
layoutCalls = 0
Skin.SetEnabled(true)
check("saved account-wide", ForeverThemesDB.skinCollections, true)
check("tile visible", art.back:IsShown(), true)
check("NineSlice off", alpha(frame.NineSlice), 0)
check("portrait off", alpha(frame.PortraitContainer), 0)
check("rock tile off", alpha(frame.Bg), 0)
check("streaks under the title off", alpha(frame.TopTileStreaks), 0)
check("mounts: inset off", alpha(_G.MountJournal.LeftInset.Bg), 0)
check("mounts: inset border off", alpha(_G.MountJournal.RightInset.NineSlice), 0)
check("pets: inset off", alpha(_G.PetJournal.RightInset.Bg), 0)
check("toys: tile off", alpha(toys.BackgroundTile), 0)
check("toys: shadow off", alpha(toys.Shadow), 0)
check("heirlooms: tile off", alpha(_G.HeirloomsJournal.iconsFrame.BackgroundTile), 0)
check("appearances: tile off", alpha(_G.WardrobeCollectionFrame.ItemsCollectionFrame.BackgroundTile), 0)
check("appearance sets: inset off", alpha(sets.LeftInset.Bg), 0)
check("close: Blizzard's art off", alpha(closeTextures[1]), 0)
check("title: Cinzel", (title:GetFont()), Media.FontPath("Cinzel"))
check("counter: label stays Friz (bodyFont Friz)", (mountLabel:GetFont()), FRIZ)
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
check("Pitwall: counter label in the body font", (mountLabel:GetFont()), Media.FontPath("Titillium Web SemiBold"))
check("Pitwall: number untouched", (mountCount:GetFont()), FRIZ)
Themes.Switch("FROST")
check("Frost: title Julius", (title:GetFont()), Media.FontPath("Julius Sans One"))
check("Frost: no wedge", art.wedge:IsShown(), false)
check("Frost: dark shade", art.shade:IsShown(), true)
-- Tab change: Blizzard resets the title, reapplied one tick later.
title:SetTextColor(1, 1, 1, 1)
M.timers = {}
_G.PetJournal._scriptHooks.OnShow()
for _, fn in ipairs(M.timers) do fn() end
local accent = Themes.Accent(Themes.SPECS.FROST.look.headerColor)
check("tab shown: title back in the accent", list(title._textColor), list({ accent[1], accent[2], accent[3], 1 }))

print("\nClassic restores everything:")
Themes.Switch("CLASSIC")
check("NineSlice back", alpha(frame.NineSlice), 1)
check("rock tile back", alpha(frame.Bg), 1)
check("toys: shadow at its own alpha", alpha(toys.Shadow), 0.6)
check("mounts: inset back", alpha(_G.MountJournal.LeftInset.Bg), 1)
check("tile off", art.back:IsShown(), false)
check("wedge off", art.wedge:IsShown(), false)
check("title in Friz", (title:GetFont()), FRIZ)
check("counter label in Friz", (mountLabel:GetFont()), FRIZ)
check("tab no longer desaturated", tab.SelectedTexture:IsDesaturated(), false)
check("tab untinted", list(tab.SelectedTexture._vertex), "1,1,1,1")
check("close: Blizzard's art back", alpha(closeTextures[1]), 1)
check("ring gone", ns.Border.Pieces(art.over)[1]:IsShown(), false)

print("\nSwitch off under a theme:")
Themes.Switch("TECH")
check("Tech: title Space Grotesk", (title:GetFont()), Media.FontPath("Space Grotesk"))
Skin.SetEnabled(false)
check("off: saved without entry", ForeverThemesDB.skinCollections, nil)
check("off: NineSlice back", alpha(frame.NineSlice), 1)
check("off: title in Friz", (title:GetFont()), FRIZ)
check("off: tile off", art.back:IsShown(), false)
frame._scriptHooks.OnShow()
check("off: showing changes nothing", alpha(frame.NineSlice), 1)

print("\nTraps:")
local h = assert(io.open(ADDONDIR .. "/Skins/Collections.lua")); local src = h:read("*a"); h:close()
-- Comments do not count: they explain why it is missing.
src = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
check("no hooksecurefunc", src:find("hooksecurefunc") == nil, true)
check("switch in all languages",
    ns.Locales.deDE.OPT_SKIN_COLLECTIONS ~= nil and ns.Locales.esES.OPT_SKIN_COLLECTIONS ~= nil
    and ns.Locales.frFR.OPT_SKIN_COLLECTIONS ~= nil and ns.Locales.enUS.OPT_SKIN_COLLECTIONS ~= nil, true)

print(("\n%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
