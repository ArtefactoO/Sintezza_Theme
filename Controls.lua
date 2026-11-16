local _, ns = ...
local T = ns.Settings

local function Lerp(from, to, progress)
    return from + (to - from) * progress
end

local function ColorBetween(from, to, progress, lift)
    return math.min(1, Lerp(from[1], to[1], progress) + lift),
        math.min(1, Lerp(from[2], to[2], progress) + lift),
        math.min(1, Lerp(from[3], to[3], progress) + lift),
        Lerp(from[4] or 1, to[4] or 1, progress)
end

function ns:AnimateControl(frame, paint)
    local value, emphasis = 0, 0
    local targetValue, targetEmphasis = 0, 0
    local fromValue, fromEmphasis, elapsed, duration
    local function Advance(_, delta)
        elapsed = elapsed + delta
        local progress = math.min(1, elapsed / duration)
        local eased = 1 - (1 - progress) ^ 3
        value = Lerp(fromValue, targetValue, eased)
        emphasis = Lerp(fromEmphasis, targetEmphasis, eased)
        paint(value, emphasis)
        if progress == 1 then frame:SetScript("OnUpdate", nil) end
    end

    return function(nextValue, nextEmphasis, seconds)
        if seconds and seconds > 0 and frame:IsVisible() and ns.animateControls ~= false then
            if nextValue == targetValue and nextEmphasis == targetEmphasis then return end
            fromValue, fromEmphasis = value, emphasis
            targetValue, targetEmphasis = nextValue, nextEmphasis
            elapsed, duration = 0, seconds
            frame:SetScript("OnUpdate", Advance)
        else
            frame:SetScript("OnUpdate", nil)
            targetValue, targetEmphasis = nextValue, nextEmphasis
            value, emphasis = nextValue, nextEmphasis
            paint(value, emphasis)
        end
    end
end

function T:SkinToggle(button, track, getValue, palette)
    local off = palette and palette.panel or self.input
    local on = palette and palette.accent or self.toggleOn
    local edge = palette and palette.line or self.toggleBorder
    local accent = palette and palette.accent or self.accent
    local size = track:GetHeight() - 2
    local rim = track:CreateTexture(nil, "BACKGROUND", nil, 0)
    rim:SetTexture(ns.media .. "control-fill.tga")
    rim:SetPoint("CENTER")
    rim:SetSize(size, size)
    ns:SnapTexture(rim)
    local fill = track:CreateTexture(nil, "BACKGROUND", nil, 1)
    fill:SetTexture(ns.media .. "control-fill.tga")
    fill:SetPoint("CENTER")
    fill:SetSize(size - 2, size - 2)
    ns:SnapTexture(fill)
    local mark = self:Glyph(track, "check", size, { .12, .085, .055, 1 })
    mark:SetPoint("CENTER")

    local move = ns:AnimateControl(track, function(position, hover)
        fill:SetVertexColor(ColorBetween(off, accent, position, .035 * hover))
        rim:SetVertexColor(ColorBetween(edge, on, position, .06 * hover))
        mark:SetAlpha(position)
    end)

    local hovered
    local function Sync(animate, duration)
        local enabled = button:IsEnabled()
        move(getValue() and 1 or 0, enabled and hovered and 1 or 0,
            animate and enabled and (duration or .16))
    end
    button:HookScript("OnEnter", function()
        hovered = true
        Sync(true, .12)
    end)
    button:HookScript("OnLeave", function()
        hovered = nil
        Sync(true, .10)
    end)
    button:HookScript("OnHide", function()
        hovered = nil
        Sync(false)
    end)
    button:HookScript("OnShow", function() Sync(false) end)
    ns:TrackAppearance(track, "state", function() Sync(false) end)
    Sync(false)
    return Sync, mark
end

function T:SkinCheckButton(check, size)
    self:Backdrop(check, self.input, self.lineSoft)
    local mark = self:Glyph(check, "check", size, self.accent)
    mark:SetPoint("CENTER")
    check:SetCheckedTexture(mark)
    local disabled = self:Glyph(check, "check", size, self.dim)
    disabled:SetPoint("CENTER")
    check:SetDisabledCheckedTexture(disabled)
    check:HookScript("OnEnter", function()
        if check:IsEnabled() then check:SetBackdropBorderColor(unpack(self.brass)) end
    end)
    check:HookScript("OnLeave", function() check:SetBackdropBorderColor(unpack(self.lineSoft)) end)
    ns:TrackAppearance(check, "state", function(target)
        local hovered = target.IsMouseOver and target:IsMouseOver()
        target:SetBackdropBorderColor(unpack(target:IsEnabled() and hovered and self.brass or self.lineSoft))
    end)
