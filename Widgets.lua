local _, ns = ...
local english = ns:GetLocale() == "enUS"
local function Text(russian, translation) return english and translation or russian end

function ns:CreateWidgets(T)
    local W = {
        PAGE_INSET = 16,
        CARD_INSET = 14,
        CONTROL_INSET = 8,
    }

    T = T or self.Settings

    function W:CloseColorPicker(owner, force)
        if owner and self.activeColorPickerOwner ~= owner then return end
        if not owner and not force and not self.activeColorPickerOwner then return end
        self.activeColorPickerOwner = nil
        local dandersPicker = _G.DFColorPickerTest
        if dandersPicker and dandersPicker.IsShown and dandersPicker:IsShown() then
            pcall(dandersPicker.Hide, dandersPicker)
        end
        local picker = ColorPickerFrame
        if not picker or not picker.IsShown or not picker:IsShown() then return end
        local cancel = picker.Footer and picker.Footer.CancelButton
        if cancel and cancel.Click then
            pcall(cancel.Click, cancel)
            if not picker:IsShown() then return end
        end
        pcall(picker.Hide, picker)
    end

    function W:PrepareColorPicker()
        self:CloseColorPicker(nil, true)
        local picker = ColorPickerFrame
        if not picker then return nil end

        -- Other addons may use the Blizzard picker as a hidden backend and leave
        -- scale, alpha, mouse state or anchors altered when their custom picker is
        -- interrupted. Reset the Blizzard picker before opening it again.
        pcall(picker.Hide, picker)
        if picker.SetScale then pcall(picker.SetScale, picker, 1) end
        if picker.SetAlpha then pcall(picker.SetAlpha, picker, 1) end
        if picker.EnableMouse then pcall(picker.EnableMouse, picker, true) end
        if picker.RegisterEvent then pcall(picker.RegisterEvent, picker, "GLOBAL_MOUSE_DOWN") end
        if picker.ClearAllPoints and picker.SetPoint then
            pcall(picker.ClearAllPoints, picker)
            pcall(picker.SetPoint, picker, "CENTER", UIParent, "CENTER", 0, 0)
        end
        if picker.SetFrameStrata then pcall(picker.SetFrameStrata, picker, "FULLSCREEN_DIALOG") end
        if picker.SetClampedToScreen then pcall(picker.SetClampedToScreen, picker, true) end

        if not self.colorPickerHideHooked and picker.HookScript then
            picker:HookScript("OnHide", function()
                W.activeColorPickerOwner = nil
            end)
            self.colorPickerHideHooked = true
        end
        return picker
    end

    function W:GetDandersColorPicker()
        local danders = _G.DandersFrames
        local gui = danders and danders.GUI
        if not gui or type(gui.OpenColorPicker) ~= "function" or type(danders.GetGlobalDB) ~= "function" then
            return nil
        end

        local ok, db = pcall(danders.GetGlobalDB, danders)
        if not ok or type(db) ~= "table" or not db.colorPickerGlobalOverride then
            return nil
        end
        return gui
    end

    function W:OpenColorPicker(owner, initialColor, hasAlpha, onChange, onCancel)
        self:CloseColorPicker(nil, true)

        -- DandersFrames' global override opens Blizzard's picker as an invisible
        -- backend. On current Retail its Cancel button may leave that backend shown
        -- after the custom window closes. Its public direct API provides the same UI
        -- without creating the Blizzard backend.
        local dandersGUI = self:GetDandersColorPicker()
        if dandersGUI then
            self.activeColorPickerOwner = owner
            local function Finish(color)
                if color and onChange then onChange(color) end
                if self.activeColorPickerOwner == owner then self.activeColorPickerOwner = nil end
            end
            local function Cancel()
                if onCancel then onCancel() end
                if self.activeColorPickerOwner == owner then self.activeColorPickerOwner = nil end
            end
            local ok = pcall(dandersGUI.OpenColorPicker, dandersGUI, initialColor, hasAlpha, Finish, Cancel, onChange)
            if ok then return true end
            self.activeColorPickerOwner = nil
        end

        local picker = self:PrepareColorPicker()
        if not picker or not picker.SetupColorPickerAndShow then return false end
        local function Changed()
            local r, g, b = picker:GetColorRGB()
            local a = hasAlpha and picker.GetColorAlpha and picker:GetColorAlpha() or (initialColor.a or 1)
            if onChange then onChange({ r = r, g = g, b = b, a = a }) end
        end
        local function Cancel()
            if onCancel then onCancel() end
            if self.activeColorPickerOwner == owner then self.activeColorPickerOwner = nil end
        end
        self.activeColorPickerOwner = owner
        local ok = pcall(picker.SetupColorPickerAndShow, picker, {
            r = initialColor.r,
            g = initialColor.g,
            b = initialColor.b,
            opacity = initialColor.a or 1,
            hasOpacity = hasAlpha,
            swatchFunc = Changed,
            opacityFunc = hasAlpha and Changed or nil,
            cancelFunc = Cancel,
        })
        if not ok then self.activeColorPickerOwner = nil end
        return ok
    end

    local function Shift(color, amount, alpha)
        return { math.min(1, color[1] + amount), math.min(1, color[2] + amount), math.min(1, color[3] + amount), alpha or color[4] or 1 }
    end

    function W:Label(parent, text, size, color, role)
        local fs = parent:CreateFontString(nil, "OVERLAY")
        T:Font(fs, size or 11, "", color or T.text, role)
        fs:SetText(text or "")
        fs:SetJustifyH("LEFT")
        return fs
    end

    function W:Help(row, description, label)
        return ns:AttachHelp(row, T, description, label)
    end

    function W:Page(parent)
        local page = CreateFrame("Frame", nil, parent)
        page:SetAllPoints()
        local canvas = CreateFrame("Frame", nil, page)
        canvas:SetPoint("TOPLEFT", page, "TOPLEFT", self.PAGE_INSET, 0)
        canvas:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -self.PAGE_INSET, 0)
        page.canvas = canvas
        return page, canvas
    end
    function W:Card(parent, title, description, headingIcon)
        local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        T:PanelSurface(card)
        card.title = self:Label(card, title, 13, headingIcon and T.brass or T.text, "display")
        if headingIcon then
            local band = card:CreateTexture(nil, "BACKGROUND", nil, 3)
            band:SetPoint("TOPLEFT", 7, -6)
            band:SetPoint("TOPRIGHT", -7, -6)
            band:SetHeight(21)
            local function PaintHeading(target)
                local r, g, b, a = unpack(T.cardHeading)
                target:SetColorTexture(r, g, b, a)
                if target.SetGradient and CreateColor then
                    target:SetColorTexture(1, 1, 1, 1)
                    target:SetGradient("HORIZONTAL", CreateColor(r, g, b, a), CreateColor(r, g, b, .06))
                end
            end
            PaintHeading(band)
            ns:TrackAppearance(band, "state", PaintHeading)
            local glyph = T:Glyph(card, headingIcon, 14)
            glyph:SetPoint("LEFT", band, "LEFT", 5, 0)
            card.title:SetPoint("LEFT", glyph, "RIGHT", 4, 0)
            card.title:SetPoint("RIGHT", band, "RIGHT", -6, 0)
            card.title:SetWordWrap(false)
        else
            card.title:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -12)
        end
        card.description = self:Label(card, description, 10, T.muted)
        card.description:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -3)
        card.description:SetWidth(1)
        card.description:SetWordWrap(true)
        card:HookScript("OnSizeChanged", function(_, width)
            card.description:SetWidth(math.max(1, width - 28))
        end)
        return card
    end

    function W:Section(parent, title, description)
        local section = CreateFrame("Frame", nil, parent)
        section.title = self:Label(section, string.upper(title or ""), 9, T.muted)
        section.title:SetPoint("TOPLEFT", section, "TOPLEFT", 0, -4)
        local line = section:CreateTexture(nil, "ARTWORK")
        ns:Tint(line, "SetColorTexture", T.lineSoft)
        line:SetPoint("LEFT", section.title, "RIGHT", 10, 0)
        line:SetWidth(1)
        line:SetHeight(1)
        section.description = self:Label(section, description or "", 9, T.muted)
        section.description:SetPoint("TOPLEFT", section.title, "BOTTOMLEFT", 0, -5)
        section.description:SetWidth(1)
        section.description:SetWordWrap(true)
        section.description:SetShown(description ~= nil and description ~= "")
        if section.description:IsShown() then
            -- Reserve two compact lines everywhere.  Column widths are resolved
            -- after construction, so measuring the FontString here is unreliable.
            section.description:SetHeight(22)
            section.description:SetJustifyV("TOP")
        end
        section.headerHeight = section.description:IsShown() and 48 or 25
        section:HookScript("OnSizeChanged", function(_, width)
            line:SetWidth(math.max(1, width - section.title:GetStringWidth() - 10))
            section.description:SetWidth(math.max(1, width))
        end)
        return section
    end

    function W:SetAvailable(widget, available)
        if widget and widget.SetAvailable then widget:SetAvailable(available ~= false) end
    end

    function W:Button(parent, text, onClick, accent, palette)
        local style = palette or T
        local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
        button:SetHeight(accent and 24 or 22)
        button.primary = accent
        button.text = self:Label(button, text, 11, style.text)
        button.text:SetPoint("LEFT", 6, 0)
        button.text:SetPoint("RIGHT", -6, 0)
        button.text:SetJustifyH("CENTER")
        button.text:SetWordWrap(false)
        button:SetScript("OnClick", onClick)
        T.SkinButton(style, button, button.text)
        return button
    end

    function W:CloseButton(parent, onClick, palette, quiet)
        local T = palette or T
        local controlTheme = ns.Settings
        local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
        button:SetSize(24, 24)
        local base = palette and { 0.02, 0.028, 0.034, 0.72 } or T.input
        local transparent = { 0, 0, 0, 0 }
        local paintSurface = controlTheme.ControlSurface(T, button)
        local paintGlyph = controlTheme.CloseGlyph(T, button)
        button:SetScript("OnClick", onClick)
        local hovered
        local function Paint()
            local background = hovered and T.panelHover or base
            local border = hovered and (T.brass or T.line) or (palette and T.lineSoft or T.line)
            if quiet and not hovered then background, border = transparent, transparent end
            paintSurface(background, border)
            paintGlyph(hovered and T.text or T.muted)
        end
        button:SetScript("OnEnter", function(self) hovered = true; Paint(self) end)
        button:SetScript("OnLeave", function(self) hovered = nil; Paint(self) end)
        button:SetScript("OnHide", function(self) hovered = nil; Paint(self) end)
        ns:TrackAppearance(button, "state", Paint)
        Paint(button)
        return button
    end

    function W:WindowHeader(window, options)
        local header = CreateFrame("Frame", nil, window, "BackdropTemplate")
        header:SetPoint("TOPLEFT", window, "TOPLEFT", 1, -1)
        header:SetPoint("TOPRIGHT", window, "TOPRIGHT", -1, -1)
        header:SetHeight(options.height or 46)
        T:HeaderSurface(header)

        local brand = CreateFrame("Frame", nil, header)
        brand:SetSize(30, 30)
        brand:SetPoint("LEFT", 13, 0)
        if options.glyph then
            local glyph = T:Glyph(brand, options.glyph, 17)
            glyph:SetPoint("CENTER")
        else
            local icon = brand:CreateTexture(nil, "ARTWORK")
            icon:SetPoint("TOPLEFT", 2, -2)
            icon:SetPoint("BOTTOMRIGHT", -2, 2)
            icon:SetTexture(options.icon)
        end

        local watermarkAsset = options.watermark
        if watermarkAsset == nil and (options.height or 46) >= 60 then watermarkAsset = options.icon end
        if watermarkAsset then
            local watermark = header:CreateTexture(nil, "BACKGROUND", nil, 4)
            watermark:SetTexture(watermarkAsset)
            local size = math.min(header:GetHeight() - 4, 66)
            watermark:SetSize(size, size)
            watermark:SetPoint("RIGHT", -70, 0)
            ns:Tint(watermark, "SetVertexColor", T.muted, .13)
        end

        if options.close ~= false then
            header.close = self:CloseButton(header, options.onClose or function() window:Hide() end, nil, true)
            header.close:SetPoint("RIGHT", -8, 0)
        end
        local endAnchor = header.close or header
        local endPoint = header.close and "LEFT" or "RIGHT"

        local hasSubtitle = options.subtitle and options.subtitle ~= ""
        local titleSize = options.titleSize or 16
        local title = self:Label(header, options.title, titleSize, T.text, "display")
        title:SetHeight(titleSize + 4)
        title:SetPoint("LEFT", brand, "RIGHT", 10, hasSubtitle and 6 or 0)
        title:SetWordWrap(false)
        header.title = title
        if options.version then
            local version = self:Label(header, "v" .. options.version, 9, T.muted)
            version:SetPoint("LEFT", title, "RIGHT", 10, -1)
        else
            title:SetPoint("RIGHT", endAnchor, endPoint, -12, 0)
        end
        if options.subtitle then
            local subtitle = self:Label(header, options.subtitle, 10, T.muted)
            subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, 1)
            subtitle:SetPoint("RIGHT", endAnchor, endPoint, -12, 0)
            subtitle:SetWordWrap(false)
            header.subtitle = subtitle
        end
        return header
    end

    function W:ScrollFrame(parent, body, wheelStep)
        local scroll = CreateFrame("ScrollFrame", nil, parent, "BackdropTemplate")
        if body then body:SetParent(scroll) else
            body = CreateFrame("Frame", nil, scroll)
            body:SetSize(1, 1)
        end
        scroll:SetScrollChild(body)

        local bar = T:AttachScrollBar(scroll, parent, wheelStep)
        bar:ClearAllPoints()
        body:HookScript("OnSizeChanged", function()
            C_Timer.After(0, function() scroll:RefreshRange() end)
        end)
        scroll.body = body
        return scroll, body, bar
    end
    function W:Toggle(parent, labelText, getValue, setValue, description, setterRefreshesEvents, layout)
        local inline = layout == "inline"
        local row = CreateFrame("Button", nil, parent, inline and "BackdropTemplate" or nil)
        row:SetHeight(28)
        row.label = self:Label(row, labelText, 11, T.text)
        local labelY = description and 9 or 0
        local trackWidth, inset = 32, self.CONTROL_INSET
        local labelInset = trackWidth + 2 * inset
        row.label:SetPoint("LEFT", row, "LEFT", inline and labelInset or 0, labelY)
        row.label:SetPoint("RIGHT", row, "RIGHT", inline and -inset or -labelInset, labelY)
        if description then
            row:SetHeight(46)
            local detail = self:Label(row, description, 10, T.muted)
            detail:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -4)
            detail:SetPoint("RIGHT", row.label, "RIGHT")
            detail:SetWordWrap(true)
            row.detail = detail
        end

        local track = CreateFrame("Frame", nil, row)
        track:SetSize(trackWidth, 16)
        local side = inline and "LEFT" or "RIGHT"
        track:SetPoint(side, row, side, inline and inset or -inset, 0)
        local function IsOn() return getValue() == true end
        local sync, knob = T:SkinToggle(row, track, IsOn)
        row.track, row.knob = track, knob

        local function PaintInline()
            local selected = IsOn()
            local fill = selected and T.accentDim or T.input
            if row.hovered and row.available then fill = Shift(fill, .035) end
            row:SetBackdropColor(unpack(fill))
            row:SetBackdropBorderColor(unpack(selected and T.accentLine or T.lineSoft))
        end
        if inline then
            T:Backdrop(row, T.input, T.lineSoft)
            row:HookScript("OnEnter", function() row.hovered = true; PaintInline() end)
            row:HookScript("OnLeave", function() row.hovered = nil; PaintInline() end)
            row:HookScript("OnHide", function() row.hovered = nil; PaintInline() end)
            ns:TrackAppearance(row, "state", PaintInline)
        end

        function row:Refresh(animate)
            if inline then PaintInline() end
            sync(animate ~= false)
        end

        row:SetScript("OnClick", function()
            if not row.available then return end
            setValue(not IsOn())
            if W.onToggle and not setterRefreshesEvents then W.onToggle() end
            row:Refresh()
        end)
        row:HookScript("OnShow", function(self) self:Refresh(false) end)
        function row:SetAvailable(available)
            self.available = available ~= false
            self:SetEnabled(self.available)
            self:SetAlpha((self.available or self.detail) and 1 or .38)
            if self.detail then
                self.label:SetAlpha(self.available and 1 or .62)
                self.track:SetAlpha(self.available and 1 or .46)
            end
            if not self.available then sync(false) end
            if inline then PaintInline() end
        end
        row:SetAvailable(true)
        row:Refresh()
        return row
    end

    function W:BindAvailability(row, check)
        local refresh = row.Refresh
        local detail = row.detail and row.detail:GetText()
        function row:Refresh(...)
            local available, reason = check()
            self:SetAvailable(available == true)
            self.unavailableReason = not available and reason or nil
            if self:GetObjectType() == "Frame" then self:EnableMouse(self.unavailableReason ~= nil) end
            if not self.unavailableReason and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
            if self.detail then
                self.detail:SetText(self.unavailableReason or detail)
                self.detail:SetTextColor(unpack(self.unavailableReason and T.warning or T.muted))
            end
            if refresh then return refresh(self, ...) end
        end
        if row.SetMotionScriptsWhileDisabled then row:SetMotionScriptsWhileDisabled(true) end
        row:HookScript("OnEnter", function(self)
            if not self.unavailableReason then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.unavailableReason, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        row:HookScript("OnLeave", function(self)
            if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        end)
        row:Refresh()
        return row
    end

    function W:Segmented(parent, labels, values, getValue, setValue, strip)
        local frame = CreateFrame("Frame", nil, parent)
        frame:SetHeight(strip and 32 or 28)
        if strip then
            local line = frame:CreateTexture(nil, "BACKGROUND")
            line:SetPoint("BOTTOMLEFT")
            line:SetPoint("BOTTOMRIGHT")
            line:SetHeight(1)
            ns:SnapTexture(line)
            ns:Tint(line, "SetColorTexture", T.lineSoft)
        end
        frame.buttons = {}
        for index, labelText in ipairs(labels) do
            local button = CreateFrame("Button", nil, frame, "BackdropTemplate")
            button.value = values[index]
            button.text = self:Label(button, labelText, 10, T.muted)
            if strip then
                button.text:SetPoint("LEFT", 4, 1)
                button.text:SetPoint("RIGHT", -4, 1)
                button.text:SetJustifyH("CENTER")
                button.text:SetWordWrap(false)
            else
                button.text:SetPoint("CENTER", 0, 1)
            end
            T:SkinTab(button, button.text, 10)
            button:SetScript("OnClick", function(self) setValue(self.value); frame:Refresh() end)
            frame.buttons[index] = button
        end
        function frame:Refresh()
            local count = #self.buttons
            local inset = strip and 0 or 2
            local width = math.max(1, (self:GetWidth() - 2 * inset - (count - 1) * 2) / count)
            if strip then width = math.min(138, width) end
            for index, button in ipairs(self.buttons) do
                button:ClearAllPoints()
                button:SetPoint("TOP", self, "TOP", 0, -2); button:SetPoint("BOTTOM", self, "BOTTOM", 0, 2); button:SetWidth(width)
                if index == 1 then button:SetPoint("LEFT", self, "LEFT", inset, 0) else button:SetPoint("LEFT", self.buttons[index - 1], "RIGHT", 2, 0) end
                T:PaintButton(button, button.value == getValue())
            end
        end
        frame:HookScript("OnSizeChanged", function(self) self:Refresh() end)
        return frame
    end

    function W:ColorSwatch(parent, labelText, getValue, setValue)
        local row = CreateFrame("Button", nil, parent)
        row:SetHeight(26)
        row.label = self:Label(row, labelText, 11, T.text)
        row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
        local swatch = CreateFrame("Frame", nil, row, "BackdropTemplate")
        swatch:SetSize(28, 16)
        swatch:SetPoint("RIGHT", row, "RIGHT", -self.CONTROL_INSET, 0)
        T:Backdrop(swatch, { 1, 1, 1, 1 }, T.line)
        function row:Refresh()
            local color = getValue()
            local r, g, b, a = color.r or color[1], color.g or color[2], color.b or color[3], color.a or color[4] or 1
            swatch:SetBackdropColor(r, g, b, a); swatch:SetBackdropBorderColor(unpack(T.line))
        end
        row:SetScript("OnClick", function()
            local current = getValue()
            local old = { r = current.r or current[1], g = current.g or current[2], b = current.b or current[3], a = current.a or current[4] or 1 }
            W:OpenColorPicker(row, old, false,
                function(color) setValue(color.r, color.g, color.b); row:Refresh() end,
                function() setValue(old.r, old.g, old.b); row:Refresh() end)
        end)
        row:HookScript("OnHide", function() W:CloseColorPicker(row) end)
        row:Refresh()
        return row
    end

    function W:SettingRow(parent, labelText, height)
        local row = CreateFrame("Frame", nil, parent)
        row:SetHeight(height or 30)
        row.label = self:Label(row, labelText, 10, T.text)
        row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.label:SetPoint("RIGHT", row, "RIGHT", -210, 0)
        row.labelText = labelText
        return row
    end

    function W:SetInputError(row, message)
        row.label:SetText(message or row.labelText)
        row.label:SetTextColor(unpack(message and T.warning or T.text))
    end

    function W:SliderRow(parent, labelText, minimum, maximum, step, getValue, setValue, suffix)
        local row = self:SettingRow(parent, labelText)
        local slider = CreateFrame("Slider", nil, row)
        slider:SetPoint("RIGHT", row, "RIGHT", -48, 0)
        slider:SetSize(130, 22)
        slider:SetOrientation("HORIZONTAL")
        slider:SetMinMaxValues(minimum, maximum)
        slider:SetValueStep(step)
        slider:SetObeyStepOnDrag(true)
        local edit = CreateFrame("EditBox", nil, row, "BackdropTemplate")
        edit:SetPoint("LEFT", slider, "RIGHT", 7, 0)
        edit:SetSize(40, 22)
        edit:SetAutoFocus(false)
        edit:SetJustifyH("CENTER")
        local editFill = edit:CreateTexture(nil, "BACKGROUND")
        editFill:SetTexture(ns.media .. "number-fill.png")
        editFill:SetAllPoints()
        ns:Tint(editFill, "SetVertexColor", T.input)
        local editEdge = edit:CreateTexture(nil, "BORDER")
        editEdge:SetTexture(ns.media .. "number-border.png")
        editEdge:SetAllPoints()
        ns:Tint(editEdge, "SetVertexColor", T.lineSoft)
        T:Font(edit, 9, "", T.text)
        local busy
        local function Normalize(value)
            value = math.max(minimum, math.min(maximum, tonumber(value) or minimum))
            return math.max(minimum, math.min(maximum, math.floor(value / step + .5) * step))
        end
        local function Format(value)
            return ("%g%s"):format(value, suffix or "")
        end
        slider:SetScript("OnValueChanged", function(_, value)
            if busy then return end
            value = Normalize(value)
            W:SetInputError(row)
            setValue(value)
            edit:SetText(edit:HasFocus() and ("%g"):format(value) or Format(value))
        end)
        local updateFill = T:SkinSlider(slider)
        slider.stepFromKeyboard = function(direction)
            slider:SetValue(Normalize(slider:GetValue() + direction * step))
        end
        edit:SetScript("OnEnterPressed", function(self)
            local text = self:GetText()
            if suffix and text:sub(-#suffix) == suffix then text = text:sub(1, -#suffix - 1) end
            local value = tonumber(text)
            self:ClearFocus()
            if not value then
                row:Refresh()
                W:SetInputError(row, Text("Введите число", "Enter a number"))
                return
            end
            W:SetInputError(row)
            slider:SetValue(Normalize(value))
            row:Refresh()
        end)
        edit:SetScript("OnEditFocusGained", function()
            edit:SetText(("%g"):format(Normalize(getValue())))
            ns:Tint(editEdge, "SetVertexColor", T.accentLine)
            W:SetInputError(row)
        end)
        edit:SetScript("OnEditFocusLost", function()
            ns:Tint(editEdge, "SetVertexColor", T.lineSoft)
            row:Refresh()
        end)
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        self:EnableSettingsTab(edit)
        function row:SetRange(low, high)
            if low == minimum and high == maximum then return end
            minimum, maximum = low, high
            busy = true
            slider:SetMinMaxValues(low, high)
            updateFill()
            busy = nil
        end
        function row:Refresh()
            busy = true
            local value = Normalize(getValue())
            slider:SetValue(value)
            updateFill()
            if not edit:HasFocus() then edit:SetText(Format(value)) end
            busy = nil
        end
        function row:SetAvailable(available)
            self.available = available ~= false
            self:SetAlpha(self.available and 1 or .38)
            if slider.SetEnabled then slider:SetEnabled(self.available) else slider:EnableMouse(self.available) end
            if edit.SetEnabled then edit:SetEnabled(self.available) else edit:EnableMouse(self.available) end
            if not self.available then edit:ClearFocus() end
        end
        row.slider, row.edit = slider, edit
        row:SetAvailable(true)
        row:Refresh()
        return row
    end

    local function ResolveChoices(choices) return type(choices) == "function" and choices() or choices end

    local function OrderedKeys(options, preferred)
        local keys = {}
        for key in pairs(options) do keys[#keys + 1] = key end
        table.sort(keys, function(a, b)
            local aOrder, bOrder = preferred and tonumber(preferred[a]), preferred and tonumber(preferred[b])
            if aOrder ~= bOrder then return (aOrder or math.huge) < (bOrder or math.huge) end
            return tostring(options[a]) < tostring(options[b])
        end)
        return keys
    end

    local function StepChoice(choices, current, direction)
        for index, choice in ipairs(choices) do
            if choice == current then return choices[(index + direction - 1) % #choices + 1] end
        end
        return choices[direction > 0 and 1 or #choices]
    end

    function W:OpenChoiceMenu(owner, choices, getValue, setValue, preferred)
        local options = ResolveChoices(choices) or {}
        local keys = OrderedKeys(options, preferred)
        if #keys == 0 then return end
        local entries = {}
        for index, key in ipairs(keys) do entries[index] = { value = key, label = options[key] } end
        T:OpenPicker(owner, entries, getValue(), function(value)
            setValue(value)
            if owner.RefreshOwner then owner:RefreshOwner() end
        end)
    end

    function W:ChoiceRow(parent, labelText, choices, getValue, setValue, preferred, valuePrefix)
        local row = self:SettingRow(parent, labelText)
        local button
        button = self:Button(row, "", function() W:OpenChoiceMenu(button, choices, getValue, setValue, preferred) end)
        T:DropdownArrow(button, button.text)
        button:SetSize(178, 22)
        button:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT")
        row.label:SetPoint("RIGHT", button, "LEFT", -8, 0)
        button.stepFromKeyboard = function(direction)
            local value = StepChoice(OrderedKeys(ResolveChoices(choices) or {}, preferred), getValue(), direction)
            if value ~= nil then setValue(value); row:Refresh() end
        end
        function row:Refresh()
            local options = ResolveChoices(choices) or {}
            local value = getValue()
            button.text:SetText((valuePrefix or "") .. tostring(options[value] or value or "—"))
        end
        button.RefreshOwner = function() row:Refresh() end
        row.button = button
        function row:SetAvailable(available)
            self.available = available ~= false
            self:SetAlpha(self.available and 1 or .38)
            button:SetEnabled(self.available)
            if not self.available then T:ClosePicker(button) end
        end
        row:SetAvailable(true)
        row:Refresh()
        return row
    end

    -- One compact selector for visual assets.  The popup carries the names while
    -- the selected texture/border stays visible in a real preview.  It replaces
    -- the old grids so adding media no longer grows the settings page.
    function W:VisualChoiceRow(parent, labelText, choices, getValue, setValue, config)
        config = type(config) == "table" and config or {}
        local previewOnly = config.previewOnly == true
        local row = self:SettingRow(parent, labelText, 34)
        local button = self:Button(row, "", function() row:OpenMenu() end)
        T:DropdownArrow(button, button.text)
        button:SetSize(132, 24)
        if previewOnly then button:Hide() else button:SetPoint("RIGHT", row, "RIGHT", 0, 0) end

        local preview = CreateFrame("Button", nil, row, "BackdropTemplate")
        preview:SetSize(previewOnly and (tonumber(config.previewWidth) or 230) or 92, 24)
        if previewOnly then preview:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        else preview:SetPoint("RIGHT", button, "LEFT", -6, 0) end
        T:Backdrop(preview, T.input, T.lineSoft)
        local sample = CreateFrame("Frame", nil, preview, "BackdropTemplate")
        sample:SetPoint("TOPLEFT", preview, "TOPLEFT", 4, -4)
        sample:SetPoint("BOTTOMRIGHT", preview, "BOTTOMRIGHT", -4, 4)
        local background = sample:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(.16, .18, .19, .92)
        local texture = sample:CreateTexture(nil, "ARTWORK")
        texture:SetAllPoints()
        texture:SetVertexColor(1, 1, 1, .88)
        if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false) end
        if texture.SetTexelSnappingBias then texture:SetTexelSnappingBias(0) end
        sample.edges = {}
        for index = 1, 4 do
            local edge = sample:CreateTexture(nil, "ARTWORK")
            edge:SetColorTexture(1, 1, 1, .88)
            sample.edges[index] = edge
        end
        sample.edges[1]:SetPoint("TOPLEFT"); sample.edges[1]:SetPoint("TOPRIGHT"); sample.edges[1]:SetHeight(1)
        sample.edges[2]:SetPoint("BOTTOMLEFT"); sample.edges[2]:SetPoint("BOTTOMRIGHT"); sample.edges[2]:SetHeight(1)
        sample.edges[3]:SetPoint("TOPLEFT", 0, -1); sample.edges[3]:SetPoint("BOTTOMLEFT", 0, 1); sample.edges[3]:SetWidth(1)
        sample.edges[4]:SetPoint("TOPRIGHT", 0, -1); sample.edges[4]:SetPoint("BOTTOMRIGHT", 0, 1); sample.edges[4]:SetWidth(1)

        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.label:SetPoint("RIGHT", preview, "LEFT", -10, 0)
        row.preview, row.sample, row.texture, row.button = preview, sample, texture, button

        local function Entries()
            local resolved = type(choices) == "function" and choices() or choices
            return type(resolved) == "table" and resolved or {}
        end

        local function SelectedEntry()
            local selected = getValue()
            for _, choice in ipairs(Entries()) do
                if choice.value == selected then return choice end
            end
        end

        local function ResetSample()
            sample:SetBackdrop(nil)
            texture:Hide()
            for _, edge in ipairs(sample.edges) do
                edge:Show()
                edge:SetColorTexture(1, 1, 1, .88)
            end
        end

        local function ApplyPreview(choice)
            ResetSample()
            if not choice then return end
            if choice.kind == "solid" then return end
            if choice.kind == "gradient" then
                if CreateColor then
                    local left, right = CreateColor(.28, .31, .33, .9), CreateColor(1, 1, 1, .95)
                    sample.edges[1]:SetGradient("HORIZONTAL", left, right)
                    sample.edges[2]:SetGradient("HORIZONTAL", left, right)
                end
                return
            end
            if choice.kind == "border" or (choice.kind == "texture" and choice.border == true) then
                for _, edge in ipairs(sample.edges) do edge:Hide() end
                if choice.texture then
                    sample:SetBackdrop({ edgeFile = choice.texture, edgeSize = 7 })
                    sample:SetBackdropBorderColor(1, 1, 1, .90)
                end
                return
            end
            for _, edge in ipairs(sample.edges) do edge:Hide() end
            texture:SetTexture(choice.texture)
            texture:SetShown(choice.texture ~= nil)
            if type(config.applyPreview) == "function" then
                config.applyPreview(sample, texture, choice)
            end
        end

        local function StepVisualChoice(entries, direction)
            local values = {}
            for index, choice in ipairs(entries) do values[index] = choice.value end
            local value = StepChoice(values, getValue(), direction)
            if value ~= nil then setValue(value); row:Refresh() end
        end

        function row:OpenMenu()
            if self.available == false then return end
            local entries = Entries()
            if #entries == 0 then return end
            local options = {}
            for index, choice in ipairs(entries) do
                options[index] = { value = choice.value, label = choice.title or tostring(choice.value) }
            end
            T:OpenPicker(previewOnly and preview or button, options, getValue(), function(value)
                setValue(value)
                row:Refresh()
            end)
        end

        function row:Refresh()
            local choice = SelectedEntry()
            button.text:SetText(choice and choice.title or "—")
            ApplyPreview(choice)
        end
        function row:SetAvailable(available)
            self.available = available ~= false
            self:SetAlpha(self.available and 1 or .38)
            button:SetEnabled(self.available)
            preview:SetEnabled(self.available)
            if not self.available then T:ClosePicker(previewOnly and preview or button) end
        end
        preview:SetScript("OnClick", function() row:OpenMenu() end)
        button.stepFromKeyboard = function(direction) StepVisualChoice(Entries(), direction) end
        preview.stepFromKeyboard = button.stepFromKeyboard
        preview.skipSettingsFocus = not previewOnly
        row:SetAvailable(true)
        row:Refresh()
        return row
    end

    function W:ColorRow(parent, labelText, getValue, setValue)
        local row = self:SettingRow(parent, labelText)
        local swatch = CreateFrame("Button", nil, row, "BackdropTemplate")
        swatch:SetSize(38, 20)
        swatch:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        T:Backdrop(swatch, { 1, 1, 1, 1 }, T.line)
        local function Parts(value)
            return value.r or value[1], value.g or value[2], value.b or value[3], value.a or value[4] or 1
        end
        function row:Refresh()
            local r, g, b, a = Parts(getValue())
            swatch:SetBackdropColor(r, g, b, a)
        end
        swatch:SetScript("OnClick", function()
            local r, g, b, a = Parts(getValue())
            local original = { r, g, b, a }
            W:OpenColorPicker(row, { r = r, g = g, b = b, a = a }, true,
                function(color) setValue({ color.r, color.g, color.b, color.a }); row:Refresh() end,
                function() setValue(original); row:Refresh() end)
        end)
        row:HookScript("OnHide", function() W:CloseColorPicker(row) end)
        row.swatch = swatch
        function row:SetAvailable(available)
            self.available = available ~= false
            self:SetAlpha(self.available and 1 or .38)
            swatch:SetEnabled(self.available)
        end
        row:SetAvailable(true)
        row:Refresh()
        return row
    end

    function W:ActionRow(parent, labelText, buttonText, callback, accent)
        local row = self:SettingRow(parent, labelText)
        local button = self:Button(row, buttonText, callback, accent)
        button:SetSize(132, 24)
        button:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.button = button
        function row:SetAvailable(available)
            self.available = available ~= false
            self:SetAlpha(self.available and 1 or .38)
            button:SetEnabled(self.available)
        end
        row:SetAvailable(true)
        return row
    end

    function W:Confirm(text, callback, owner)
        StaticPopupDialogs.SINTEZZA_UI_CONFIRM = {
            text = "%s", button1 = Text("Подтвердить", "Confirm"), button2 = Text("Отмена", "Cancel"),
            OnShow = owner and function(dialog)
                dialog:SetFrameStrata(owner:GetFrameStrata())
                dialog:Raise()
            end or nil,
            OnAccept = function(_, data) if data then data() end end,
            timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        }
        StaticPopup_Show("SINTEZZA_UI_CONFIRM", text, nil, callback)
    end

    function W:EditBox(parent, placeholder, onCommit)
        local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
        box:SetHeight(28)
        box:SetAutoFocus(false)
        box:SetTextInsets(10, 10, 0, 0)
        T:Backdrop(box, T.input, T.line)
        T:Font(box, 11, "", T.text)
        box.placeholder = self:Label(box, placeholder, 10, T.muted)
        box.placeholder:SetPoint("LEFT", box, "LEFT", 10, 0)
        box:SetScript("OnTextChanged", function(self) self.placeholder:SetShown(self:GetText() == "") end)
        box:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(T.accent[1], T.accent[2], T.accent[3], 0.55) end)
        box:SetScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(unpack(T.line)) end)
        box:SetScript("OnEnterPressed", function(self) onCommit(self:GetText()); self:SetText(""); self:ClearFocus() end)
        box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        self:EnableSettingsTab(box)
        return box
    end

    function W:NavButton(parent, text, pageKey, onClick, iconKey)
        local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
        button:SetHeight(27)
        local wash = button:CreateTexture(nil, "BACKGROUND")
        wash:SetAllPoints()
        button.marker = button:CreateTexture(nil, "ARTWORK")
        button.marker:SetTexture(ns.media .. "Diamond.tga")
        button.marker:SetSize(8, 8)
        button.marker:SetPoint("LEFT", button, "LEFT", 10, 0)
        ns:Tint(button.marker, "SetVertexColor", T.accent, .9)
        local indicator = button:CreateTexture(nil, "OVERLAY")
        indicator:SetPoint("TOPLEFT", 1, -1)
        indicator:SetPoint("TOPRIGHT", -1, -1)
        indicator:SetHeight(1)
        ns:SnapTexture(indicator)
        if iconKey then
            local icon = T:Glyph(button, iconKey, 16, T.brass)
            icon:SetPoint("LEFT", button, "LEFT", 6, 0)
        end
        button.text = self:Label(button, text, 11, T.muted)
        button.text:SetPoint("LEFT", button, "LEFT", 28, 0)
        button.text:SetPoint("RIGHT", button, "RIGHT", -20, 0)
        button.text:SetWordWrap(false)
        button.pageKey = pageKey
        button:SetScript("OnClick", function() onClick(pageKey) end)
        local function Fade(texture, color, opacity)
            local r, g, b = unpack(color)
            if texture.SetGradient and CreateColor then
                texture:SetColorTexture(1, 1, 1, 1)
                texture:SetGradient("HORIZONTAL", CreateColor(r, g, b, opacity), CreateColor(r, g, b, 0))
            else
                texture:SetColorTexture(r, g, b, opacity)
            end
        end
        local function Paint(self)
            local selected = self.selected
            self.marker:SetShown(selected and not iconKey)
            indicator:SetShown(selected)
            wash:SetShown(not not (selected or self.hovered))
            if selected or self.hovered then
                local bg = selected and (self.hovered and T.accentHover or T.accentDim) or T.panelHover
                Fade(wash, bg, selected and .72 or .48)
            end
            if selected then Fade(indicator, T.controlAccentLine, .72) end
            local c = (selected or self.hovered) and T.text or T.muted
            self.text:SetTextColor(c[1], c[2], c[3], 1)
        end
        function button:SetSelected(selected)
            self.selected = selected
            Paint(self)
        end
        button:SetScript("OnEnter", function(self) self.hovered = true; Paint(self) end)
        button:SetScript("OnLeave", function(self) self.hovered = false; Paint(self) end)
        ns:TrackAppearance(button, "state", Paint)
        button:SetSelected(false)
        return button
    end

    function W:EnableSettingsTab(edit)
        edit:HookScript("OnTabPressed", function(self)
            local frame = self:GetParent()
            while frame and not frame.MoveSettingsFocus do frame = frame:GetParent() end
            if frame then frame:MoveSettingsFocus(self) end
        end)
    end

    return W
end
