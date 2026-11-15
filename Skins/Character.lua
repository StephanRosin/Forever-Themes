--[[---------------------------------------------------------------------------
Skins/Character.lua -- Blizzard's character window (CharacterFrame, Forever
1.60.1: Blizzard_UIPanels_Game/Camelot/CharacterFrame.xml) in the central
theme. Option "Theme Blizzard's character window" (options, under Blizzard's
windows), account-wide (default: Core.lua, Migrate.lua). Depends only on Skins/Skin.lua,
Themes and one line in Options.lua.

Themed:
  - Frame: NineSlice and portrait hidden; under them the theme tile, ring,
    title strip (gloss, line, band, Pitwall wedge), ornaments
    (Skin.PaintArt) -- background and tint like the Forever addons' panels per theme and colour.
  - Backgrounds of the left and right pane, stone header, class image and
    the insets of the stats, titles and equipment lists hidden; the divider
    between the panes in the theme's line colour.
  - Title in the theme font and header colour (accent); level line and stat
    labels in the text font (bodyFont; where that is Friz, Blizzard's stays;
    the level line then takes the title font).
  - Stat headers (item level, attributes ...) without Blizzard's band, title
    in the theme font and accent.
  - Close: the drawn cross in the icon colour.
  - Side tabs: tinted grey, selection and hover in the icon colour.
Blizzard's stays: 3D model and its background, equipment slots, the stats
pane's tabs, the content of reputation, skills, PvP, currency, statistics,
scroll bars, the numbers in the stats list.

Classic or option off: everything as Blizzard built it (Skin.Restore).

Refreshed on every show of the window and of a tab (one frame later:
Blizzard sets the title colour again afterwards), on every newly filled row
of the stats list (ScrollUtil callback, not a hook) and when theme, colour
or option change. Only textures, fonts, alpha: that may run in combat too.
Values are never read (Forever makes them secret).
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local Themes, Skin = ns.Themes, ns.Skin

local CharacterSkin = {}
ns.CharacterSkin = CharacterSkin

-- The left pane starts 20 below the top edge (LeftPaneHost, y = -20).
local TITLE_HEIGHT = 20
local TAB_TINT = { 0.3, 0.3, 0.3, 1 }
local BODY_FONT = "Friz Quadrata"
local DIVIDER_WIDTH = 1
-- Blizzard's fills behind the panes (CharacterFrame.xml, Camelot).
local PANE_ATLASES = { ["UI-Character-Info-General-BG"] = true, ["UI-Character-Info-Stat-BG"] = true,
    ["UI-Character-Info-Stat-StoneBG3"] = true }
local DIVIDER_ATLASES = { ["common-framedivider"] = true }
-- The pages CharacterFrame:ShowSubFrame shows (CharacterFrameConstants.lua).
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

-- ForeverThemesDB read directly: AccountDB() created it before ADDON_LOADED.
function CharacterSkin.Enabled()
    return _G.ForeverThemesDB ~= nil and _G.ForeverThemesDB.skinCharacter == true
end

local function active()
    return CharacterSkin.Enabled() and Themes.Current() ~= Themes.CLASSIC
end

-- Theme fonts only have Latin letters (LibForeverThemes.LatinClient).
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

-- A row of the stats list: header (Title) or stat (Label, Value).
local function skinStatRow(row)
    statRows[row] = true
    if not active() then return end
    local display, body = fonts()
    if row.Title then
        Skin.Hide(rec, row.Background)
        local flag, color = titleStyle()
        Skin.Font(rec, row.Title, display, flag, color)
    else
        -- Only the label: Media.ApplyText reads the text again later
        -- (GetText), and the value can be secret.
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
    -- The level line sits up by the heading: if the text font is Friz
    -- (Blizzard's own), it takes the title font, else it looks unthemed
    -- (like Themes.ForeignFont).
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

-- What is currently applied, so a settings notification (dragging the panel ...)
-- does not repaint every time.
local drawn
local function signature()
    if not active() then return "off" end
    return Themes.Current() .. "|" .. tostring(Themes.Color())
end

-- force: even if theme, colour and option have not changed
-- (window shown: Blizzard resets colours and images).
function CharacterSkin.Apply(force)
    local frame = _G.CharacterFrame
    if not (frame and art) then return end
    local now = signature()
    if now == drawn and not force then return end
    -- A different theme: back to Blizzard's state, then anew (fonts without a theme font ...).
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

-- Tabs: Blizzard sets the title colour after showing (RefreshDisplay),
-- hence one frame later.
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

-- At login: create our own parts (not only once in combat) and hook in.
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

-- For the tests: our own art and the divider.
function CharacterSkin.Parts() return art, divider end

ns.On("PLAYER_LOGIN", CharacterSkin.Setup)
-- Currency and statistics can load later.
ns.On("ADDON_LOADED", function() if art then hookSubframes() end end)
ns.Settings.OnChange(function() CharacterSkin.Apply() end)
