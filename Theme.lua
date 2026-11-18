local name, ns = ...
_G.Sintezza_Theme = ns

local MEDIA = "Interface\\AddOns\\" .. name .. "\\Media\\"
ns.media = MEDIA
ns.icons = {
    Sintezza_Theme = MEDIA .. "Icons\\Sintezza_Theme",
    Sintezza_UI = MEDIA .. "Icons\\Sintezza_UI",
    Sintezza_Disenchant = MEDIA .. "Icons\\Sintezza_Disenchant",
    Sintezza_Loot = MEDIA .. "Icons\\Sintezza_Loot",
    Sintezza_Rivals = MEDIA .. "Icons\\Sintezza_Rivals",
    Sintezza_Vendor = "Interface\\Icons\\INV_Misc_Coin_01",
    DisenchantProfession = MEDIA .. "Icons\\DisenchantProfession.tga",
    GameBar = MEDIA .. "Icons\\GameBar\\",
    RaidTools = MEDIA .. "Icons\\RaidTools\\",
    RivalsMarker = MEDIA .. "Icons\\NameplateDiamond",
}

local factionCrests = {
    Alliance = MEDIA .. "Icons\\Factions\\Alliance.tga",
    Horde = MEDIA .. "Icons\\Factions\\Horde.tga",
}

function ns:GetFactionCrest(faction)
    if issecretvalue and issecretvalue(faction) then return end
    return factionCrests[faction]
end

local T = {
    media = MEDIA,
    bg = { 0.018, 0.026, 0.032, 0.985 },
    sidebar = { 0.022, 0.032, 0.039, 0.985 },
    panel = { 0.035, 0.047, 0.056, 0.88 },
    panelHover = { 0.055, 0.071, 0.082, 0.94 },
    input = { 0.025, 0.034, 0.040, 0.90 },
    line = { 0.20, 0.27, 0.30, 0.48 },
    lineSoft = { 0.20, 0.27, 0.30, 0.24 },
    text = { 0.90, 0.93, 0.95, 1 },
    muted = { 0.49, 0.55, 0.59, 1 },
    accent = { 0.047, 0.824, 0.624, 1 },
    accentDim = { 0.025, 0.27, 0.225, 0.82 },
    toggleOff = { 0.12, 0.15, 0.17, 0.82 },
    knobOff = { 0.46, 0.50, 0.52, 1 },
    warning = { 0.95, 0.68, 0.18, 1 },
    danger = { 0.95, 0.31, 0.25, 1 },
}
ns.Theme = T

local brass = {
    bg = { 0.077, 0.071, 0.066, 1 },
    sidebar = { 0.066, 0.060, 0.055, 1 },
    header = { 0.112, 0.102, 0.090, 1 },
    headerLight = { 0.74, 0.70, 0.65, 1 },
    badge = { 0.135, 0.121, 0.102, 1 },
    panel = { 0.122, 0.127, 0.134, 1 },
    panelHover = { 0.154, 0.165, 0.176, 1 },
    input = { 0.070, 0.074, 0.082, 1 },
    line = { 0.477, 0.386, 0.255, 1 },
    lineSoft = { 0.253, 0.218, 0.163, 1 },
    brass = { 0.719, 0.581, 0.374, 1 },
    text = { 0.965, 0.925, 0.847, 1 },
    muted = { 0.788, 0.737, 0.639, 1 },
    dim = { 0.675, 0.608, 0.490, 1 },
    accent = { 0.510, 0.851, 0.784, 1 },
    accentDim = { 0.125, 0.235, 0.220, 1 },
    accentHover = { 0.157, 0.290, 0.263, 1 },
    accentLine = { 0.309, 0.549, 0.491, 1 },
    selection = { 0.138, 0.115, 0.086, 1 },
    selectionHover = { 0.175, 0.145, 0.110, 1 },
    selectionLine = { 0.336, 0.273, 0.185, 1 },
    rowBand = { 0.74, 0.81, 0.90, 0.035 },
    toggleOff = { 0.164, 0.145, 0.113, 1 },
    toggleOn = { 0.137, 0.349, 0.318, 1 },
    toggleBorder = { 0.44, 0.38, 0.27, 1 },
    knobOff = { 0.67, 0.61, 0.50, 1 },
    sliderTrack = { 0.48, 0.42, 0.31, 1 },
    sliderThumb = { 0.88, 0.86, 0.77, 1 },
    scrollTrack = { 0.35, 0.29, 0.20, 0.38 },
    scrollThumb = { 0.788, 0.737, 0.639, 0.72 },
    controlFace = { 0.135, 0.117, 0.087, 1 },
    controlDisabled = { 0.096, 0.093, 0.082, 1 },
    frameAccent = { 0.31, 0.58, 0.75, 1 },
}

