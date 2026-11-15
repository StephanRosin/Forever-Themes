--[[---------------------------------------------------------------------------
Skins/Skin.lua -- small helpers to show a Blizzard window in the central theme
(Themes.lua) without rebuilding it. Taken from the InfoPanel; needs only
Themes, Media, Border and Corners.

Looks only, never layout: Blizzard's parts are hidden through SetAlpha
(allowed in combat and on protected frames, and Blizzard's own Show/Hide
does not change the alpha), textures tinted, texts given a font. No point,
no size, no Show/Hide on Blizzard's frames. And never hooksecurefunc on
frame methods: in Forever that makes them nil for Blizzard's own code.

A record (Skin.NewRecord) remembers every original value on the first
change; Skin.Restore puts everything back (Classic, option off).

The own art (Skin.NewArt) draws on the window what the panel draws: theme
tile with the same tint (Media.ThemeBackground, LibForeverThemes' tint), dark
fill (stained glass, frost), title strip with gloss and line, band and
Pitwall wedge, ornaments and the ring inside along the edge (nothing reaches
beyond the window except the soft shadow).
-----------------------------------------------------------------------------]]

local ADDON, ns = ...

local Skin = {}
local Lib = LibForeverThemes
ns.Skin = Skin

local function weak() return setmetatable({}, { __mode = "k" }) end

function Skin.NewRecord()
    return { alpha = weak(), tint = weak(), font = weak() }
end

-- Textures of our own art: HideRegions leaves them alone.
local own = weak()

function Skin.Hide(rec, region)
    if not (region and region.SetAlpha) then return end
    if rec.alpha[region] == nil then rec.alpha[region] = region:GetAlpha() end
    region:SetAlpha(0)
end

-- Every texture of frame whose atlas is in atlases.
function Skin.HideAtlases(rec, frame, atlases)
    if not (frame and frame.GetRegions) then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if not own[region] and region.GetAtlas and atlases[region:GetAtlas() or ""] then Skin.Hide(rec, region) end
    end
end

-- c = { r, g, b[, a] }; desaturate: grey first, then tinted (Blizzard's
-- atlases are coloured).
function Skin.Tint(rec, tex, c, desaturate)
    if not (tex and tex.SetVertexColor) then return end
    if not rec.tint[tex] then
        local r, g, b, a = tex:GetVertexColor()
        rec.tint[tex] = { r or 1, g or 1, b or 1, a or 1, tex.IsDesaturated and tex:IsDesaturated() or false }
    end
    if tex.SetDesaturated then tex:SetDesaturated(desaturate == true) end
    tex:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
end

-- The outline Blizzard gave the text, as a text style flag (Media.ApplyText).
local function blizzardFlag(o)
    if o.flags:find("THICKOUTLINE") then return "THICKOUTLINE" end
    if o.flags:find("OUTLINE") then return "OUTLINE" end
    if o.shadow[1] ~= 0 or o.shadow[2] ~= 0 then return "SHADOW" end
    return ""
end

-- Font fontName (Media name) on Blizzard's text, at Blizzard's size.
-- flag nil: Blizzard's outline stays; color nil: the colour stays. Goes
-- through Media.ApplyText, which retries files used for the first time.
function Skin.Font(rec, fs, fontName, flag, color)
    if not (fs and fs.SetFont and fontName) then return end
    rec.font[fs] = rec.font[fs] or ns.Media.Snapshot(fs)
    local o = rec.font[fs]
    if not o.size then return end
    if not color then
        local r, g, b, a = fs:GetTextColor()
        color = { r or 1, g or 1, b or 1, a or 1 }
    end
    ns.Media.ApplyText(fs, { font = fontName, size = o.size, flag = flag or blizzardFlag(o), color = color })
end

function Skin.Restore(rec)
    for region, alpha in pairs(rec.alpha) do region:SetAlpha(alpha) end
    for tex, v in pairs(rec.tint) do
        if tex.SetDesaturated then tex:SetDesaturated(v[5]) end
        tex:SetVertexColor(v[1], v[2], v[3], v[4])
    end
    for fs, o in pairs(rec.font) do
        -- Stops pending Media.ApplyText retries.
        fs.fontWanted = nil
        ns.Media.Restore(fs, o, true)
    end
    rec.alpha, rec.tint, rec.font = weak(), weak(), weak()
end

-- Close button ------------------------------------------------------------------

-- A drawn cross as in the Group Finder (Header.CloseButton); hover mixed
-- halfway to white like the header icons.
local CROSS_SIZE, CROSS_WIDTH, HOVER_MIX = 14, 2, 0.5
local crosses = weak()

local function paintCross(cross)
    local c = cross.color
    if not c then return end
    if cross.hover then c = { c[1] + (1 - c[1]) * HOVER_MIX, c[2] + (1 - c[2]) * HOVER_MIX, c[3] + (1 - c[3]) * HOVER_MIX } end
    for _, line in ipairs(cross) do line:SetColorTexture(c[1], c[2], c[3], 1) end
end

-- Created once (at login, not in combat); hidden.
function Skin.NewCross(button)
    if not button or crosses[button] then return end
    local cross = {}
    for i, angle in ipairs({ math.pi / 4, -math.pi / 4 }) do
        local line = button:CreateTexture(nil, "OVERLAY")
        line:SetSize(CROSS_SIZE, CROSS_WIDTH)
        line:SetPoint("CENTER")
        if line.SetRotation then line:SetRotation(angle) end
        line:Hide()
        own[line] = true
        cross[i] = line
    end
    crosses[button] = cross
    if button.HookScript then
        button:HookScript("OnEnter", function() cross.hover = true; paintCross(cross) end)
        button:HookScript("OnLeave", function() cross.hover = false; paintCross(cross) end)
    end
end

-- Blizzard's button images off, the cross on in color (color nil: cross off).
function Skin.CloseButton(rec, button, color)
    local cross = button and crosses[button]
    if not cross then return end
    cross.color = color
    for _, line in ipairs(cross) do line:SetShown(color ~= nil) end
    if not color then return end
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
        if button[get] then Skin.Hide(rec, button[get](button)) end
    end
    paintCross(cross)
end

-- Window art ------------------------------------------------------------------

-- Above the content (Blizzard's children up to 520): the ring lies on the edge.
local OVER_LEVEL = 500
local ORNAMENT_SIZE = 12
local SHINE_ALPHA = 0.10
local DEFAULT_SHINE = { 1, 0.79, 0.19 }
local DEFAULT_LINE = { 0.78, 0.59, 0.13, 0.45 }

-- Our own texture on frame that HideAtlases leaves alone; hidden.
function Skin.OwnTexture(frame, layer, sublevel)
    local t = frame:CreateTexture(nil, layer, nil, sublevel)
    t:Hide()
    own[t] = true
    return t
end

local function texture(frame, sublevel) return Skin.OwnTexture(frame, "BACKGROUND", sublevel) end

-- The art for frame; titleHeight: height of Blizzard's title bar.
-- Below all of frame's children (our textures in BACKGROUND), the ring on
-- its own frame above them. Create at login, not in combat.
function Skin.NewArt(frame, titleHeight)
    local art = { frame = frame, titleHeight = titleHeight, clip = {} }
    art.back = texture(frame, -8)
    art.shade = texture(frame, -7)
    art.shine = texture(frame, -6)
    art.band = texture(frame, -5)
    art.line = texture(frame, -4)
    art.wedge = texture(frame, -3)
    art.over = CreateFrame("Frame", nil, frame)
    art.over:SetAllPoints(frame)
    art.over:SetFrameLevel(frame:GetFrameLevel() + OVER_LEVEL)
    art.box = art.over:CreateTexture(nil, "BACKGROUND")
    art.ornaments = {}
    for i = 1, 4 do
        art.ornaments[i] = art.over:CreateTexture(nil, "OVERLAY")
        art.ornaments[i]:Hide()
    end
    return art
end

local function placeOrnaments(art, look, extent)
    local wanted = {}
    for _, i in ipairs(look.ornament and look.corners or {}) do wanted[i] = true end
    local size, inset = look.ornamentSize or ORNAMENT_SIZE, (look.ornamentInset or 0) - extent
    local c = look.ornamentColor or { 1, 1, 1, 1 }
    for i, piece in ipairs(art.ornaments) do
        if wanted[i] then
            local point = ns.Corners.POINTS[i]
            piece:ClearAllPoints()
            piece:SetPoint(point, art.box, point, (i == 1 or i == 3) and inset or -inset, i <= 2 and -inset or inset)
            piece:SetSize(size, size)
            piece:SetTexture(Lib.Texture(look.ornament .. ".tga"))
            piece:SetTexCoord(unpack(ns.Corners.COORDS[i]))
            piece:SetVertexColor(c[1], c[2], c[3], c[4])
        end
        piece:SetShown(wanted[i] == true)
    end
end

-- The title strip: from the ring's inner edge to titleHeight below the top edge.
local function placeStrip(art, a, extent)
    local frame, h = art.frame, art.titleHeight
    local s = ns.Themes.Accent(a.shine or DEFAULT_SHINE)
    art.shine:ClearAllPoints()
    art.shine:SetPoint("TOPLEFT", art.box, "TOPLEFT")
    art.shine:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -extent, -h)
    art.shine:SetColorTexture(1, 1, 1, 1)
    art.shine:SetGradient("VERTICAL", CreateColor(s[1], s[2], s[3], 0), CreateColor(s[1], s[2], s[3], SHINE_ALPHA))
    art.shine:Show()
    local l = a.line or DEFAULT_LINE
    art.line:ClearAllPoints()
    art.line:SetPoint("TOPLEFT", frame, "TOPLEFT", extent, -h)
    art.line:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -extent, -h)
    art.line:SetHeight(1)
    art.line:SetColorTexture(l[1], l[2], l[3], l[4])
    art.line:Show()
    local band = a.band
    art.band:SetShown(band ~= nil)
    if band then
        art.band:ClearAllPoints()
        art.band:SetPoint("TOPLEFT", art.box, "TOPLEFT")
        art.band:SetPoint("TOPRIGHT", art.box, "TOPRIGHT")
        art.band:SetHeight(band.height or (h - extent))
        art.band:SetColorTexture(band.color[1], band.color[2], band.color[3], band.color[4])
    end
    art.wedge:SetShown(a.wedge ~= nil)
    if a.wedge then
        local c, size = ns.Themes.Wedge(a.wedgeColor), h - extent
        art.wedge:ClearAllPoints()
        art.wedge:SetPoint("TOPLEFT", art.box, "TOPLEFT")
        art.wedge:SetSize(size, size)
        art.wedge:SetTexture(Lib.Texture(a.wedge .. ".tga"))
        art.wedge:SetTexCoord(0, Lib.WEDGE_PART, 0, 1)
        art.wedge:SetVertexColor(c[1], c[2], c[3], c[4])
    end
