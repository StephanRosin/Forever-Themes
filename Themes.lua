--[[---------------------------------------------------------------------------
Themes.lua -- the central theme and colour (ForeverThemesDB.theme, .colors)
and the look the Blizzard window skins draw in it.

The theme's identity (backdrop, tint, ornaments, wedge, ring, fonts) and
its colours come from LibForeverThemes. SPECS adds what the skins draw on
top: the ring (border), the title colour and outline (look), and the
title strip's shine and line, Swiss' and Pitwall's band and the dark
content shade (art). These are the InfoPanel's values, where the skins
came from, so a skinned window looks like the panel next to it.

Themes.Switch / Themes.SetColor have the shape of a registry entry
(_G.ForeverThemes) but change the central choice; Hub.lua carries it to the
addons.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local Lib = LibForeverThemes
local T = Lib.THEMES

local Themes = {}
ns.Themes = Themes
Themes.CLASSIC = Lib.CLASSIC
Themes.IDS = Lib.IDS
Themes.COLORS = Lib.COLORS

-- The HD themes (WOOD_HD, ...) are their base's part here over a finer
-- backdrop of their own (Lib.Specs, withHd). An addon without them refuses
-- them (UNKNOWN): following and "Apply to all" leave it on its own theme.
Themes.SPECS = Lib.Specs({
    WOOD = {
        look = { borderStyle = "GOLD", borderSize = 3, cornerRadius = 4, shadowEnabled = true, shadowSize = 6,
            shadowAlpha = 60 },
        art = { ornamentSize = 11, ornamentInset = 1, shine = { 1, 0.7, 0.35 }, line = { 0.8, 0.6, 0.3, 0.6 } },
    },
    TECH = {
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = T.TECH.rim, headerColor = { 0.25, 0.88, 0.94 },
            valueColor = { 0.85, 0.95, 1 } },
        art = { shine = { 0.25, 0.88, 0.94 }, line = { 0.25, 0.88, 0.94, 0.6 } },
    },
    -- The paper as dark as the Quest Log's (0.45): light text with an outline.
    PARCHMENT = {
        look = { borderStyle = "FLAT", borderSize = 2, borderColor = T.PARCHMENT.rim, cornerRadius = 2,
            shadowEnabled = true, shadowSize = 5, shadowAlpha = 45, headerColor = { 1, 0.9, 0.7 } },
        art = { ornamentSize = 16, ornamentInset = 0, shine = { 0.45, 0.3, 0.15 }, line = { 0.29, 0.2, 0.12, 0.8 } },
    },
    RUNESTONE = {
        look = { borderStyle = "FLAT", borderSize = 2, borderColor = T.RUNESTONE.rim, shadowEnabled = true,
            shadowSize = 6, shadowAlpha = 70, headerColor = { 0.35, 0.95, 0.85 } },
        art = { ornamentSize = 14, ornamentInset = 2, shine = { 0.35, 0.95, 0.85 }, line = { 0.35, 0.95, 0.85, 0.5 } },
    },
    GLASS = {
        look = { borderStyle = "FLAT", borderSize = 3, borderColor = T.GLASS.rim, shadowEnabled = true,
            shadowSize = 6, shadowAlpha = 55 },
        art = { shine = { 1, 1, 1 }, line = { 0.07, 0.06, 0.05, 1 }, contentShade = { 0.05, 0.04, 0.06, 0.9 } },
    },
    -- Titles light with a thick outline, values dark ink on the grey paper.
    COMIC = {
        look = { borderStyle = "FLAT", borderSize = 3, borderColor = T.COMIC.rim, headerFlag = "THICKOUTLINE",
            headerColor = { 1, 0.9, 0.1 }, valueColor = { 0.1, 0.1, 0.1 } },
        art = { shine = { 1, 0.9, 0.1 }, line = { 0.07, 0.07, 0.07, 1 } },
    },
    -- A soft drop shadow instead of an outline.
    FROST = {
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = T.FROST.rim, cornerRadius = 6,
            shadowEnabled = true, shadowSize = 8, shadowAlpha = 55, headerColor = { 0.86, 0.96, 1 },
            headerFlag = "SHADOW" },
        art = { shine = { 0.86, 0.96, 1 }, line = { 0.86, 0.96, 1, 0.6 }, contentShade = { 0.02, 0.07, 0.15, 0.45 } },
    },
    PIXEL = {
        look = { borderStyle = "FLAT", borderSize = 3, borderColor = T.PIXEL.rim, headerColor = { 1, 0.95, 0.91 } },
        art = { shine = { 1, 0.95, 0.91 }, line = { 1, 0.95, 0.91, 0.6 } },
    },
    SWISS = {
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = T.SWISS.rim, headerColor = { 1, 0.176, 0.125 },
            valueColor = { 0.949, 0.949, 0.949 } },
        art = { shine = { 1, 0.176, 0.125 }, line = { 0.165, 0.165, 0.165, 1 },
            band = { color = T.SWISS.rule, height = T.SWISS.ruleSize } },
    },
    CONSOLE = {
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = T.CONSOLE.rim,
            headerColor = { 0.306, 0.929, 0.69 }, valueColor = { 0.902, 0.91, 0.933 } },
        art = { shine = { 0.306, 0.929, 0.69 }, line = { 0.545, 0.565, 0.627, 0.5 } },
    },
    -- A black title strip with the wedge, the content on a black card.
    PITWALL = {
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = T.PITWALL.rim,
            headerColor = { 0.949, 0.953, 0.961 }, valueColor = { 0.949, 0.953, 0.961 } },
        art = { shine = { 0, 0, 0 }, line = { 0, 0, 0, 1 }, band = { color = T.PITWALL.strip },
            contentShade = { 0, 0, 0, 0.85 } },
    },
    -- A window of the game's own world: parchment in a walnut frame, the title
    -- in gold on a red banner. Blizzard sets most texts light, so the light
    -- parchment is shaded as dark as Parchment's paper (light text with an
    -- outline; dark ink only where an addon sets every colour itself).
    AZEROTH = {
        look = { borderStyle = "FLAT", borderSize = 2, borderColor = T.AZEROTH.rim, headerColor = { 1, 0.82, 0 },
            valueColor = { 0.96, 0.89, 0.72 } },
        art = { ornamentSize = 18, ornamentInset = 0, shine = { 1, 0.82, 0 }, line = { 0.29, 0.2, 0.12, 0.8 },
            band = {}, contentShade = { 0.16, 0.09, 0.03, 0.55 } },
    },
    -- A goblin workshop: sooty sheet metal in a copper frame with rivets; the
    -- warning stripes only as a thin strip (text on them would not read).
    GOBLIN = {
        displaySizeAdd = -1,
        look = { borderStyle = "FLAT", borderSize = 2, borderColor = T.GOBLIN.rim, headerColor = { 0.95, 0.76, 0.19 },
            valueColor = { 0.96, 0.92, 0.85 } },
        art = { ornamentSize = 11, ornamentInset = 0, shine = { 0.95, 0.76, 0.19 }, line = { 0.55, 0.33, 0.16, 0.8 },
            band = { height = 5 } },
    },
}, true)
-- Classic draws nothing; its look only keeps the skins' lookups safe.
Themes.SPECS.CLASSIC.look = {}