local function Mix(from, to, weight, alpha)
    return {
        from[1] + (to[1] - from[1]) * weight,
        from[2] + (to[2] - from[2]) * weight,
        from[3] + (to[3] - from[3]) * weight,
        alpha or 1,
    }
end

local function Palette(colors)
    local palette = {}
    local keys = { "bg", "sidebar", "header", "panel", "input", "line", "lineSoft", "brass",
        "text", "muted", "accent", "accentDim", "selection" }
    for i, key in ipairs(keys) do
        local color = colors[i]
        palette[key] = { tonumber(color:sub(1, 2), 16) / 255, tonumber(color:sub(3, 4), 16) / 255,
            tonumber(color:sub(5, 6), 16) / 255, 1 }
    end
    local p = palette
    p.headerLight = p.brass
    p.badge = Mix(p.header, p.brass, .10)
    p.panelHover = Mix(p.panel, p.muted, .11)
    p.dim = Mix(p.muted, p.bg, .18)
    p.accentHover = Mix(p.accentDim, p.accent, .12)
    p.accentLine = Mix(p.accentDim, p.accent, .48)
    p.selectionHover = Mix(p.selection, p.brass, .10)
    p.selectionLine = p.lineSoft
    p.rowBand = Mix(p.muted, p.accent, .2, .04)
    p.toggleOff = Mix(p.panel, p.lineSoft, .35)
    p.toggleOn = Mix(p.accentDim, p.accent, .16)
    p.toggleBorder = Mix(p.line, p.muted, .16)
    p.knobOff = p.dim
    p.sliderTrack = p.line
    p.sliderThumb = Mix(p.text, p.accent, .15)
    p.scrollTrack = Mix(p.lineSoft, p.line, .35, .38)
    p.scrollThumb = Mix(p.muted, p.accent, .15, .76)
    p.controlFace = p.selection
    p.controlDisabled = Mix(p.input, p.panel, .34)
    p.frameAccent = p.accent
    return p
end

local ember = Palette({ "19120e", "1b120e", "39251a", "2b1e17", "1b130f", "8d5e43", "593b2d",
    "cb8a5f", "fae9d9", "d3b4a2", "e7a57b", "512e1e", "41271c" })
ember.frameAccent = { .68, .43, .31, 1 }

local palettes = {
    BRASS = brass,
    EMBER = ember,
    COPPER = Palette({ "171310", "191410", "2d231d", "251e1a", "1a1512", "755b4a", "4b3830",
        "bb9177", "f6e8dc", "ccb5a6", "e2b397", "453029", "362720" }),
    FOREVER = Palette({ "10100d", "0c0c09", "2d2515", "1b1913", "12110e", "8e713b", "4a3d24",
        "dfbd72", "fff0cc", "d6c299", "ffe29a", "4b3b19", "292112" }),
    FROST = Palette({ "101722", "0c121c", "26394d", "1a2938", "101b28", "6689a4", "354960",
        "9fc9e7", "ecf5ff", "aec5d8", "9ce8f5", "213e4f", "1b2c3a" }),
    ARCANE = Palette({ "191323", "130e1b", "38294a", "2a2037", "1a1323", "8b70a8", "4b385e",
        "c5a6df", "faefff", "cfbbdc", "e1bdff", "483056", "2c203b" }),
    GRAPHITE = Palette({ "131313", "1a1a1a", "303030", "2b2b2b", "1c1c1c", "797979", "505050",
        "ababab", "f1f1f1", "bdbdbd", "dddddd", "535353", "404040" }),
}

