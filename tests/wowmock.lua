-- WoW API mock (from the InfoPanel), just enough for the tests. Lua 5.1, as in the game.
local M = { frames = {}, byName = {}, chat = {}, hidden = {}, placed = {},
            reparented = {}, timers = {},
            fontStrings = {}, labelText = {}, anchors = {}, anchorXY = {}, scrollChild = {},
            strata = {}, level = {}, mouse = {} }

local widget = {}
widget.__index = function(t, k)
    -- Only CamelCase keys are WoW widget methods. Everything else is addon
    -- data and must return nil as in the game, or the mock hides real
    -- state (e.g. "dragging").
    if type(k) ~= "string" or not k:match("^%u") then return nil end
    local f = function() end
    rawset(t, k, f)
    return f
end

local function newWidget(name)
    local w = setmetatable({ _name = name, _scripts = {}, _events = {},
                             _w = 140, _h = 140, _shown = true }, widget)
    function w:GetName()  return self._name end
    function w:SetScript(s, fn) self._scripts[s] = fn end
    function w:SetText(t) self._text = t end
    function w:GetText() return self._text end
    function w:GetStringWidth() return #(self._text or '') * 6 end
    function w:GetStringHeight() return 12 end
    function w:SetValue(v) self._value = v end
    function w:GetValue() return self._value end
    function w:SetChecked(v) self._checked = not not v end
    function w:SetScrollChild(c) self._scrollChild = c; M.scrollChild[self._name or self] = c end
    function w:GetVerticalScroll() return self._scroll or 0 end
    function w:SetVerticalScroll(v) self._scroll = v end
    function w:GetVerticalScrollRange() return 400 end
    function w:GetChecked() return self._checked end
    function w:GetScript(s)     return self._scripts[s] end
    function w:SetAttribute(k, v) self._attr = self._attr or {}; self._attr[k] = v end
    function w:GetAttribute(k)    return self._attr and self._attr[k] end
    function w:RegisterForClicks(...) self._clicks = { ... } end
    function w:GetParent()        return self._parent end
    function w:SetSize(a, b)    self._w, self._h = a, b end
    function w:SetHeight(v)     self._h = v end
    function w:SetWidth(v)      self._w = v end
    function w:GetWidth()       return self._w end
    function w:GetHeight()      return self._h end
    -- Screen rectangle: tests set _rect = { left, bottom, width, height }.
    function w:GetCenter() local r = self._rect; if r then return r[1] + r[3] / 2, r[2] + r[4] / 2 end end
    function w:GetTop() local r = self._rect; return r and (r[2] + r[4]) end
    function w:GetBottom() local r = self._rect; return r and r[2] end
    function w:StartMoving() end
    function w:StopMovingOrSizing() end
    function w:Hide()  self._shown = false; M.hidden[self._name or self] = true end
    function w:Show()  self._shown = true end
    function w:IsShown() return self._shown end
    function w:SetShown(v) self._shown = not not v end
    function w:IsMouseOver() return self._mouseOver == true end
    -- Looks (1.6): textures, colours, masks and shadows are recorded
    -- so the tests can check them.
    function w:SetTexture(t) self._texture = t end
    function w:GetTexture() return self._texture end
    function w:SetTexCoord(...) self._texCoord = { ... } end
    function w:SetHorizTile(v) self._horizTile = v == true end
    function w:GetHorizTile() return self._horizTile == true end
    function w:SetVertTile(v) self._vertTile = v == true end
    function w:GetVertTile() return self._vertTile == true end
    function w:SetColorTexture(r, g, b, a) self._colorTexture = { r, g, b, a } ; self._texture = nil end
    function w:SetVertexColor(r, g, b, a) self._vertex = { r, g, b, a } end
    function w:SetDesaturation(v) self._desat = v end
    function w:SetGradient(o, from, to) self._gradient = { o, from, to } end
    function w:SetTextColor(r, g, b, a) self._textColor = { r, g, b, a } end
    function w:SetShadowOffset(x, y) self._shadowOffset = { x, y } end
    function w:SetShadowColor(r, g, b, a) self._shadowColor = { r, g, b, a } end
    function w:SetTextureSliceMargins(l, t, r, b) self._slice = { l, t, r, b } end
    function w:AddMaskTexture(m) self._masks = self._masks or {}; self._masks[m] = true end
    function w:RemoveMaskTexture(m) if self._masks then self._masks[m] = nil end end
    function w:SetAlpha(a) self._alpha = a end
    function w:GetAlpha() return self._alpha or 1 end
    function w:SetScale(s) self._scale = s end
    function w:GetScale() return self._scale or 1 end
    function w:GetEffectiveScale() return 1 end
    function w:GetFrameLevel() return 3 end
    function w:CreateTexture() return newWidget() end
    function w:CreateMaskTexture() return newWidget() end
    function w:CreateFontString()
        local fs = newWidget()
        M.fontStrings[#M.fontStrings + 1] = fs
        function fs:SetText(t) self._text = t; M.labelText[self] = t end
        -- Font: without these two, applying a font does nothing at all,
        -- and a test of it would be worthless.
        fs._font = { "Fonts\\FRIZQT__.TTF", 10, "" }
        function fs:GetFont() return self._font[1], self._font[2], self._font[3] end
        function fs:SetFont(path, size, flags)
            self._font = { path, size, flags }
            return true
        end
        function fs:SetPoint(p, rel, p2, x, y)
            if type(rel) == "number" then x, y = rel, p2 end
            M.placed[self] = { p, x, y }
        end
        return fs
    end
    function w:RegisterEvent(e) self._events[e] = true end
    function w:SetPoint(p, rel, p2, x, y)
        -- SetPoint has several signatures. The short form (point, x, y) has
        -- a number in second place instead of a relative frame.
        if type(rel) == "number" then x, y, rel, p2 = rel, p2, nil, nil end
        M.placed[self._name or self] = { p, x, y, rel and rel.GetName and rel:GetName() }
        local key = self._name or self
        M.anchors[key] = M.anchors[key] or {}
        M.anchors[key][p] = rel and rel.GetName and rel:GetName()
        -- Record offsets PER anchor point: a frame can have several, and
        -- M.placed only holds the last one set.
        M.anchorXY[key] = M.anchorXY[key] or {}
        M.anchorXY[key][p] = { x, y }
    end
    function w:ClearAllPoints() M.anchors[self._name or self] = nil end
    function w:SetFrameStrata(v) M.strata[self._name or self] = v end
    function w:GetFrameStrata()  return M.strata[self._name or self] or "MEDIUM" end
    function w:SetFrameLevel(v)  M.level[self._name or self] = v end
    function w:EnableMouse(v)    M.mouse[self._name or self] = v end
    function w:SetParent(parent)
        M.reparented[self._name or self] = parent and parent.GetName and parent:GetName()
    end
    return w
end
M.newWidget = newWidget

function CreateFrame(frameType, name, parent, template)
    local f = newWidget(name)
    f._type, f._parent, f._template = frameType, parent, template
    table.insert(M.frames, f)
    if name then M.byName[name] = f end
    return f
end

UIParent = newWidget("UIParent")
function UIParent:GetRight() return 1920 end
function UIParent:GetWidth() return 1920 end

-- Colours as a table like ColorMixin (only the fields that are read).
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
function UIParent:GetHeight() return 1080 end

M.registered = {}
InterfaceOptions_AddCategory = function(panel)
    M.registered[#M.registered + 1] = panel.name
end
-- Settings deliberately NOT defined: this tests the fallback path.

Minimap = newWidget("Minimap")
M.minimapRight, M.minimapTop = 1900, 800
function Minimap:GetRight() return M.minimapRight end
function Minimap:GetTop()   return M.minimapTop end
function Minimap:GetLeft()  return M.minimapRight - self._w end
function Minimap:GetZoom()  return 3 end
function Minimap:SetZoom(z) end
function Minimap:GetZoomLevels() return 6 end
for _, n in ipairs({ "MinimapCluster","MinimapBackdrop","MinimapBorder","MinimapNorthTag",
                     "MinimapZoomIn","MinimapZoomOut","MiniMapTracking","MiniMapMailFrame",
                     "MiniMapBattlefieldFrame","GameTimeFrame","MinimapToggleButton",
                     "MinimapZoneTextButton","TimeManagerClockButton","MiniMapInstanceDifficulty",
                     "MiniMapWorldMapButton" }) do
    local f = newWidget(n); f._w, f._h = 32, 32; _G[n] = f
end
function GetMinimapZoneText() return "Gadgetzan" end
function GetGameTime() return 21, 7 end
function date(f) return "21:07" end
LibStub = function(n) if n == "LibDBIcon-1.0" then return { radius = 5, SetButtonRadius = function() end } end end

-- Chat frames and tabs as in the game: ten frames, two of them open.
NUM_CHAT_WINDOWS = 10
M.tabAlpha = {}
for i = 1, 12 do
    local frame = newWidget("ChatFrame" .. i)
    frame._w, frame._h = 430, 180
    function frame:GetLeft() return 20 end
    local tab = newWidget("ChatFrame" .. i .. "Tab")
    tab._shown, tab._h = (i <= 2), 24
    function tab:SetAlpha(v) M.tabAlpha[self._name] = v end
    _G["ChatFrame" .. i]          = frame
    _G["ChatFrame" .. i .. "Tab"] = tab
end

M.updateAlphaCalls = 0
function FCFTab_UpdateAlpha(frame) M.updateAlphaCalls = M.updateAlphaCalls + 1 end
M.hooks = {}
function hooksecurefunc(name, fn) M.hooks[name] = fn end
-- Screen 1920 wide; the map ends at 2020-... see M.minimapRight.
function UIParent:GetRight() return 1920 end
function UIParent:GetHeight() return 1080 end
StaticPopupDialogs = {}
function StaticPopup_Show(which) M.popup = which end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) table.insert(M.chat, m) end }
SlashCmdList = {}
function GetLocale() return M.locale or "deDE" end
UISpecialFrames = {}
GameTooltip = newWidget("GameTooltip")
M.tooltip = {}
function GameTooltip:SetOwner(o) M.tooltip = { owner = o } end
function GameTooltip:AddLine(t) M.tooltip[#M.tooltip + 1] = t end
function GameTooltip:Show() M.tooltip.shown = true end
function GameTooltip:Hide() M.tooltip.shown = false end
function GetInventoryItemLink(unit, slot) return "[Testitem" .. slot .. "]" end

C_Timer = { After = function(_, fn) table.insert(M.timers, fn) end }

M.state = { ctrl = false, mouseDown = false, cursor = {0, 0}, zoom = 3 }
function GetMinimapZoneText() return "Gadgetzan" end
function GetZoneText()        return "Tanaris" end
function GetGameTime()        return 21, 7 end
function date(fmt)            return "21:07" end

function IsControlKeyDown()  return M.state.ctrl end
function IsMouseButtonDown() return M.state.mouseDown end
function GetCursorPosition() return M.state.cursor[1], M.state.cursor[2] end

-- The minimap: record size, position from a fixed top-right corner
Minimap = newWidget("Minimap")
M.minimapRight, M.minimapTop = 1900, 800
function Minimap:GetRight() return M.minimapRight end
function Minimap:GetTop()   return M.minimapTop end
function Minimap:GetZoom()  return M.state.zoom end
function Minimap:SetZoom(z) M.state.zoom = z; M.zoomCalls = (M.zoomCalls or 0) + 1 end
function Minimap:GetZoomLevels() return 6 end

-- Blizzard frames the addon touches
-- Heights differ as in the game: GameTimeFrame (day/night) is larger.
-- Sizes as measured in the real dump.
local blizzHeights = {
    MinimapBorder = 192, MinimapNorthTag = 16, MinimapZoomIn = 32, MinimapZoomOut = 32,
    MiniMapTracking = 32, MiniMapMailFrame = 33, MiniMapBattlefieldFrame = 33,
    GameTimeFrame = 50, MinimapBackdrop = 192, MinimapToggleButton = 32,
    MinimapZoneTextButton = 12, TimeManagerClockButton = 28,
    MiniMapInstanceDifficulty = 46, MiniMapWorldMapButton = 33,
    MinimapCluster = 165,
}
-- Widths also from the dump: 32/33/33/50 -- the size difference is
-- exactly why the column is aligned by centre points.
local blizzWidths = {
    MinimapBorder = 192, MinimapNorthTag = 16, MinimapZoomIn = 32, MinimapZoomOut = 32,
    MiniMapTracking = 32, MiniMapMailFrame = 33, MiniMapBattlefieldFrame = 33,
    GameTimeFrame = 50, MinimapBackdrop = 192, MinimapToggleButton = 32,
    MinimapZoneTextButton = 140, TimeManagerClockButton = 60,
    MiniMapInstanceDifficulty = 38, MiniMapWorldMapButton = 33,
    MinimapCluster = 177,
}
-- Mail and battlefield are normally OFF -- that is exactly what the
-- gap bug in the column was about.
local blizzHidden = { MiniMapMailFrame = true, MiniMapBattlefieldFrame = true }
for n, h in pairs(blizzHeights) do
    local f = newWidget(n)
    f._h = h
    f._w = blizzWidths[n] or h
    f._shown = not blizzHidden[n]
    _G[n] = f
end
-- MiniMapWorldMapButton and MinimapBorderTop stay nil on purpose,
-- so the addon's guard is tested.

-- LibDBIcon
M.iconRefreshes = 0
local dbicon = { radius = 5 }
function dbicon:SetButtonRadius(r) self.radius = r; M.iconRefreshes = M.iconRefreshes + 1 end
LibStub = function(name) if name == "LibDBIcon-1.0" then return dbicon end end

-- Additional game APIs the addons need at login.
function UnitClass()  return "Warlock", "WARLOCK" end
function UnitRace()   return "Human", "Human" end
function UnitName()   return "Testchar" end
function UnitLevel()  return 43 end
function UnitExists() return false end
function UnitFactionGroup() return "Alliance" end

-- WoW Forever tracks honour as a PvP rank via C_MajorFactions, faction
-- 2800, and takes the rank title from the global strings. See
-- Blizzard_UIPanels_Game/Camelot/PVPRankFrame.lua in the forever branch.
M.state.rang = nil        -- nil means: this client does not know it
M.state.rangTexte = {
    -- Keys as in the original: PVP_RANK_<enum value>_<0 Horde | 1 Alliance>
    ["PVP_RANK_6_1"] = "Sergeant",
}
PVP_RANK_0_NAME = "Ohne Rang"
Enum = Enum or {}
Enum.PvPRanks = { Rank_1 = 5 }
Enum.UITextureSliceMode = { Stretched = 0, Tiled = 1 }
function UnitSex() return 2 end
function GetText(key) return M.state.rangTexte[key] or key end
C_MajorFactions = {
    GetMajorFactionProgressionInfo = function(id)
        if id ~= 2800 then return nil end
        return M.state.rang
    end,
}
function UnitCreatureFamily() return nil end
function GetRealmName() return "Testrealm" end
-- Four returns as in the game: version, build, date, interface number.
M.build = { "1.60.1", "70374", "Oct 1 2026", 16001 }
function GetBuildInfo() return M.build[1], M.build[2], M.build[3], M.build[4] end
function GetNumSpellTabs() return 0 end
function GetSpellTabInfo() return nil end
function GetSpellBookItemName() return nil end
function GetQuestsCompleted() return {} end
function GetNumQuestLogEntries() return 0 end
function GetQuestLogTitle() return nil end
function GetItemCount() return 0 end
function IsUsableSpell() return true, false end
function GetSpellCooldown() return 0, 0 end
function GetSpellTexture(s) return "TEX:" .. tostring(s) end
-- M.combat: in combat (tests that check protected frames).
function InCombatLockdown() return M.combat == true end
function ClearOverrideBindings() end
function SetOverrideBindingClick() end
C_EventUtils = { IsEventValid = function() return true end }
BOOKTYPE_SPELL = "spell"
function wipe(t) for k in pairs(t) do t[k] = nil end return t end

-- Game state for the InfoPanel
M.state = M.state or {}
M.state.items = { [6265] = 7, [20559] = 42 }
M.state.honor = nil             -- deliberately unavailable
function GetItemCount(id) return M.state.items[id] or 0 end
function GetItemIcon(id) return M.state.items[id] and ("ICON:" .. id) or nil end

-- Honour is a currency, not a bag token.
Constants = { CurrencyConsts = { HONOR_CURRENCY_ID = 1792 } }
M.state.currency = {
    [1792] = { quantity = 1350, iconFileID = "ICON:honor", name = "Honor" },
}
-- Currency frame: list of { name, currencyID?, isHeader? }; otherwise the
-- ID comes via a link as in the game.
M.state.currencyList = {}
HONOR = "Ehre"
C_CurrencyInfo = {
    GetCurrencyInfo = function(id) return M.state.currency[id] end,
    GetCurrencyListSize = function() return #M.state.currencyList end,
    GetCurrencyListInfo = function(i)
        local e = M.state.currencyList[i]
        return e and { name = e.name, isHeader = e.isHeader } or nil
    end,
    GetCurrencyListLink = function(i)
        local e = M.state.currencyList[i]
        return e and e.id and ("|Hcurrency:" .. e.id .. "|h") or nil
    end,
    GetCurrencyIDFromLink = function(link)
        return tonumber(link:match("currency:(%d+)"))
    end,
}
function GetItemInfo(id)
    if id == 6948 then return "Hearthstone" end   -- English client
    return M.state.items[id] and ("Item" .. id) or nil
end
function GetItemIcon(id) return "ICON:" .. tostring(id) end
function GetBindLocation() return "Ironforge" end
function GetTime() return M.state.now or 0 end

-- Hearthstone cooldown, set by the tests.
M.state.now = 10000
M.state.cooldowns = {}
-- Forever: items and bags only under C_Item / C_Container.
C_Item = {
    GetItemCount = function(id) return GetItemCount(id) end,
    GetItemInfo = function(id) return GetItemInfo(id) end,
    GetItemIconByID = function(id) return GetItemIcon(id) end,
    GetItemInfoInstant = function(id) return M.state.instant and M.state.instant[id] end,
}
C_Container = C_Container or {}
M.state.bags = {}
function C_Container.GetContainerNumSlots(bag) return #(M.state.bags[bag] or {}) end
function C_Container.GetContainerItemID(bag, slot) return (M.state.bags[bag] or {})[slot] end
function C_Container.GetItemCooldown(id)
    local cd = M.state.cooldowns[id]
    if not cd then return 0, 0, 1 end
    return cd[1], cd[2], 1
end
function UIParent_GetHeight() return 1080 end
bit = { band = function() return 0 end }

return M