end

local function placeShade(art, color, extent)
    art.shade:SetShown(color ~= nil)
    if not color then return end
    art.shade:ClearAllPoints()
    art.shade:SetPoint("TOPLEFT", art.frame, "TOPLEFT", extent, -art.titleHeight)
    art.shade:SetPoint("BOTTOMRIGHT", art.frame, "BOTTOMRIGHT", -extent, extent)
    art.shade:SetColorTexture(color[1], color[2], color[3], color[4])
end

-- The current theme (not Classic) on art: background, border and art like
-- the Forever addons' panels (Themes.SPECS[id].look/.art, colour from Themes.COLORS).
function Skin.PaintArt(art)
    local spec = ns.Themes.Spec(ns.Themes.Current())
    local look, a = spec.look, spec.art or {}
    local frame = art.frame
    local border = { style = look.borderStyle, size = look.borderSize,
        color = ns.Themes.Rim(look.borderColor or ns.Settings.DEFAULTS.borderColor),
        radius = 0, shadow = look.shadowEnabled, shadowSize = look.shadowSize or 0,
        shadowAlpha = (look.shadowAlpha or 0) / 100 }
    local extent = ns.Border.Extent(border)
    local w, h = frame:GetWidth(), frame:GetHeight()
    border.radius = ns.Corners.Clamp(look.cornerRadius or 0, w, h)
    art.box:ClearAllPoints()
    art.box:SetPoint("TOPLEFT", frame, "TOPLEFT", extent, -extent)
    art.box:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -extent, extent)
    art.back:SetAllPoints(frame)
    ns.Media.ThemeBackground(art.back, spec.art)
    art.back:Show()
    -- Like the panel: the rounding outside, concentric with the ring.
    ns.Corners.Fit(art.clip, frame, border.radius > 0 and ns.Corners.Clamp(border.radius + extent, w, h) or 0,
        { art.back, art.shine })
    ns.Border.Draw(art.over, art.box, border)
    placeShade(art, a.contentShade, extent)
    placeStrip(art, a, extent)
    placeOrnaments(art, a, extent)
end

local NO_BORDER = { style = "NONE", size = 0, radius = 0, shadow = false }

function Skin.HideArt(art)
    for _, key in ipairs({ "back", "shade", "shine", "band", "line", "wedge" }) do art[key]:Hide() end
    for _, piece in ipairs(art.ornaments) do piece:Hide() end
    ns.Corners.Fit(art.clip, art.frame, 0, { art.back, art.shine })
    ns.Border.Draw(art.over, art.box, NO_BORDER)
end