end

function T:SkinInput(edit, size)
    self:Backdrop(edit, self.input, self.lineSoft)
    self:Font(edit, size or 11)
    edit:HookScript("OnEditFocusGained", function() edit:SetBackdropBorderColor(unpack(self.accentLine)) end)
    edit:HookScript("OnEditFocusLost", function() edit:SetBackdropBorderColor(unpack(self.lineSoft)) end)
    ns:TrackAppearance(edit, "state", function(target)
        target:SetBackdropBorderColor(unpack(target:HasFocus() and self.accentLine or self.lineSoft))
    end)
end

local buttonStyles = setmetatable({}, { __mode = "k" })
local menuSurfaces = setmetatable({}, { __mode = "k" })
local textureGetters = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }
local function RoundTexture(texture, asset, snap)
    if not texture.SetTextureSliceMargins then return false end
    if texture:SetTexture(ns.media .. asset, "CLAMP", "CLAMP") == false then return false end
    texture:SetTextureSliceMargins(5, 5, 5, 5)
    if snap then ns:SnapTexture(texture) end
    return true
end

function T:IconBorder(texture, color)
    if not RoundTexture(texture, "control-border.tga") then
        texture:SetTexture(ns.media .. "control-border.tga")
    end
    ns:Tint(texture, "SetVertexColor", color or self.line)
end

function T:FrameIcon(parent, icon)
    local border = parent:CreateTexture(nil, "OVERLAY")
    border:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    self:IconBorder(border)
    return border
end

function T:PaintItemBorder(border, quality, r, g, b)
    if issecretvalue and issecretvalue(quality) then quality = nil end
    quality = tonumber(quality)
    if quality and quality >= 2 then
        if not r and GetItemQualityColor then r, g, b = GetItemQualityColor(quality) end
        if r then
            ns:Tint(border, "SetVertexColor", { r, g or 1, b or 1, .8 })
            return
        end
    end
    ns:Tint(border, "SetVertexColor", self.line)
end

function T:CloseGlyph(button)
    local first = button:CreateTexture(nil, "OVERLAY")
    local second = button:CreateTexture(nil, "OVERLAY")
    for index, stroke in ipairs({ first, second }) do
        stroke:SetColorTexture(1, 1, 1, 1)
        stroke:SetSize(11, 1.5)
        stroke:SetPoint("CENTER")
        stroke:SetRotation(index == 1 and math.pi / 4 or -math.pi / 4)
    end
    return function(color)
        first:SetVertexColor(unpack(color))
        second:SetVertexColor(unpack(color))
    end
end

function T:ControlSurface(frame)
    local fill = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
    local rim = frame:CreateTexture(nil, "BACKGROUND", nil, -5)
    if RoundTexture(fill, "control-fill.tga", true) and RoundTexture(rim, "slate-bevel.tga", true) then
        frame:SetBackdrop(nil)
        fill:SetAllPoints(frame)
        rim:SetAllPoints(frame)
        return function(background, border, depth)
            rim:SetVertexColor(unpack(border))
            local r, g, b, a = unpack(background)
            local opacity = a or 1
            local raised = depth or 0
            if fill.SetGradient and CreateColor then
                local shade = .79 - .035 * raised
                local light = .04 + .05 * raised
                fill:SetVertexColor(1, 1, 1, 1)
                fill:SetGradient("VERTICAL",
                    CreateColor(r * shade, g * shade, b * shade, opacity),
                    CreateColor(math.min(1, r + light),
                        math.min(1, g + .9 * light),
                        math.min(1, b + .8 * light), opacity))
            else
                fill:SetVertexColor(unpack(background))
            end
        end
    end
    rim:Hide()
    fill:Hide()
    self:Backdrop(frame, self.input, self.line)
    return function(background, border)
        frame:SetBackdropColor(unpack(background))
        frame:SetBackdropBorderColor(unpack(border))
    end
