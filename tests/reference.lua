-- The InfoPanel's own drawing of its backdrop and ring (its Media.lua
-- ApplyBackground and Settings), rebuilt independently of the hub: the
-- skins came from there and must still look like the panel. Paint() draws
-- the central theme and colour onto panel.bg and panel's ring.
local THEME_BACKS = { WOOD = { "Wood", 0.5 }, TECH = { "Tech", 1 }, PARCHMENT = { "Parchment", 0.45 },
    RUNESTONE = { "Stone", 0.55 }, GLASS = { "Glass", 1 }, COMIC = { "Comic", 0.7 }, FROST = { "Frost", 0.55 },
    PIXEL = { "Pixel", 1 }, SWISS = { "Swiss", 1 }, CONSOLE = { "Console", 1 }, PITWALL = { "Swiss", 1 } }
local BG_ALPHA = { FROST = 0.85 }
return function(ns)
    local Lib, Themes = LibForeverThemes, ns.Themes
    local panel = CreateFrame("Frame", "ReferencePanel")
    panel.bg = panel:CreateTexture()
    function panel.Paint()
        local id = Themes.Current()
        local b = THEME_BACKS[id]
        if not b then return end
        local alpha = BG_ALPHA[id] or 1
        local c = Lib.Paint(id, Themes.Color())
        local back = b[1] .. "Back"
        local mean = c and c.back and Lib.GREY_MEAN[back]
        panel.bg:SetTexture(Lib.Texture(mean and back .. "Grey.tga" or back .. ".tga"), "REPEAT", "REPEAT")
        if mean then
            panel.bg:SetVertexColor(math.min(1, c.back[1] / mean), math.min(1, c.back[2] / mean),
                math.min(1, c.back[3] / mean), alpha)
        elseif c and c.paper then
            panel.bg:SetVertexColor(c.paper[1], c.paper[2], c.paper[3], alpha)
        else
            panel.bg:SetVertexColor(b[2], b[2], b[2], alpha)
        end
        local look = Themes.Spec(id).look
        ns.Border.Draw(panel, panel, { style = look.borderStyle, size = look.borderSize,
            color = Themes.Rim(look.borderColor or ns.Settings.DEFAULTS.borderColor), radius = 0, shadow = false })
    end
    return panel
end