local stoneTones = {
    BRASS = { 36 / 255, 74 / 255, 69 / 255 },
    EMBER = { 101 / 255, 56 / 255, 33 / 255 },
    COPPER = { 91 / 255, 54 / 255, 51 / 255 },
    FOREVER = { 72 / 255, 56 / 255, 32 / 255 },
    FROST = { 48 / 255, 72 / 255, 100 / 255 },
    ARCANE = { 84 / 255, 58 / 255, 104 / 255 },
    GRAPHITE = { .26, .26, .26 },
}

local controlNeutral = { .135, .119, .105, 1 }
local controlGraphite = { .15, .15, .15, 1 }
for id, palette in pairs(palettes) do
    local graphite = id == "GRAPHITE"
    local control = graphite and controlGraphite or controlNeutral
    palette.stoneTone = stoneTones[id]
    palette.chromeShade = Mix(graphite and { .09, .09, .09 } or { .080, .073, .065 }, palette.stoneTone, .05)
    palette.cardLight = Mix(graphite and { .30, .30, .30 } or { .267, .227, .176 }, palette.stoneTone, .44, .38)
    palette.cardShade = Mix(graphite and { .15, .15, .15 } or { .129, .106, .082 }, palette.stoneTone, .18, .68)
    palette.cardHeading = Mix(graphite and { .55, .55, .55 } or { .62, .52, .41 }, palette.stoneTone, .12, .26)
    palette.controlFace = control
    palette.controlEdge = Mix(graphite and { .41, .41, .41 } or { .33, .29, .25 }, palette.line, .20)
    palette.controlActive = Mix(control, palette.accentDim, .35)
    palette.controlActiveHover = Mix(palette.controlActive, palette.accent, .10)
    palette.controlAccentLine = Mix(palette.accentLine, palette.accent, .14)
    palette.sliderTrack = Mix(graphite and { .42, .42, .42 } or { .24, .21, .18 }, palette.stoneTone, .18)
    palette.sliderThumb = Mix(palette.accent, palette.text, .28)
end

local Settings = setmetatable({}, { __index = T })
ns.Settings = Settings
local refreshers = setmetatable({}, { __mode = "k" })
local paletteColors = {}

function ns:TrackAppearance(region, key, repaint)
    local handlers = refreshers[region]
    if not handlers then
        handlers = {}
        refreshers[region] = handlers
    end
    handlers[key] = repaint
end

function ns:Tint(region, method, color, alpha)
    local function Paint(target)
        target[method](target, color[1], color[2], color[3], alpha or color[4] or 1)
    end
    Paint(region)
    if paletteColors[color] then
        self:TrackAppearance(region, method, Paint)
    elseif refreshers[region] then
        refreshers[region][method] = nil
    end
end

function ns:SnapTexture(texture)
    if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(true) end
    if texture.SetTexelSnappingBias then texture:SetTexelSnappingBias(0) end
end

function ns:GetPalette()
    local settings = Sintezza_ThemeDB
    local selected = type(settings) == "table" and settings.palette
    return palettes[selected] and selected or "BRASS"
end

function ns:GetPaletteSwatch(id)
    local palette = palettes[id]
    if palette then return palette.bg, palette.text, palette.accentDim end
end

function ns:LoadPalette()
    local palette = palettes[self:GetPalette()]
    for key, color in pairs(palette) do
        local live = Settings[key] or {}
        for i = 1, #color do live[i] = color[i] end
        Settings[key] = live
        paletteColors[live] = true
    end
end

local backgroundSettings = { tint = "backgroundTintStrength", texture = "backgroundTextureStrength" }
local activeBackground = { tint = 1, texture = 1 }
local backgroundRegions = {
    tint = setmetatable({}, { __mode = "k" }),
    texture = setmetatable({}, { __mode = "k" }),
}

local function CanPaint(region)
    local isSecret = issecretvalue
    while true do
        if isSecret and isSecret(region) then return false end
        if not region then return true end

        if region.IsForbidden then
            local forbidden = region:IsForbidden()
            if (isSecret and isSecret(forbidden)) or forbidden then return false end
        end
        if region.CanBeAccessedInContext then
            local accessible = region:CanBeAccessedInContext()
            if (isSecret and isSecret(accessible)) or not accessible then return false end
        end
        region = region.GetParent and region:GetParent()
    end