local function db() return ns.AccountDB() end

-- The central theme; CLASSIC until one is chosen (or seeded, Hub.lua).
function Themes.Current()
    local id = db().theme
    return Themes.SPECS[id] and id or Themes.CLASSIC
end

-- Whether a central theme was chosen or seeded yet.
function Themes.IsSet() return db().theme ~= nil end

function Themes.Spec(id) return Themes.SPECS[id] or Themes.SPECS.CLASSIC end

function Themes.Colors(themeId) return Lib.Colors(themeId or Themes.Current()) end

-- The colour of themeId (default: the central theme): the chosen one, else
-- the theme's first; nil for CLASSIC.
function Themes.Color(themeId)
    themeId = themeId or Themes.Current()
    local colors = db().colors
    return Lib.ValidColor(themeId, colors and colors[themeId])
end

-- The central theme: id. true, or nil and why not.
function Themes.Switch(id)
    if not Themes.SPECS[id] then return nil, "UNKNOWN" end
    if id == db().theme then return true end
    db().theme = id
    ns.Settings.Changed()
    return true
end

-- The colour id for themeId (default: the central theme).
function Themes.SetColor(id, themeId)
    themeId = themeId or Themes.Current()
    if not Lib.Colour(themeId, id) then return nil, "UNKNOWN" end
    local store = db()
    store.colors = store.colors or {}
    if store.colors[themeId] == id then return true end
    store.colors[themeId] = id
    if themeId == Themes.Current() then ns.Settings.Changed() end
    return true
end

-- The face for Blizzard's texts and Platynator under the central theme,
-- the same as Forever Unit Frames' Themes.Font (its title font, Swiss',
-- Console's and Pitwall's text font; Comic: Bangers); nil under Classic and
-- on a client whose letters the fonts lack. Unit Frames names Pitwall's
-- "Titillium Web", the same file under its older name.
function Themes.Font()
    local id = Themes.Current()
    if id == Themes.CLASSIC or not Lib.LatinClient() then return nil end
    return Lib.ForeignFont(Themes.Spec(id))
end

-- The colour (back or paper) in use, nil while it is the theme's first.
function Themes.BackColor() return Lib.Paint(Themes.Current(), Themes.Color()) end

function Themes.Accent(color) return Lib.Accent(Themes.Current(), Themes.Color()) or color end
function Themes.Rim(color) return Lib.Rim(Themes.Current(), Themes.Color()) or color end
function Themes.Wedge(color)
    return Lib.WedgeColor({ wedgeColor = color }, Themes.Current(), Themes.Color())
end

-- Light ink on a dark comic paper.
local LIGHT_TEXT = { 0.9, 0.9, 0.9 }
local LIGHT_ICONS = { 0.85, 0.85, 0.85 }
local function darkPaper() return Lib.DarkPaper(Themes.Current(), Themes.Color()) end

function Themes.OnPaper(color) return darkPaper() and LIGHT_TEXT or color end

-- The icons' colour (close cross, tabs): a theme's own ink (Comic), else the
-- accent of its colour (Pitwall: the wedge's); nil under Classic.
function Themes.IconColor()
    if darkPaper() then return LIGHT_ICONS end
    local id = Themes.Current()
    local spec = Themes.Spec(id)
    if id == Themes.CLASSIC or spec.iconColor then return spec.iconColor end
    local c = Lib.IconColor(spec, id, Themes.Color(), spec.look.headerColor or ns.Settings.DEFAULTS.headerColor)
    return { c[1], c[2], c[3] }
end