end

local mapIconStyle = {
    idle = { { .078, .074, .063, 1 }, { .50, .38, .22, 1 } },
    hover = { { .10, .084, .065, 1 }, { .92, .76, .50, 1 } },
    active = { { .15, .13, .095, 1 }, { .90, .75, .50, 1 } },
    pressed = { { .10, .08, .06, 1 }, { .72, .55, .32, 1 } },
}

function T:PaintButton(button, selected)
    local style = buttonStyles[button]
    if not style then return end
    if selected ~= nil then style.selected = selected end
    local enabled = button:IsEnabled()
    local active = enabled and (style.selected or button.primary)
    local hover = enabled and style.hover
    if style.mapIcon then
        local state = style.pressed and mapIconStyle.pressed or active and mapIconStyle.active
            or hover and mapIconStyle.hover or mapIconStyle.idle
        if style.mapState ~= state then
            style.paint(unpack(state))
            style.mapState = state
        end
        style.mapIndicator:SetShown(not not active)
        style.mapIcon:SetAlpha(enabled and 1 or .45)
        return
    end
    local background
    if not enabled then
        background = self.controlDisabled or self.input
    elseif style.pressed then
        background = self.input
    elseif active then
        background = hover and (self.controlActiveHover or self.accentHover or self.accentDim)
            or self.controlActive or self.accentDim
    else
        background = hover and self.panelHover or self.controlFace or self.input
    end
    local border = not enabled and self.lineSoft or active and (self.controlAccentLine or self.accentLine)
        or hover and self.brass or self.controlEdge or self.line
    style.paint(background, border, not enabled and .4 or style.pressed and .22 or 1)
    local label = style.label or button:GetFontString()
    if label then
        local color = active and self.text
            or (enabled and (style.tab and self.muted or self.text) or self.dim)
        label:SetTextColor(unpack(color))
    end
    if style.paintGlyph then
        style.paintGlyph(not enabled and self.dim or (hover and self.text or self.muted))
    end
end

function T:SkinButton(button, label, fontSize)
    if not (button and button.SetBackdrop) then return false end
    local style = buttonStyles[button]
    if not style then
        style = {}
        buttonStyles[button] = style
        for _, getter in ipairs(textureGetters) do
            local art = button[getter] and button[getter](button)
            if art then art:SetAlpha(0) end
        end
        for _, part in ipairs({ "Left", "Middle", "Right" }) do
            if button[part] then button[part]:SetAlpha(0) end
        end
        style.paint = self:ControlSurface(button)
        local function Paint() T.PaintButton(self, button) end
        button:HookScript("OnEnter", function() style.hover = true; Paint() end)
        button:HookScript("OnLeave", function() style.hover, style.pressed = nil, nil; Paint() end)
        button:HookScript("OnMouseDown", function() style.pressed = true; Paint() end)
        button:HookScript("OnMouseUp", function() style.pressed = nil; Paint() end)
        button:HookScript("OnHide", function() style.hover, style.pressed = nil, nil end)
        button:HookScript("OnShow", Paint)
        button:HookScript("OnEnable", Paint)
        button:HookScript("OnDisable", function() style.pressed = nil; Paint() end)
        ns:TrackAppearance(button, "state", function(target) T.PaintButton(self, target) end)
    end
    if label and label ~= style.label then
        style.label = label
        style.fontApplied = nil
    end
    local text = style.label or button:GetFontString()
    if text and not style.fontApplied then
        self:Font(text, fontSize or 11)
        style.fontApplied = true
    end
    T.PaintButton(self, button)
    return true
end

function T:CreateMapIconButton(parent, texture, onClick, tintIcon)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(28, 28)
    button:SetScript("OnClick", onClick)
    self:SkinButton(button)

    local style = buttonStyles[button]
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(21, 21)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture(texture)
    if tintIcon then
        if icon.SetGradient and CreateColor then
            icon:SetGradient("VERTICAL", CreateColor(.28, .49, .45), CreateColor(.99, .94, .81))
        else
            icon:SetVertexColor(.68, .83, .79)
        end
    end

    local indicator = button:CreateTexture(nil, "OVERLAY")
    indicator:SetSize(8, 1)
    indicator:SetPoint("BOTTOM", 0, 2)
    indicator:SetColorTexture(.93, .75, .44, 1)
    style.mapIcon, style.mapIndicator = icon, indicator
    self:PaintButton(button, false)
    return button