end

local function NormalizeStrength(value)
    if issecretvalue and issecretvalue(value) then return 100 end
    local number = tonumber(value)
    if not number or number ~= number then return 100 end
    return math.max(0, math.min(100, number))
end

function ns:GetBackgroundStrength(kind)
    local key = backgroundSettings[kind]
    if key then return NormalizeStrength(self.Fonts:GetSettings()[key]) end
end

local function ApplyBackgroundStrength(kind, strength)
    activeBackground[kind] = strength
    for region, baseOpacity in pairs(backgroundRegions[kind]) do
        if CanPaint(region) then region:SetAlpha(baseOpacity * strength) end
    end
end

function ns:SetBackgroundStrength(kind, value)
    local key = backgroundSettings[kind]
    if not key then return false end
    local settings = self.Fonts:GetSettings()
    value = NormalizeStrength(value)
    settings[key] = value
    local strength = value / 100
    if activeBackground[kind] == strength then return true end
    if InCombatLockdown and InCombatLockdown() then
        self.pendingAppearance = true
        return false
    end
    ApplyBackgroundStrength(kind, strength)
    return true
end

local function LoadBackgroundStrengths()
    ApplyBackgroundStrength("tint", ns:GetBackgroundStrength("tint") / 100)
    ApplyBackgroundStrength("texture", ns:GetBackgroundStrength("texture") / 100)
end

local function TrackBackgroundOpacity(region, kind, baseOpacity)
    backgroundRegions[kind][region] = baseOpacity
    region:SetAlpha(baseOpacity * activeBackground[kind])
end

function ns:RefreshAppearance()
    if InCombatLockdown and InCombatLockdown() then
        self.pendingAppearance = true
        return false
    end
    self.pendingAppearance = nil
    local settings = self.Fonts:GetSettings()
    self.activeFont = settings.interfaceFont or "THEME"
    self.activeTitleFont = settings.titleFont or "THEME"
    self.activeButtonStyle = self:GetButtonStyle()
    self.animateControls = settings.animateControls ~= false
    self:LoadPalette()
    LoadBackgroundStrengths()
    for region, handlers in pairs(refreshers) do
        if CanPaint(region) then
            for key, repaint in pairs(handlers) do
                if key ~= "state" then repaint(region) end
            end
        end
    end
    for region, handlers in pairs(refreshers) do
        if handlers.state and CanPaint(region) then
            handlers.state(region)
        end
    end
    return true
end

ns:LoadPalette()
LoadBackgroundStrengths()

local GLYPHS = { overview = 0, panels = 1, combat = 2, party = 3, system = 4, check = 5, pin = 6, chevron = 7 }

function Settings:Glyph(frame, key, size, color)
    local index = assert(GLYPHS[key], "unknown settings glyph")
    local texture = frame:CreateTexture(nil, "OVERLAY")
    texture:SetTexture(MEDIA .. "settings-glyphs.tga")
    texture:SetTexCoord(index / 8, (index + 1) / 8, 0, 1)
    texture:SetSize(size, size)
    ns:Tint(texture, "SetVertexColor", color or self.brass)
    return texture
end

function Settings:BrassCorners(frame)
    for _, position in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
        local right = position:find("RIGHT", 1, true)
        local bottom = position:find("BOTTOM", 1, true)
        local texture = frame:CreateTexture(nil, "OVERLAY", nil, 2)
        texture:SetTexture(MEDIA .. "settings-corner.tga")
        texture:SetTexCoord(right and 1 or 0, right and 0 or 1, bottom and 1 or 0, bottom and 0 or 1)
        texture:SetSize(24, 24)
        texture:SetPoint(position, frame, position, right and 1 or -1, bottom and -1 or 1)
        ns:Tint(texture, "SetVertexColor", self.brass)
    end
end

