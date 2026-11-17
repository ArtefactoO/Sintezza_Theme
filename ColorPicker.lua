local _, ns = ...
local T = ns.Settings
local english = ns:GetLocale() == "enUS"
local function Text(en, ru) return english and en or ru end

local panel, session
local owners = setmetatable({}, { __mode = "k" })
local LIMIT = 10

local function Clamp(value)
    return math.max(0, math.min(1, value))
end

local function HSVToRGB(h, s, v)
    local turn = (h % 1) * 6
    local sector = math.floor(turn)
    local low = v * (1 - s)
    local rising = v * (1 - s * (1 - (turn - sector)))
    local falling = v * (1 - s * (turn - sector))
    if sector == 0 then return v, rising, low end
    if sector == 1 then return falling, v, low end
    if sector == 2 then return low, v, rising end
    if sector == 3 then return low, falling, v end
    if sector == 4 then return rising, low, v end
    return v, low, falling
end

local function RGBToHSV(r, g, b)
    local v = math.max(r, g, b)
    local delta = v - math.min(r, g, b)
    if delta == 0 then return 0, 0, v end
    local hue
    if v == r then hue = (g - b) / delta
    elseif v == g then hue = (b - r) / delta + 2
    else hue = (r - g) / delta + 4 end
    return (hue / 6) % 1, delta / v, v
end

local function ReadHex(value)
    local hex = value:match("^%s*#?(%x+)%s*$")
    if not hex then return end
    if #hex == 3 then hex = hex:gsub(".", "%0%0") end
    if #hex == 6 then return hex:upper() end
end

local function Hex(r, g, b)
    return ("%02X%02X%02X"):format(math.floor(r * 255 + .5), math.floor(g * 255 + .5), math.floor(b * 255 + .5))
end

local function RGB(hex)
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

local function Palette(key)
    local db = ns.Fonts:GetSettings()
    if type(db.colorPicker) ~= "table" then db.colorPicker = {} end
    local list = db.colorPicker[key]
    if type(list) ~= "table" then list = {}; db.colorPicker[key] = list end
    return list
end

local function Finish(accept)
    local current = session
    if not current then return end
    session = nil
    panel:Hide()
    if accept and current.previewed then
        local list = Palette("recent")
        local hex = Hex(current.r, current.g, current.b)
        for index = #list, 1, -1 do
            if list[index] == hex then table.remove(list, index) end
        end
        table.insert(list, 1, hex)
        while #list > LIMIT do table.remove(list) end
    elseif not accept and current.previewed and current.onCancel then
        current.onCancel()
    end
end

function ns:IsColorPickerOpen()
    return session ~= nil
end

function ns:CloseColorPicker(widgets, owner)
    if session and session.widgets == widgets and (not owner or session.owner == owner) then Finish(false) end
end

local function Checker(frame, columns, rows)
    for row = 0, rows - 1 do
        for column = 0, columns - 1 do
            local tile = frame:CreateTexture(nil, "BACKGROUND")
            local size = frame:GetWidth() / columns
            tile:SetPoint("TOPLEFT", frame, "TOPLEFT", column * size, -row * frame:GetHeight() / rows)
            tile:SetSize(size, frame:GetHeight() / rows)
            local gray = (column + row) % 2 == 0 and .72 or .40
            tile:SetColorTexture(gray, gray, gray, 1)
        end
    end
end

local function Gradient(region, axis, start, finish)
    region:SetColorTexture(1, 1, 1, 1)
    region:SetGradient(axis, CreateColor(unpack(start)), CreateColor(unpack(finish)))
end

local function Capture(frame, change)
    frame:EnableMouse(true)
    local function Drag(self)
        if not session or not IsMouseButtonDown("LeftButton") then
            self:SetScript("OnUpdate", nil)
            return
        end
        local x, y = GetCursorPosition()
        local scale = self:GetEffectiveScale()
        local left, bottom = self:GetLeft(), self:GetBottom()
        if left and bottom then
            change(Clamp((x / scale - left) / self:GetWidth()), Clamp((y / scale - bottom) / self:GetHeight()))
        end
    end
    local function Stop(self) self:SetScript("OnUpdate", nil) end
    frame:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        Drag(self)
        if session then self:SetScript("OnUpdate", Drag) end
    end)
    frame:SetScript("OnMouseUp", Stop)
    frame:SetScript("OnHide", Stop)
