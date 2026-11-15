--[[---------------------------------------------------------------------------
Skins/Communities.lua -- Blizzard's "Guild & Communities" window
(CommunitiesFrame, Forever 1.60.1: Blizzard_Communities/CommunitiesFrame.xml,
loads on demand) in the central theme. The menu entry and the key open it
through ToggleGuildFrame -> ToggleCommunitiesFrame (Camelot uses
Mainline/Game.lua); FriendsFrame has no guild tab here. Option
"Theme Blizzard's guild & communities window" (options, Blizzard's windows),
account-wide, off by default. Built like Skins/Character.lua.

Themed:
  - Frame: NineSlice, portrait with crest (PortraitOverlay), rock tile,
    streaks under the title and the inset hidden; under them the theme tile,
    ring, title strip, Pitwall wedge, ornaments
    (Skin.PaintArt) -- like the Forever addons' panels per theme and colour.
  - Left list (communities): Blizzard's blue fill and ornate edge hidden.
  - Guild info: parchment and header bands hidden, the headings in the theme
    font and accent (like the stat headers in the character window).
  - Title in the theme font and accent; labels ("Show offline",
    "Guild reputation:") in the text font (Friz stays).
  - Close: the drawn cross in the icon colour.
  - Side tabs on the right: frame grey, selection and hover in the icon colour.
Blizzard's stays: chat and input line, member list with its columns, news,
perks, guild finder, scroll bars, dropdowns, the maximize/minimize button,
the frames around chat and lists.

Classic or option off: everything as Blizzard built it (Skin.Restore).

Refreshed on every show, on every resize (minimizing switches 814x426 <->
322x406, the rounding depends on the size) and when theme, colour or option
change. Only textures, fonts, alpha. Chat and guild texts (MOTD, info text,
names) are never touched: they can be secret, and Media.ApplyText reads text
again. CommunitiesFrame is not protected: our own parts may be created even
when Blizzard_Communities only loads in combat.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local Themes, Skin = ns.Themes, ns.Skin

local CommunitiesSkin = {}
ns.CommunitiesSkin = CommunitiesSkin

local BLIZZARD_ADDON = "Blizzard_Communities"
-- Rock tile and streaks start 21 below the top edge (ButtonFrameBaseTemplate).
local TITLE_HEIGHT = 21
local TAB_TINT = { 0.3, 0.3, 0.3, 1 }
local BODY_FONT = "Friz Quadrata"
-- The side tabs (CommunitiesFrameTabTemplate -> RightSideTabTemplate).
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

-- As in Character.lua (candidate for Skin.lua): title font, text font unless Friz.
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

-- Guild info (CommunitiesGuildInfoFrameTemplate): parchment, header bands and
-- crest background sit in BACKGROUND, the headings are the layer's own font
-- strings (MOTD and info text are children, so not included).
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
            -- The tab frame (SpellBook-SkillLineTab) is the sole texture in BORDER.
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

-- force: even if theme, colour, option are unchanged (show, new size).
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

-- At login or when Blizzard_Communities loads later: create our own parts.
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

-- For the tests: our own art.
function CommunitiesSkin.Parts() return art end

-- Loads Blizzard_Communities before login, sets up on PLAYER_LOGIN (themes ready).
local loggedIn = false
ns.On("PLAYER_LOGIN", function() loggedIn = true; CommunitiesSkin.Setup() end)
ns.On("ADDON_LOADED", function(_, name) if name == BLIZZARD_ADDON and loggedIn then CommunitiesSkin.Setup() end end)
ns.Settings.OnChange(function() CommunitiesSkin.Apply() end)
