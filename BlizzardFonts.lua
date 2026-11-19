local ADDON, ns = ...

-- "Theme font for Blizzard texts" (ForeverThemesDB.blizzardTexts, from Forever
-- Unit Frames' Core/BlizzardFonts.lua): some of Blizzard's texts take the
-- central theme's font (Themes.Font, as Unit Frames chose it), each keeping
-- its size and outline.
-- Only these, one FontString each (their font objects, GameFontNormalSmall
-- or NumberFontNormal, also carry tooltips, quest and chat text): the
-- player's cast bar (Text, CastTimeText), the duration and count of the buff
-- and debuff icons, the Cooldown Manager's numbers (countdown, charges,
-- stacks, the buff bars' duration), the red error line (UIErrorsFrame) and
-- the floating combat text (font object CombatTextFont, only Blizzard_CombatText
-- uses it; each new line takes it again, sizes come from SetTextHeight), the
-- swing timers' labels (SwingTimerMainHand/OffHand/RangedFrame), the breath,
-- fatigue and feign-death bars (MirrorTimerContainer.mirrorTimers[i].Text) and,
-- with Baganator, the texts on its bag slots (stack count, corner widgets
-- such as item level) and its category headers, reached through its skin API
-- (Baganator.API.Skins), and the action buttons' key binding, count and macro
-- name (Blizzard's bars and Bartender4's).
-- The first change remembers each text's font for the session; Classic or
-- the switch off puts it back.
--
-- While this addon is loaded it owns these texts (LibForeverThemes.Hub();
-- the Unit Frames' and InfoPanel's bridges stand down).
--
-- No hooksecurefunc on a frame (in Forever it breaks Blizzard's own
-- code): the cast bar sets its font again in SetLook, hence
-- HookScript("OnShow"); the Cooldown Manager builds new icons, hence
-- Blizzard's EventRegistry message "CooldownViewerSettings.OnDataChanged";
-- and every loading screen. The client reads the damage numbers' font
-- (DAMAGE_TEXT_FONT) at login only: ForeverThemesDB.damageFont keeps the
-- font for the next one, set at ADDON_LOADED.
local BlizzardFonts = {}
ns.BlizzardFonts = BlizzardFonts
local COOLDOWN_VIEWERS = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer",
    "BuffBarCooldownViewer" }
local AURA_FRAMES = { "BuffFrame", "DebuffFrame" }
local SWING_TIMERS = { "SwingTimerMainHandFrame", "SwingTimerOffHandFrame", "SwingTimerRangedFrame" }
-- Action buttons (key binding, count, macro name): Blizzard's bars and
-- Bartender4's (BT4Button1..180, LibActionButton keeps these regions).
local ACTION_BARS = { ActionButton = 12, MultiBarBottomLeftButton = 12, MultiBarBottomRightButton = 12,
    MultiBarRightButton = 12, MultiBarLeftButton = 12, MultiBar5Button = 12, MultiBar6Button = 12,
    MultiBar7Button = 12, PetActionButton = 10, StanceButton = 10, BT4Button = 180, BT4PetButton = 10,
    BT4StanceButton = 10 }

-- FontString (or MessageFrame) -> its font before the first change.
local originals = setmetatable({}, { __mode = "k" })

