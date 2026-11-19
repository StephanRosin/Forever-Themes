local ADDON, ns = ...
-- Fonts and backdrops for the skins and the text bridges (from the
-- InfoPanel's Media.lua): the theme fonts and textures come from
-- LibForeverThemes, Friz Quadrata and Morpheus are the client's.
local Media = {}
ns.Media = Media

local Lib = LibForeverThemes
local CLIENT_FONTS = { ["Friz Quadrata"] = "Fonts\\FRIZQT__.TTF", ["Arial Narrow"] = "Fonts\\ARIALN.TTF",
    ["Skurri"] = "Fonts\\SKURRI.TTF", ["Morpheus"] = "Fonts\\MORPHEUS.TTF" }
Media.DEFAULT = { font = CLIENT_FONTS["Friz Quadrata"] }

-- A font's file by name; an unknown name gets Friz Quadrata.
function Media.FontPath(name)
    return Lib.FontPath(name) or CLIENT_FONTS[name] or Media.DEFAULT.font
end

-- The central theme's backdrop on tex (art: the theme spec's art), tiled,
-- tinted as in every Forever addon (the grey texture under a colour).
local WHITE = { 1, 1, 1, 1 }
function Media.ThemeBackground(tex, art)
    local id, color = ns.Themes.Current(), ns.Themes.Color()
    tex:SetTexture(Lib.Texture(Lib.Back(art, id, color) .. ".tga"), "REPEAT", "REPEAT")
    tex:SetHorizTile(true)
    tex:SetVertTile(true)
    local t = Lib.Tint(art, id, color) or WHITE
    tex:SetVertexColor(t[1], t[2], t[3], t[4] or 1)
end

-- A text style (Settings.TextStyle) on a font string. SHADOW is a drop
-- shadow, the other flags are outlines.
-- Whether a text has the requested font. A file not loaded yet (the
-- themes' ones) can be refused on first use.
local function hasFont(fs, path)
    local got = fs:GetFont()
    if type(got) ~= "string" then return false end
    local function plain(p) return (p:lower():gsub("/", "\\")) end
    return plain(got) == plain(path)
end
Media.HasFont = hasFont
-- How often and how far apart a refused font is tried again.
local FONT_RETRIES, FONT_RETRY_DELAY = 40, 0.25

-- A font file used for the first time can leave a text blank although
-- GetFont reports it (seen in game: blank texts until the theme was picked
-- a second time). Set again a little later via another font, as that second
-- pick does, they appear. Once per text and font.
-- A file's first use can take seconds when many fonts load at once (theme
-- switch); report only once per file.
local refusedFonts = {}

local REDRAW_DELAYS = { 0.5, 2 }
local function redrawLater(fs, path, size, flags, wanted)
    if fs.fontDrawn == wanted then return end
    fs.fontDrawn = wanted
    for _, delay in ipairs(REDRAW_DELAYS) do
        C_Timer.After(delay, function()
            if fs.fontWanted ~= wanted then return end
            fs:SetFont("Fonts\\FRIZQT__.TTF", size, flags)
            fs:SetFont(path, size, flags)
            local text = fs:GetText()
            if text then fs:SetText(""); fs:SetText(text) end
        end)
    end
end

local function setFont(fs, path, size, outline, retries)
    fs:SetFont(path, size, outline)
    local wanted = path .. "|" .. size .. "|" .. outline
    fs.fontWanted = wanted
    if hasFont(fs, path) then
        redrawLater(fs, path, size, outline, wanted)
        return
    end
    -- The default font until then, else the text would have no font.
    fs:SetFont(Media.DEFAULT.font, size, outline)
    if retries <= 0 then
        -- A hidden text (a style without a title) never makes the client
        -- load a new file: no complaint, the next shown use loads it.
        if ns.Print and fs:IsVisible() and not refusedFonts[path] then
            refusedFonts[path] = true
            ns.Print(ns.L.FONT_REFUSED, path)
        end
        return
    end
    C_Timer.After(FONT_RETRY_DELAY, function()
        -- Restyled meanwhile: that call has its own retries.
        if fs.fontWanted == wanted then setFont(fs, path, size, outline, retries - 1) end
    end)
end

function Media.ApplyText(fs, style)
    local flag = style.flag
    local outline = (flag == "OUTLINE" or flag == "THICKOUTLINE") and flag or ""
    fs.fontWanted = nil
    setFont(fs, Media.FontPath(style.font), style.size, outline, FONT_RETRIES)
    if flag == "SHADOW" then
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
    else
        fs:SetShadowOffset(0, 0)
    end
    local c = style.color
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
end

-- Blizzard's font on one of its font strings, remembered before we change
-- it, and put back. SetFontObject alone does not restore: after SetFont the
-- string still names the same font object, and setting that one again
-- changes nothing (seen in game). So file, size, flags and shadow go back
-- explicitly.
function Media.Snapshot(fs)
    local file, size, flags = fs:GetFont()
    local sx, sy = fs:GetShadowOffset()
    local r, g, b, a = fs:GetShadowColor()
    local tr, tg, tb, ta = fs:GetTextColor()
    return { object = fs:GetFontObject(), file = file, size = size, flags = flags or "",
             shadow = { sx or 0, sy or 0 }, shadowColor = { r or 0, g or 0, b or 0, a or 1 },
             color = { tr or 1, tg or 1, tb or 1, ta or 1 } }
end

function Media.Restore(fs, o, withColor)
    if o.file then fs:SetFont(o.file, o.size, o.flags) end
    -- Only FontStrings: a MessageFrame (UIErrorsFrame) errors on any SetFontObject back
    -- ("font object loop"); SetFont above already restored its face.
    if o.object and fs:GetObjectType() == "FontString" then fs:SetFontObject(o.object) end
    fs:SetShadowOffset(o.shadow[1], o.shadow[2])
    fs:SetShadowColor(o.shadowColor[1], o.shadowColor[2], o.shadowColor[3], o.shadowColor[4])
    if withColor then fs:SetTextColor(o.color[1], o.color[2], o.color[3], o.color[4]) end
end