end

local function Build()
    local W = ns:CreateWidgets(T)
    local shade = CreateFrame("Frame", nil, UIParent)
    shade:Hide()
    shade:SetAllPoints(UIParent)
    shade:SetFrameStrata("FULLSCREEN_DIALOG")
    shade:EnableMouse(true)
    shade:EnableMouseWheel(true)
    local dim = shade:CreateTexture(nil, "BACKGROUND")
    dim:SetAllPoints()
    dim:SetColorTexture(0, 0, 0, .37)

    local dialog = CreateFrame("Frame", "SintezzaThemeColorPicker", shade, "BackdropTemplate")
    dialog:Hide()
    dialog:SetPoint("CENTER")
    dialog:SetClampedToScreen(true)
    dialog:EnableMouse(true)
    T:Backdrop(dialog, T.bg, T.line)
    if UISpecialFrames then table.insert(UISpecialFrames, dialog:GetName()) end

    local title = W:Label(dialog, Text("Choose color", "Выбор цвета"), 16, T.text, "display")
    title:SetPoint("TOPLEFT", 16, -13)
    local close = W:CloseButton(dialog, function() Finish(false) end)
    close:SetPoint("TOPRIGHT", -10, -9)

    local function Surface(kind, width, height, x, y)
        local surface = CreateFrame(kind, nil, dialog, "BackdropTemplate")
        surface:SetSize(width, height)
        surface:SetPoint("TOPLEFT", dialog, "TOPLEFT", x, -y)
        return surface
    end
    local square = Surface("Frame", 218, 218, 16, 43)
    local hue = Surface("Frame", 18, 218, 244, 43)
    local alpha = Surface("Frame", 246, 14, 16, 283)
    Checker(alpha, 18, 2)
    local tone = square:CreateTexture(nil, "BACKGROUND")
    tone:SetAllPoints()
    local white = square:CreateTexture(nil, "ARTWORK", nil, 1)
    white:SetAllPoints()
    Gradient(white, "HORIZONTAL", {1, 1, 1, 1}, {1, 1, 1, 0})
    local black = square:CreateTexture(nil, "ARTWORK", nil, 2)
    black:SetAllPoints()
    Gradient(black, "VERTICAL", {0, 0, 0, 1}, {0, 0, 0, 0})

    for index = 0, 5 do
        local band = hue:CreateTexture(nil, "ARTWORK")
        band:SetPoint("TOPLEFT", hue, "TOPLEFT", 0, -index * 218 / 6)
        band:SetSize(18, 218 / 6)
        Gradient(band, "VERTICAL", { HSVToRGB((index + 1) % 6 / 6, 1, 1) }, { HSVToRGB(index / 6, 1, 1) })
    end
    local alphaTint = alpha:CreateTexture(nil, "ARTWORK")
    alphaTint:SetAllPoints()
    local alphaLabel = W:Label(dialog, "", 10, T.muted)
    alphaLabel:SetPoint("LEFT", alpha, "RIGHT", 12, 0)
    local function Marker(frame, w, h)
        local marker = frame:CreateTexture(nil, "OVERLAY", nil, 6)
        marker:SetSize(w, h)
        marker:SetColorTexture(1, 1, 1, 1)
        return marker
    end
    local point = square:CreateTexture(nil, "OVERLAY", nil, 6)
    point:SetSize(15, 15)
    point:SetTexture(ns.media .. "help-ring.tga")
    local hueMark, alphaMark = Marker(hue, 22, 2), Marker(alpha, 2, 18)

    local function Sample(label, y, kind)
        local caption = W:Label(dialog, label, 10, T.muted)
        caption:SetPoint("TOPLEFT", 280, -y)
        local frame = Surface(kind, 104, 24, 280, y + 15)
        Checker(frame, 7, 2)
        local paint = frame:CreateTexture(nil, "ARTWORK")
        paint:SetAllPoints()
        return frame, paint
    end
    local _, fresh = Sample(Text("New", "Новый"), 43, "Frame")
    local previous, original = Sample(Text("Original", "Исходный"), 92, "Button")

    local hexLabel = W:Label(dialog, "Hex", 10, T.muted)
    hexLabel:SetPoint("TOPLEFT", 280, -142)
    local hex = W:EditBox(dialog, "", function() end)
    hex:SetSize(104, 27)
    hex:SetPoint("TOPLEFT", 280, -157)
    hex:SetMaxLetters(12)
    hex:SetJustifyH("CENTER")
    local hint = W:Label(dialog, "", 9, T.warning)
    hint:SetPoint("TOPLEFT", hex, "BOTTOMLEFT", 0, -4)
    local star = W:Button(dialog, "", function()
        local key = Hex(session.r, session.g, session.b)
        local list = Palette("favorites")
        for index, saved in ipairs(list) do
            if saved == key then
                table.remove(list, index)
                dialog:RefreshPalette()
                dialog:Refresh()
                return
            end
        end
        if #list < LIMIT then
            list[#list + 1] = key
            dialog:RefreshPalette()
            dialog:Refresh()
        end
    end)
    star:SetSize(104, 25)
    star:SetPoint("TOPLEFT", 280, -231)

    local function PlaceMark(mark, relative, x, y)
        mark:ClearAllPoints()
        mark:SetPoint("CENTER", relative, "BOTTOMLEFT", x, y)
    end

    local function Apply(h, s, v, a)
        local current = session
        if not current then return end
        local r, g, b = HSVToRGB(h, s, v)
        local changed = math.abs(current.r - r) > .00001 or math.abs(current.g - g) > .00001
            or math.abs(current.b - b) > .00001 or current.a ~= a
        current.h, current.s, current.v, current.a = h, s, v, a
        current.r, current.g, current.b = r, g, b
        dialog:Refresh()
        if changed and current.onChange then
            current.previewed = true
            current.onChange({r = r, g = g, b = b, a = a})
        end
    end

    local function Choose(key)
        local h, s, v = RGBToHSV(RGB(key))
        Apply(s > 0 and h or session.h, s, v, session.a)
    end
    local function CommitHex()
        local key = ReadHex(hex:GetText())
        if not key then
            hint:SetText(Text("Enter 3 or 6 hex digits", "Нужно 3 или 6 символов"))
            hex:SetFocus()
            hex:HighlightText()
            return false
        end
        if key ~= Hex(session.r, session.g, session.b) then Choose(key) end
        return true
    end

    previous:SetScript("OnClick", function()
        local current = session
        local color = current.original
        local h, s, v = RGBToHSV(color.r, color.g, color.b)
        Apply(h, s, v, color.a)
    end)
    hex:SetScript("OnEnterPressed", function(self) if CommitHex() then self:ClearFocus() end end)
    hex:SetScript("OnEscapePressed", function() Finish(false) end)
    Capture(square, function(x, y) Apply(session.h, x, y, session.a) end)
    Capture(hue, function(_, y) Apply((1 - y) % 1, session.s, session.v, session.a) end)
    Capture(alpha, function(x) Apply(session.h, session.s, session.v, x) end)

    local function Swatches(key, label)
        local caption = W:Label(dialog, label, 10, T.muted)
        local buttons = {}
        for index = 1, LIMIT do
            local button = CreateFrame("Button", nil, dialog, "BackdropTemplate")
            button:SetSize(25, 25)
            T:Backdrop(button, T.input, T.line)
            button:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(unpack(T.accent)) end)
            button:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(T.line)) end)
            button:SetScript("OnClick", function(self) Choose(self.hex) end)
            buttons[index] = button
        end
        return function(y)
            caption:ClearAllPoints()
            caption:SetPoint("TOPLEFT", dialog, "TOPLEFT", 16, -y)
            local colors = Palette(key)
            for index, button in ipairs(buttons) do
                local value = colors[index]
                button.hex = type(value) == "string" and ReadHex(value) or nil
                button:SetShown(button.hex ~= nil)
                if button.hex then
                    local r, g, b = RGB(button.hex)
                    button:SetBackdropColor(r, g, b, 1)
                end
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", dialog, "TOPLEFT", 16 + (index - 1) * 30, -y - 16)
            end
        end
    end
    local favorites = Swatches("favorites", Text("Favorites", "Избранное"))
    local recent = Swatches("recent", Text("Recent colors", "Недавние цвета"))

    local okay = W:Button(dialog, Text("OK", "ОК"), function()
        local current = session
        if CommitHex() and session == current then Finish(true) end
    end, true)
    okay:SetSize(88, 25)
    okay:SetPoint("BOTTOMRIGHT", -16, 13)
    local cancel = W:Button(dialog, Text("Cancel", "Отмена"), function() Finish(false) end)
    cancel:SetSize(88, 25)
    cancel:SetPoint("RIGHT", okay, "LEFT", -7, 0)
    dialog:SetScript("OnHide", function()
        hex:ClearFocus()
        shade:Hide()
        Finish(false)
    end)

    function dialog:RefreshPalette()
        local delta = session.hasAlpha and 36 or 0
        favorites(272 + delta)
        recent(322 + delta)
        dialog:SetSize(400, 420 + delta)
    end

    function dialog:Refresh()
        local current = session
        local r, g, b, a = current.r, current.g, current.b, current.a
        local base = current.original
        local hr, hg, hb = HSVToRGB(current.h, 1, 1)
        tone:SetColorTexture(hr, hg, hb, 1)
        fresh:SetColorTexture(r, g, b, a)
        original:SetColorTexture(base.r, base.g, base.b, base.a)
        PlaceMark(point, square, current.s * 218, current.v * 218)
        PlaceMark(hueMark, hue, 9, (1 - current.h) * 218)
        PlaceMark(alphaMark, alpha, a * 246, 7)
        Gradient(alphaTint, "HORIZONTAL", {r, g, b, 0}, {r, g, b, 1})
        alphaLabel:SetText(Text("Opacity %d%%", "Непрозр. %d%%"):format(math.floor(a * 100 + .5)))
        alpha:SetShown(current.hasAlpha)
        alphaLabel:SetShown(current.hasAlpha)
        local key = Hex(r, g, b)
        hex:SetText(key)
        hint:SetText("")
        local list = Palette("favorites")
        local saved
        for _, item in ipairs(list) do if item == key then saved = true; break end end
        star.text:SetText(saved and Text("Remove favorite", "Из избранного") or Text("Add favorite", "В избранное"))
        star:SetEnabled(saved == true or #list < LIMIT)
    end

    dialog.shade = shade
    return dialog
end

function ns:OpenColorPicker(widgets, owner, initialColor, hasAlpha, onChange, onCancel)
    Finish(false)
    if session then return false end
    if not panel then panel = Build() end
    local r, g, b, a = initialColor.r, initialColor.g, initialColor.b, initialColor.a or 1
    local h, s, v = RGBToHSV(r, g, b)
    session = {
        widgets = widgets, owner = owner, original = {r = r, g = g, b = b, a = a},
        r = r, g = g, b = b, a = a, h = h, s = s, v = v,
        hasAlpha = hasAlpha == true, onChange = onChange, onCancel = onCancel,
    }
    if owner and owner.HookScript and not owners[owner] then
        owners[owner] = true
        owner:HookScript("OnHide", function(self)
            if session and session.owner == self then Finish(false) end
        end)
    end
    panel:RefreshPalette()
    panel:Refresh()
    panel.shade:Show()
    panel:Show()
    return true
end