local function add(list, fs)
    if type(fs) == "table" and fs.GetFont and fs.SetFont then list[#list + 1] = fs end
end

-- A Baganator region's texts: an item slot's stack count, a corner widget
-- that is a text itself (item level and the like; icons are textures), a
-- category's label and section header (buttons with a text).
local function bagTexts(list, details)
    local region, kind = details.region, details.regionType
    if kind == "ItemButton" then add(list, region.Count)
    elseif kind == "CornerWidget" then add(list, region)
    elseif (kind == "CategoryLabel" or kind == "CategorySectionHeader") and region.GetFontString then
        add(list, region:GetFontString())
    end
end

local function castBarTexts(list)
    local bar = _G.PlayerCastingBarFrame
    if bar then add(list, bar.Text); add(list, bar.CastTimeText) end
end

-- Every text there is right now.
function BlizzardFonts.Targets()
    local list = {}
    castBarTexts(list)
    for _, name in ipairs(AURA_FRAMES) do
        local frame = _G[name]
        for _, button in ipairs(frame and frame.auraFrames or {}) do
            add(list, button.Duration)
            add(list, button.Count)
        end
    end
    for _, name in ipairs(COOLDOWN_VIEWERS) do
        local viewer = _G[name]
        for _, item in ipairs(viewer and { viewer:GetChildren() } or {}) do
            local cd = item.Cooldown
            if cd and cd.GetCountdownFontString then add(list, cd:GetCountdownFontString()) end
            add(list, item.ChargeCount and item.ChargeCount.Current)
            add(list, item.Applications and item.Applications.Applications)
            add(list, item.Icon and item.Icon.Applications)
            add(list, item.Bar and item.Bar.Duration)
        end
    end
    for _, name in ipairs(SWING_TIMERS) do
        local bar = _G[name] and _G[name].StatusBar
        if bar then add(list, bar.TypeLabel); add(list, bar.TimeLabel) end
    end
    for prefix, count in pairs(ACTION_BARS) do
        for i = 1, count do
            local button = _G[prefix .. i]
            if button then add(list, button.HotKey); add(list, button.Count); add(list, button.Name) end
        end
    end
    local mirror = _G.MirrorTimerContainer
    for _, timer in ipairs(mirror and mirror.mirrorTimers or {}) do add(list, timer.Text) end
    local skins = _G.Baganator and Baganator.API and Baganator.API.Skins
    for _, details in ipairs(skins and skins.GetAllFrames and skins.GetAllFrames() or {}) do bagTexts(list, details) end
    add(list, _G.UIErrorsFrame)
    add(list, _G.CombatTextFont)
    return list
end

-- Whether the client refused path on any shown text (a file used for the
-- first time, e.g. Bungee or Alegreya, can be); those keep their font until
-- then. A hidden text never loads a new file (Media.lua): it gets the font at
-- the next refresh, not a retry of its own.
local function setFont(list, path)
    local refused = false
    for _, fs in ipairs(list) do
        local file, size, flags = fs:GetFont()
        if file ~= path and size then
            originals[fs] = originals[fs] or { object = fs:GetFontObject(), file = file, size = size, flags = flags }
            fs:SetFont(path, size, flags)
            if fs.IsVisible and fs:IsVisible() and not ns.Media.HasFont(fs, path) then refused = true end
        end
    end
    return refused
end

local function restoreAll()
    for fs, o in pairs(originals) do
        fs:SetFont(o.file, o.size, o.flags)
        -- Only a FontString: the error line, a MessageFrame, errors on any
        -- SetFontObject back ("font object loop"); SetFont restored it.
        if o.object and fs:GetObjectType() == "FontString" then fs:SetFontObject(o.object) end
        originals[fs] = nil
    end
end

function BlizzardFonts.Enabled() return ns.AccountDB().blizzardTexts == true end

function BlizzardFonts.SetEnabled(on)
    ns.AccountDB().blizzardTexts = on and true or nil
    BlizzardFonts.Refresh()
end

-- The theme font's name while the switch is on, else nil.
local function wanted()
    return BlizzardFonts.Enabled() and ns.Themes.Font() or nil
end

-- A refused font is set again a little later, as the skins do (Media.lua):
-- else the texts kept the client's font until the next loading screen.
local RETRY_DELAY, RETRIES = 0.25, 40
local retry = { pending = false, left = RETRIES }

local function retryLater()
    if retry.pending or retry.left <= 0 then return end
    retry.pending, retry.left = true, retry.left - 1
    C_Timer.After(RETRY_DELAY, function()
        retry.pending = false
        BlizzardFonts.Refresh()
    end)
end

local function applyTo(list, font)
    local path = ns.Media.FontPath(font)
    if not setFont(list, path) then retry.left = RETRIES; return end
    if retry.left > 0 then retryLater(); return end
    -- Given up: said once, as the skins say it (Media.lua).
    if not retry.told then retry.told = true; ns.Print(ns.L.FONT_REFUSED, path) end
end

-- After a settings change, a theme switch, a loading screen.
function BlizzardFonts.Refresh()
    local font = wanted()
    ns.AccountDB().damageFont = font
    if font then applyTo(BlizzardFonts.Targets(), font) else restoreAll() end
end

local function hookCastBar()
    local bar = _G.PlayerCastingBarFrame
    if not bar or not bar.HookScript then return end
    bar:HookScript("OnShow", function()
        local font = wanted()
        if font then
            local list = {}
            castBarTexts(list)
            applyTo(list, font)
        end
    end)
end

ns.On("ADDON_LOADED", function(_, name)
    local font = name == ADDON and ForeverThemesDB and ForeverThemesDB.damageFont
    if font then _G.DAMAGE_TEXT_FONT = ns.Media.FontPath(font) end
end)

-- Baganator makes slots as bags open: each new one takes the font at once.
local function hookBaganator()
    local skins = _G.Baganator and Baganator.API and Baganator.API.Skins
    if not (skins and skins.RegisterListener) then return end
    skins.RegisterListener(function(details)
        local font = wanted()
        if font then
            local list = {}
            bagTexts(list, details)
            applyTo(list, font)
        end
    end)
end

ns.On("PLAYER_LOGIN", function()
    hookCastBar()
    hookBaganator()
    if _G.EventRegistry then
        -- A moment later: the Cooldown Manager builds its icons first.
        EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", function()
            C_Timer.After(0, BlizzardFonts.Refresh)
        end, BlizzardFonts)
    end
    BlizzardFonts.Refresh()
    local font = wanted()
    if font then _G.DAMAGE_TEXT_FONT = ns.Media.FontPath(font) end
end)
ns.Settings.OnChange(function() BlizzardFonts.Refresh() end)
-- A hidden text does not load a new font file (LibForeverThemes loads ours
-- while the addon loads); each loading screen also brings new buttons.
ns.On("PLAYER_ENTERING_WORLD", function()
    BlizzardFonts.Refresh()
end)