local function TiledSurface(frame, asset, tileSize, anchor)
    local bounds = anchor or frame
    local grain = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    grain:SetTexture(MEDIA .. asset, "REPEAT", "REPEAT")
    grain:SetPoint("TOPLEFT", bounds, "TOPLEFT", 1, -1)
    grain:SetPoint("BOTTOMRIGHT", bounds, "BOTTOMRIGHT", -1, 1)
    local function Tile(_, width, height)
        if issecretvalue and (issecretvalue(width) or issecretvalue(height)) then return end
        grain:SetTexCoord(0, math.max(1, width - 2) / tileSize, 0, math.max(1, height - 2) / tileSize)
    end
    -- Anchored surfaces are fixed-size popups. Do not hook their native layout.
    if not anchor then frame:HookScript("OnSizeChanged", Tile) end
    Tile(bounds, bounds:GetWidth(), bounds:GetHeight())
    return grain
end

function Settings:Surface(frame, grainOpacity, lightOpacity, lightTint, grainAsset)
    local grain = TiledSurface(frame, grainAsset or "settings-grain.tga", 128)
    TrackBackgroundOpacity(grain, "texture", grainOpacity)
    if lightOpacity then
        local light = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
        light:SetTexture(MEDIA .. "settings-depth.tga")
        light:SetAllPoints(grain)
        if lightTint then ns:Tint(light, "SetVertexColor", lightTint) end
        TrackBackgroundOpacity(light, lightTint and "tint" or "texture", lightOpacity)
    end
end

function T:GetFont()
    if EllesmereUI and EllesmereUI.GetFontPath then
        local path = EllesmereUI.GetFontPath("nameplates")
        if path then return path end
    end
    local path = GameFontHighlight and GameFontHighlight:GetFont()
    return path or "Fonts\\FRIZQT__.TTF"
end

local function FontPath(value)
    return type(value) == "string" and value ~= "" and value or nil
end

function T:GetGameTextFont()
    return FontPath(STANDARD_TEXT_FONT) or (GameFontHighlight and FontPath(GameFontHighlight:GetFont()))
end

function T:GetCombatTextFont()
    local magic = _G.FontMagicCombatTextFix
    if magic and type(magic.GetSelectedCombatTextFontPath) == "function" then
        local ok, path = pcall(magic.GetSelectedCombatTextFontPath, magic)
        if ok and FontPath(path) then return path end
    end
    local native = _G.CombatTextFont
    return FontPath(_G.DAMAGE_TEXT_FONT) or FontPath(_G.COMBAT_TEXT_FONT)
        or (native and native.GetFont and FontPath(native:GetFont()))
end

local function SharedMedia()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

function T:TextFontChoices(includeInterface)
    local choices = { DEFAULT = "По умолчанию (WoW)", COMBAT = "Боевой шрифт" }
    if includeInterface then choices.INTERFACE = "Как в интерфейсе" end
    local media = SharedMedia()
    if media and media.List then
        for _, name in ipairs(media:List("font") or {}) do
            if not choices[name] then choices[name] = name end
        end
    end
    return choices
end

function T:ResolveTextFont(selection)
    if selection == "INTERFACE" then return self:GetFont() end
    if selection == "COMBAT" then return self:GetCombatTextFont() or self:GetGameTextFont() end
    if type(selection) == "string" and selection ~= "DEFAULT" then
        local media = SharedMedia()
        local font = media and media.Fetch and FontPath(media:Fetch("font", selection, true))
        if font then return font end
    end
    return self:GetGameTextFont()
end

function T:ApplyTextFont(fontString, selection, size, flags)
    local chosen = self:ResolveTextFont(selection)
    if chosen then
        local ok, applied = pcall(fontString.SetFont, fontString, chosen, size, flags)
        if ok and applied ~= false then return end
    end
    local default = self:GetGameTextFont()
    if default and default ~= chosen then fontString:SetFont(default, size, flags) end
end

function T:Font(fontString, size, flags, color, preferred)
    local function Apply(region)
        local ok = not preferred and ns.Fonts:Apply(region, size or 11, flags)
        if not ok then ok = region:SetFont(preferred or self:GetFont(), size or 11, flags or "") end
        if not ok and preferred then
            ok = region:SetFont(self:GetGameTextFont() or self:GetFont(), size or 11, flags or "")
        end
        if not ok and GameFontHighlight then region:SetFont(GameFontHighlight:GetFont(), size or 11, flags or "") end
    end
    Apply(fontString)
    if not preferred then ns:TrackAppearance(fontString, "font", Apply) end
    ns:Tint(fontString, "SetTextColor", color or self.text)