end

function T:SkinCloseButton(button)
    if not self:SkinButton(button) then return false end
    local style = buttonStyles[button]
    if not style.paintGlyph then style.paintGlyph = self:CloseGlyph(button) end
    self:PaintButton(button)
    return true
end

function T:SkinTab(button, label, fontSize)
    if not buttonStyles[button] and not self:SkinButton(button, label, fontSize) then return false end
    local style = buttonStyles[button]
    if not style.tab then
        style.tab = true
        self:PaintButton(button)
    end
    return true
end

function T:DropdownArrow(button, label)
    local arrow = self:Glyph(button, "chevron", 9, self.brass)
    arrow:SetPoint("RIGHT", -7, 0)
    arrow:SetRotation(-math.pi / 2)
    if label then
        label:ClearAllPoints()
        label:SetPoint("LEFT", 8, 0)
        label:SetPoint("RIGHT", arrow, "LEFT", -5, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
    end
    return arrow
end

local arrowRotation = { right = 0, down = -math.pi / 2, left = math.pi, up = math.pi / 2 }

function T:ButtonArrow(button, direction)
    if not buttonStyles[button] and not self:SkinButton(button) then return button end
    local style = buttonStyles[button]
    if not style.arrow then
        local arrow = self:Glyph(button, "chevron", 11, self.muted)
        arrow:SetPoint("CENTER")
        style.arrow = arrow
        style.paintGlyph = function(color) arrow:SetVertexColor(unpack(color)) end
    end
    style.arrow:SetRotation(arrowRotation[direction])
    self:PaintButton(button)
    return button
end

function T:MenuBackdrop(menu)
    local paint = menuSurfaces[menu]
    if not paint then
        paint = self:ControlSurface(menu)
        menuSurfaces[menu] = paint
        ns:TrackAppearance(menu, "state", function() paint(self.bg, self.line) end)
    end
    paint(self.bg, self.line)
end

function T:MenuHighlight(row)
    local art = row:CreateTexture(nil, "BACKGROUND")
    art:SetAllPoints()
    ns:Tint(art, "SetColorTexture", self.accentDim)
    art:Hide()
    return art
end

local menuInset = { left = 6, right = 6, top = 5, bottom = 5 }
local menuPadding = { width = 0, height = 0 }
local menuStyle = {}
function menuStyle:GetInset() return menuInset end
function menuStyle:GetChildExtentPadding() return menuPadding end
function menuStyle:Generate()
    local background = self:AttachTexture()
    local border = self:AttachTexture()
    background:SetDrawLayer("BACKGROUND", -2)
    border:SetDrawLayer("BACKGROUND", -1)
    border:SetAllPoints()
    if RoundTexture(background, "control-fill.tga") and RoundTexture(border, "slate-bevel.tga") then
        background:SetAllPoints()
        background:SetVertexColor(unpack(T.bg))
        border:SetVertexColor(unpack(T.line))
    else
        border:SetDrawLayer("BACKGROUND", -3)
        background:SetPoint("TOPLEFT", 1, -1)
        background:SetPoint("BOTTOMRIGHT", -1, 1)
        background:SetColorTexture(unpack(T.bg))
        border:SetColorTexture(unpack(T.line))
    end
end

function T:OpenMenu(owner, build)
    if not (owner and MenuUtil and MenuUtil.CreateContextMenu) then return end
    local previous = owner.menuMixin
    owner.menuMixin = menuStyle
    local ok, menu = pcall(MenuUtil.CreateContextMenu, owner, function(button, root)
        build(button, root)
        if not MenuUtil.TraverseMenu then return end
        -- Blizzard's menu compositor owns the font strings and blocks SetFont.
        MenuUtil.TraverseMenu(root, function(entry)
            entry:AddInitializer(function(row)
                if row.highlight then
                    row.highlight:SetBlendMode("BLEND")
                    row.highlight:SetColorTexture(unpack(self.accentDim))
                end
            end)
        end)
    end)
    owner.menuMixin = previous
    if not ok then error(menu, 0) end
    return menu
end
