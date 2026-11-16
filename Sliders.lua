local _, ns = ...
local T = ns.Settings
local trackHeight, thumbWidth, thumbHeight = 4, 12, 12

function T:SkinSlider(slider, palette)
    local trackColor = palette and palette.line or self.sliderTrack
    local thumbColor = palette and palette.fg or self.sliderThumb
    local accent = palette and palette.accent or self.accent

    local track = CreateFrame("Frame", nil, slider)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetHeight(trackHeight)
    local trackArt = track:CreateTexture(nil, "BACKGROUND")
    trackArt:SetAllPoints()
    ns:Tint(trackArt, "SetColorTexture", trackColor)

    local fill = CreateFrame("Frame", nil, slider)
    fill:SetFrameLevel(track:GetFrameLevel() + 1)
    fill:SetPoint("LEFT", track)
    fill:SetHeight(trackHeight)
    local fillArt = fill:CreateTexture(nil, "ARTWORK")
    fillArt:SetAllPoints()
    local function PaintFill(target) target:SetColorTexture(accent[1], accent[2], accent[3], .20) end
    PaintFill(fillArt)
    ns:TrackAppearance(fillArt, "SetColorTexture", PaintFill)

    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(ns.media .. "slider-knob.png")
    thumb:SetAlpha(0)
    thumb:SetSize(thumbWidth, thumbHeight)
    slider:SetThumbTexture(thumb)
    local face = CreateFrame("Frame", nil, slider)
    face:SetFrameLevel(fill:GetFrameLevel() + 1)
    face:SetAllPoints(slider)
    local knob = face:CreateTexture(nil, "ARTWORK")
    knob:SetTexture(ns.media .. "slider-knob.png")
    knob:SetPoint("CENTER", thumb)

    local motion = ns:AnimateControl(face, function(pressed, hover)
        local expansion = 1.5 * hover - 1.5 * pressed
        knob:SetSize(thumbWidth + expansion, thumbHeight + expansion)
        knob:SetVertexColor(
            thumbColor[1] + (accent[1] - thumbColor[1]) * hover,
            thumbColor[2] + (accent[2] - thumbColor[2]) * hover,
            thumbColor[3] + (accent[3] - thumbColor[3]) * hover, 1)
    end)

    local hovered, pressed
    local function Feedback(seconds)
        motion(pressed and 1 or 0, (pressed or hovered) and 1 or 0, seconds)
    end
    slider:HookScript("OnEnter", function()
        hovered = true
        Feedback(.12)
    end)
    slider:HookScript("OnLeave", function()
        hovered, pressed = nil, nil
        Feedback(.10)
    end)
    slider:HookScript("OnMouseDown", function(_, key)
        if key ~= "LeftButton" then return end
        pressed = true
        Feedback(.09)
    end)
    slider:HookScript("OnMouseUp", function(_, key)
        if key ~= "LeftButton" then return end
        pressed = nil
        Feedback(.12)
    end)
    local function Reset()
        hovered, pressed = nil, nil
        Feedback()
    end
    slider:HookScript("OnHide", Reset)
    ns:TrackAppearance(face, "state", function() Feedback() end)
    Reset()

    local function UpdateFill()
        local low, high = slider:GetMinMaxValues()
        local fraction = high > low and math.max(0, math.min(1, (slider:GetValue() - low) / (high - low))) or 0
        local width = slider:GetWidth()
        local inset = math.min(thumbWidth / 2, width / 2)
        fill:SetShown(fraction > 0 and width > 0)
        if fraction > 0 and width > 0 then fill:SetWidth(inset + fraction * (width - 2 * inset)) end
    end
    slider:HookScript("OnValueChanged", UpdateFill)
    slider:HookScript("OnSizeChanged", UpdateFill)
    UpdateFill()
    return UpdateFill
end

function T:ScrollTrack(frame, color)
    local art = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
    art:SetPoint("TOP", frame, "TOP")
    art:SetPoint("BOTTOM", frame, "BOTTOM")
    art:SetWidth(4)
    ns:Tint(art, "SetColorTexture", color or self.scrollTrack)
    return art
end

function T:ScrollThumbArt(thumb, color)
    thumb:SetTexture(ns.media .. "slider-knob.png")
    thumb:SetTexCoord(0, 1, 0, 1)
    ns:Tint(thumb, "SetVertexColor", color or self.scrollThumb)
end

function T:SkinScrollBar(slider, width, height)
    self:ScrollTrack(slider)
    local thumb = slider:GetThumbTexture()
    if not thumb then
        thumb = slider:CreateTexture(nil, "ARTWORK")
        slider:SetThumbTexture(thumb)
    end
    self:ScrollThumbArt(thumb)
    thumb:SetSize(width, height)
end

function T:SkinScrollArrow(button, up)
    if not button then return end
    for _, state in ipairs({ "Normal", "Pushed", "Highlight", "Disabled" }) do
        local tint = state == "Disabled" and self.dim or (state == "Normal" and self.brass or self.accent)
        local art = self:Glyph(button, "chevron", 10, tint)
        art:SetDrawLayer(state == "Highlight" and "HIGHLIGHT" or "ARTWORK")
        art:SetPoint("CENTER")
        art:SetRotation(up and math.pi / 2 or -math.pi / 2)
        button["Set" .. state .. "Texture"](button, art)
    end
end

function T:AttachScrollBar(scroll, parent, wheelStep)
    local bar = CreateFrame("Slider", nil, parent)
    bar:SetOrientation("VERTICAL")
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(false)
    bar:SetWidth(9)
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 4, 0)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 4, 0)
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)
    self:SkinScrollBar(bar, 6, 28)

    local syncing
    function scroll:RefreshRange(verticalRange)
        if syncing then return end
        syncing = true
        if verticalRange == nil and self.UpdateScrollChildRect then
            self:UpdateScrollChildRect()
        end
        local range = math.max(0, verticalRange or self:GetVerticalScrollRange() or 0)
        local offset = math.min(range, self:GetVerticalScroll())
        bar:SetMinMaxValues(0, range)
        bar:SetValue(offset)
        syncing = nil
        if offset ~= self:GetVerticalScroll() then self:SetVerticalScroll(offset) end
        local visible = self:IsShown() and range > .5
        bar:SetShown(visible)
        bar:EnableMouse(visible)
    end
    bar:SetScript("OnValueChanged", function(_, value)
        if not syncing then scroll:SetVerticalScroll(value) end
    end)
    scroll:HookScript("OnVerticalScroll", function(_, value)
        if syncing or bar:GetValue() == value then return end
        syncing = true
        bar:SetValue(value)
        syncing = nil
    end)
    scroll:HookScript("OnScrollRangeChanged", function(self, _, verticalRange)
        self:RefreshRange(verticalRange)
    end)
    scroll:HookScript("OnShow", function(self) self:RefreshRange() end)
    scroll:HookScript("OnHide", function()
        bar:Hide()
        bar:EnableMouse(false)
    end)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        local _, range = bar:GetMinMaxValues()
        if range > 0 then
            bar:SetValue(math.max(0, math.min(range, bar:GetValue() - delta * (wheelStep or 42))))
        end
    end)
    scroll.bar = bar
    scroll:RefreshRange()
    return bar
end