end

function Settings:Font(fontString, size, flags, color, role)
    ns.Fonts:ApplyTheme(fontString, size or 11, flags, nil, role)
    ns:Tint(fontString, "SetTextColor", color or self.text)
end

function ns:ForAddon(_, palette)
    return setmetatable({}, { __index = palette or Settings })
end

function T:Backdrop(frame, color, border)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    color, border = color or self.panel, border or self.line
    ns:Tint(frame, "SetBackdropColor", color)
    ns:Tint(frame, "SetBackdropBorderColor", border)
end

function T:SectionSurface(frame)
    self:Backdrop(frame, self.input, self.lineSoft)
    local wash = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    wash:SetPoint("TOPLEFT", 1, -1)
    wash:SetPoint("BOTTOMRIGHT", -1, 1)
    local function Paint(texture)
        local warm = self.brass
        texture:SetColorTexture(warm[1], warm[2], warm[3], .13)
        if texture.SetGradient and CreateColor then
            texture:SetGradient("HORIZONTAL", CreateColor(warm[1], warm[2], warm[3], .24), CreateColor(warm[1], warm[2], warm[3], 0))
        end
    end
    Paint(wash)
    ns:TrackAppearance(wash, "state", Paint)
end

local function PaintGradient(texture, bottom, top, bottomAlpha, topAlpha)
    texture:SetColorTexture(top[1], top[2], top[3], topAlpha or top[4])
    if texture.SetGradient and CreateColor then
        texture:SetColorTexture(1, 1, 1, 1)
        texture:SetGradient("VERTICAL", CreateColor(bottom[1], bottom[2], bottom[3], bottomAlpha or bottom[4]),
            CreateColor(top[1], top[2], top[3], topAlpha or top[4]))
    end
end

local function StoneWash(frame, material, tone)
    local wash = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    wash:SetAllPoints(material)
    wash:SetTexture(MEDIA .. "stone-wash.tga")
    ns:Tint(wash, "SetVertexColor", tone)
    TrackBackgroundOpacity(wash, "tint", 1)
end

local function SlateSurface(frame, tone)
    local material = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    material:SetTexture(MEDIA .. "slate-relief.tga")
    material:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    material:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    local function Crop(_, width, height)
        local aspect = math.max(1, width - 2) / math.max(1, height - 2)
        local sourceAspect = 1120 / 800
        local halfU = .5 * math.min(1, aspect / sourceAspect)
        local halfV = .5 * math.min(1, sourceAspect / aspect)
        material:SetTexCoord(.5 - halfU, .5 + halfU, .5 - halfV, .5 + halfV)
    end
    frame:HookScript("OnSizeChanged", Crop)
    Crop(frame, frame:GetWidth(), frame:GetHeight())
    TrackBackgroundOpacity(material, "texture", 1)
    if material.SetDesaturated then
        local function Paint(target) target:SetDesaturated(ns:GetPalette() == "GRAPHITE") end
        Paint(material)
        ns:TrackAppearance(material, "slateDesaturation", Paint)
    end

    StoneWash(frame, material, tone)
end

local function AddSeamGlint(header, tint)
    local glint = header:CreateTexture(nil, "BORDER", nil, 2)
    glint:SetTexture(MEDIA .. "seam-glint.tga")
    glint:SetPoint("BOTTOMLEFT", 1, 0)
    glint:SetHeight(5)
    glint:Hide()
    ns:Tint(glint, "SetVertexColor", tint)

    local group = glint:CreateAnimationGroup()
    local travel = group:CreateAnimation("Translation")
    travel:SetDuration(.72)
    travel:SetOrder(1)
    local fadeIn = group:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(.24)
    fadeIn:SetDuration(.22)
    fadeIn:SetOrder(1)
    local fadeOut = group:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(.24)
    fadeOut:SetToAlpha(0)
    fadeOut:SetStartDelay(.22)
    fadeOut:SetDuration(.50)
    fadeOut:SetOrder(1)

    local function Stop()
        group:Stop()
        glint:Hide()
    end
    local function Play()
        if not ns.animateControls or not header:IsVisible() then return end
        local width = header:GetWidth() - 2
        if width < 2 then return end
        Stop()
        local glintWidth = math.min(170, width * .36)
        glint:SetWidth(glintWidth)
        travel:SetOffset(width - glintWidth, 0)
        glint:Show()
        group:Play()
    end
    group:SetScript("OnFinished", function() glint:Hide() end)
    header:HookScript("OnShow", Play)
    header:HookScript("OnHide", Stop)
    header:HookScript("OnSizeChanged", function()
        if group:IsPlaying() then Stop() end
    end)
    ns:TrackAppearance(glint, "state", function()
        if ns.animateControls == false then Stop() end
    end)
    Play()
end

local function AddHeaderEdge(theme, frame)
    local function Part(index)
        local part = frame:CreateTexture(nil, "BORDER", nil, 2)
        part:SetTexture(MEDIA .. "header-seam.tga")
        part:SetTexCoord(index / 4, (index + 1) / 4, 0, 1)
        part:SetHeight(8)
        ns:SnapTexture(part)
        ns:Tint(part, "SetVertexColor", theme.brass, .68)
        return part
    end
    local left, curve, right = Part(0), Part(1), Part(2)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 0)
    left:SetPoint("BOTTOMRIGHT", curve, "BOTTOMLEFT")
    right:SetPoint("BOTTOMLEFT", curve, "BOTTOMRIGHT")
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 0)

    local function Position(_, width)
        width = math.max(2, width - 2)
        curve:SetWidth(math.min(24, width * .72))
        curve:SetPoint("BOTTOM", frame, "BOTTOMLEFT", 1 + width * .38, 0)
    end
    Position(frame, frame:GetWidth())
    frame:HookScript("OnSizeChanged", Position)
end

local function AddSurfaceLight(theme, frame, layer, alpha)
    local light = frame:CreateTexture(nil, "BACKGROUND", nil, layer)
    light:SetTexture(MEDIA .. "surface-light.tga")
    light:SetPoint("TOPLEFT", 1, -1)
    light:SetPoint("BOTTOMRIGHT", -1, 1)
    ns:Tint(light, "SetVertexColor", theme.stoneTone, alpha)
    TrackBackgroundOpacity(light, "tint", 1)
end

local windowSurfaces = setmetatable({}, { __mode = "k" })

function Settings:WindowSurface(frame, anchor)
    if not anchor then self:Backdrop(frame, self.bg, self.line) end
    local art = windowSurfaces[frame]
    if not art then
        if anchor then
            local rim = frame:CreateTexture(nil, "BACKGROUND", nil, -3)
            rim:SetAllPoints(anchor)
            ns:Tint(rim, "SetColorTexture", self.line)
            local base = frame:CreateTexture(nil, "BACKGROUND", nil, -2)
            base:SetPoint("TOPLEFT", anchor, "TOPLEFT", 1, -1)
            base:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -1, 1)
            ns:Tint(base, "SetColorTexture", self.bg)
            local grain = TiledSurface(frame, "settings-grain.tga", 128, anchor)
            TrackBackgroundOpacity(grain, "texture", 1)
            StoneWash(frame, grain, self.stoneTone)
            art = frame
        else
            art = CreateFrame("Frame", nil, frame)
            art:SetAllPoints()
            art:SetFrameLevel(frame:GetFrameLevel())
            SlateSurface(art, self.stoneTone)
        end
        windowSurfaces[frame] = art
        if not anchor and ns.TrackWindow then ns:TrackWindow(frame) end
    end
    if not anchor then art:Show() end
    return art
end

function ns:SkinProgressBar(bar, color)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    self:Tint(bar, "SetStatusBarColor", color)
end

local skinnedRolls = setmetatable({}, { __mode = "k" })

local function CanStyle(region)
    return CanPaint(region) and region ~= nil
end

local function ApplyItemOutline(theme, item, qualityArt)
    local outline = theme:FrameIcon(item, item.Icon)
    local red, green, blue
    local function Paint(target)
        if red then
            target:SetVertexColor(red, green, blue, 1)
        else
            target:SetVertexColor(unpack(theme.line))
        end
    end
    local function UpdateQuality(_, r, g, b)
        if not CanStyle(outline) then return end
        if (issecretvalue and (issecretvalue(r) or issecretvalue(g) or issecretvalue(b)))
            or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
            red, green, blue = nil, nil, nil
        else
            red, green, blue = r, g, b
        end
        Paint(outline)
    end
    hooksecurefunc(qualityArt, "SetVertexColor", UpdateQuality)
    UpdateQuality(qualityArt, qualityArt:GetVertexColor())
    ns:TrackAppearance(outline, "SetVertexColor", Paint)
    item.Border:SetAlpha(0)
end

function Settings:SkinLootRollPopup(frame)
    if not CanStyle(frame) or skinnedRolls[frame] then return end
    local timer, item = frame.Timer, frame.IconFrame
    if not CanStyle(timer) or not CanStyle(item) then return end
    if not CanStyle(frame.Background) or not CanStyle(frame.Border) or not CanStyle(frame.Name)
        or not CanStyle(timer.Background) or not CanStyle(item.Icon) or not CanStyle(item.Count) then return end

    -- Blizzard places the timer behind the popup on each show. Put the window
    -- art on its background layer so it stays below the timer fill and controls.
    self:WindowSurface(timer, frame)

    frame.Background:SetAlpha(0)
    frame.Border:SetAlpha(0)
    timer.Background:SetAlpha(0)
    ns:SkinProgressBar(timer, self.accent)
    item.Icon:SetTexCoord(.08, .92, .08, .92)
    if CanStyle(item.Border) then ApplyItemOutline(self, item, frame.Border) end
    ns.Fonts:ApplyTheme(frame.Name, 12, "")
    ns.Fonts:ApplyTheme(item.Count, 10, "OUTLINE")
    if CanStyle(frame.NeedRollAnim) and CanStyle(frame.NeedRollAnim.RollNumber) then
        ns.Fonts:ApplyTheme(frame.NeedRollAnim.RollNumber, 32, "OUTLINE")
    end

    local buttons = frame.LootButtonContainer
    if CanStyle(buttons) then
        for _, key in ipairs({ "NeedButton", "PassButton", "GreedButton", "TransmogButton" }) do
            if CanStyle(buttons[key]) then self:StyleIconButton(buttons[key], CanStyle, 4) end
        end
    end
    skinnedRolls[frame] = true
end

function Settings:SidebarSurface(frame)
    self:Backdrop(frame, self.chromeShade, self.lineSoft)
    ns:Tint(frame, "SetBackdropColor", self.chromeShade, .93)
end

function Settings:PanelSurface(frame)
    self:Backdrop(frame, { 0, 0, 0, 0 }, self.lineSoft)
    local wash = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    wash:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    wash:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    local function Paint(target) PaintGradient(target, self.cardShade, self.cardLight) end
    Paint(wash)
    ns:TrackAppearance(wash, "state", Paint)
    AddSurfaceLight(self, frame, 2, .19)
end

function Settings:RowBand(frame)
    local band = frame:CreateTexture(nil, "BACKGROUND", nil, -2)
    band:SetAllPoints()
    ns:Tint(band, "SetColorTexture", self.rowBand)
    return band
end

function Settings:HeaderSurface(frame)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    ns:Tint(frame, "SetBackdropColor", self.chromeShade, .68)
    AddSurfaceLight(self, frame, 1, .31)
    AddHeaderEdge(self, frame)
    AddSeamGlint(frame, self.headerLight)
end

function T:Glow(frame, alpha)
    local texture = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    texture:SetPoint("TOPLEFT", frame, "TOPLEFT", -12, 12)
    texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 12, -12)
    texture:SetTexture(MEDIA .. "window-shadow.png")
    texture:SetBlendMode("BLEND")
    texture:SetVertexColor(0, 0, 0, alpha or 0.9)
    return texture
end
