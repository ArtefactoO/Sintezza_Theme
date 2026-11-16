local _, theme = ...
local Preferences = {}
local contexts = setmetatable({}, { __mode = "k" })
local defaults = { scale = 100, opacity = 100, layer = "DEFAULT", locked = false }
local layerOrder = { DEFAULT = 1, MEDIUM = 2, HIGH = 3, DIALOG = 4 }

local function Text(english, russian)
    return theme:GetLocale() == "ruRU" and russian or english
end

local function Number(value, minimum, maximum, fallback)
    local number = tonumber(value)
    if not number or number ~= number then return fallback end
    return math.min(maximum, math.max(minimum, number))
end

local function Normalize(key, value)
    if key == "scale" then return Number(value, 50, 200, 100) end
    if key == "opacity" then return Number(value, 20, 100, 100) end
    if key == "layer" then return layerOrder[value] and value or defaults.layer end
    if key == "locked" then return value == true end
end

function theme:NewWindowPreferences(getOwner, import, key)
    local prefs = setmetatable({
        getOwner = getOwner, import = import, key = key or "windowAppearance",
        windows = setmetatable({}, { __mode = "k" }),
    }, { __index = Preferences })
    contexts[prefs] = true
    return prefs
end

function Preferences:Storage()
    local owner = self.getOwner()
    if not owner then return end
    if type(owner[self.key]) ~= "table" then
        owner[self.key] = self.import and self.import(owner) or {}
    end
    return owner[self.key]
end

function Preferences:Get(key)
    local db = self:Storage()
    if db then return Normalize(key, db[key]) end
    return defaults[key]
end

function Preferences:CanMove()
    return not InCombatLockdown() and not self:Get("locked")
end

function Preferences:Set(key, value)
    local db = self:Storage()
    if not db then return end
    db[key] = Normalize(key, value)
    self:Apply()
    if self.OnChanged then
        if InCombatLockdown() then
            self.changed = self.changed or {}
            self.changed[key] = true
        else
            self:OnChanged(key)
        end
    end
end

local function ResetFramePosition(frame, options)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", options.resetX or 0, options.resetY or 0)
    if frame.SetUserPlaced then frame:SetUserPlaced(false) end
end

local function Dimension(value, frame)
    if type(value) == "function" then return value(frame) end
    return value
end

local function SetResizeBounds(frame, resize)
    local width, height = Dimension(resize.minWidth, frame), Dimension(resize.minHeight, frame)
    frame:SetResizeBounds(width, height, resize.maxWidth, resize.maxHeight)
    return width, height
end

local function RestoreSize(frame, resize, db)
    local minimumWidth, minimumHeight = SetResizeBounds(frame, resize)
    local width, height
    if resize.read then
        width, height = resize.read()
    elseif type(db) == "table" and type(db.sizes) == "table" and type(db.sizes[resize.key]) == "table" then
        width, height = db.sizes[resize.key].width, db.sizes[resize.key].height
    end
    width = Number(width, minimumWidth, resize.maxWidth or math.huge, Dimension(resize.width, frame))
    height = Number(height, minimumHeight, resize.maxHeight or math.huge, Dimension(resize.height, frame))
    width, height = math.max(width, minimumWidth), math.max(height, minimumHeight)
    if frame:GetWidth() == width and frame:GetHeight() == height then return false end
    frame:SetSize(width, height)
    return true
end

function Preferences:AttachResizeGrip(frame, options)
    local resize = options.resize
    resize.key = resize.key or frame:GetName()
    resize.width = resize.width or frame:GetWidth()
    resize.height = resize.height or frame:GetHeight()
    resize.minWidth = resize.minWidth or resize.width
    resize.minHeight = resize.minHeight or resize.height
    frame:SetResizable(true)
    local grip = CreateFrame("Button", nil, frame)
    resize.grip = grip
    grip:SetSize(19, 19)
    grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    grip:SetFrameLevel(frame:GetFrameLevel() + 20)
    local strokes = {}
    for index = 1, 3 do
        local stroke = grip:CreateTexture(nil, "ARTWORK")
        stroke:SetColorTexture(1, 1, 1, 1)
        stroke:SetSize(3 + index * 3, 1.4)
        stroke:SetRotation(math.pi / 4)
        local offset = 2 + index * 2
        stroke:SetPoint("CENTER", grip, "BOTTOMRIGHT", -offset, offset)
        strokes[index] = stroke
    end
    local hovered
    local function PaintGrip()
        local colors = theme.Settings
        local color = resize.dragging and colors.accent or hovered and colors.brass or colors.dim
        for _, stroke in ipairs(strokes) do stroke:SetVertexColor(unpack(color)) end
    end
    grip:SetScript("OnEnter", function() hovered = true; PaintGrip() end)
    grip:SetScript("OnLeave", function() hovered = nil; PaintGrip() end)
    grip:SetScript("OnHide", function() hovered = nil; PaintGrip() end)
    theme:TrackAppearance(grip, "state", PaintGrip)
    PaintGrip()

    function resize.stop(save, applying)
        if not resize.dragging then return end
        if InCombatLockdown() then
            resize.stopPending, self.pending = true, true
            return
        end
        frame:StopMovingOrSizing()
        resize.dragging, resize.stopPending = nil, nil
        PaintGrip()
        resize.needsLayout = true
        local db = self:Storage()
        if save and db and db == resize.profile and self:CanMove() and (not options.active or options.active()) then
            local width, height = math.floor(frame:GetWidth() + .5), math.floor(frame:GetHeight() + .5)
            if resize.save then
                resize.save(width, height)
            else
                if type(db.sizes) ~= "table" then db.sizes = {} end
                db.sizes[resize.key] = { width = width, height = height }
            end
        end
        resize.profile = nil
        if not applying then self:ApplyTo(frame) end
    end

    grip:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or not self:CanMove() or (options.active and not options.active()) then return end
        local db = self:Storage()
        if not db then return end
        resize.dragging, resize.profile = true, db
        frame:StartSizing("BOTTOMRIGHT")
        PaintGrip()
    end)
    grip:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then resize.stop(true) end
    end)
    frame:HookScript("OnHide", function() resize.stop(false) end)
end

function Preferences:ApplyTo(frame)
    local options = self.windows[frame]
    if not options then return end
    if InCombatLockdown() then self.pending = true; return end
    local resize = options.resize
    local active = not options.active or options.active()
    local resized
    if resize then
        local db = self:Storage()
        local unlocked = active and self:CanMove()
        if resize.dragging and (resize.stopPending or not unlocked or resize.profile ~= db) then resize.stop(false, true) end
        resize.grip:SetShown(unlocked)
        if active and not resize.dragging then resized = RestoreSize(frame, resize, db) end
    end
    if not active or (resize and resize.dragging) then return end
    local scale = self:Get("scale") / 100
    if options.fit ~= false then
        local width, height = frame:GetWidth(), options.fitHeight or frame:GetHeight()
        if width > 0 and height > 0 then
            scale = math.max(.1, math.min(scale, (UIParent:GetWidth() - 24) / width, (UIParent:GetHeight() - 24) / height))
        end
    end
    local layer = self:Get("layer")
    local strata = layer == "DEFAULT" and options.defaultLayer or layer
    local layerChanged = frame:GetFrameStrata() ~= strata
    if layerChanged then frame:SetFrameStrata(strata) end
    frame:SetAlpha(self:Get("opacity") / 100)
    frame:SetScale(scale)
    if options.layout then options.layout(frame, scale) end
    if options.pendingPosition then
        options.pendingPosition = nil
        ResetFramePosition(frame, options)
    end
    if resize and (resized or resize.needsLayout) then
        resize.needsLayout = nil
        if frame.onResized then frame.onResized() end
    end
    if layerChanged and theme.RaiseWindow then theme:RaiseWindow(frame) end
end

function Preferences:Apply()
    for frame in pairs(self.windows) do self:ApplyTo(frame) end
end

function Preferences:Bind(frame, options)
    if not self.windows[frame] then
        options = options or {}
        options.defaultLayer = options.defaultLayer or frame:GetFrameStrata()
        self.windows[frame] = options
        if options.resize then self:AttachResizeGrip(frame, options) end
        frame:HookScript("OnShow", function(selfFrame) self:ApplyTo(selfFrame) end)
    end
    self:ApplyTo(frame)
end

function Preferences:ResetPosition()
    if InCombatLockdown() then self.pendingReset = true; return end
    if self.OnReset and self:OnReset() then return end
    for frame, options in pairs(self.windows) do
        if not options.active or options.active() then
            ResetFramePosition(frame, options)
        else
            options.pendingPosition = true
        end
    end
end

function Preferences:ResetSize()
    if InCombatLockdown() then self.pendingSizeReset = true; return end
    local db = self:Storage()
    if not db then return end
    if self.OnResetSize then self:OnResetSize() end
    db.sizes = nil
    for _, options in pairs(self.windows) do
        local resize = options.resize
        if resize then
            if resize.dragging then resize.stop(false, true) end
            if resize.save then resize.save(nil, nil) end
        end
    end
    self:Apply()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("DISPLAY_SIZE_CHANGED")
events:SetScript("OnEvent", function(_, event)
    for prefs in pairs(contexts) do
        if event == "PLAYER_REGEN_DISABLED" then
            for _, options in pairs(prefs.windows) do
                if options.resize then options.resize.stop(false) end
            end
        end
        if prefs.pendingReset then prefs.pendingReset = nil; prefs:ResetPosition() end
        if prefs.pendingSizeReset and not InCombatLockdown() then
            prefs.pendingSizeReset = nil
            prefs:ResetSize()
        end
        if prefs.pending or event == "DISPLAY_SIZE_CHANGED" then
            prefs.pending = nil
            prefs:Apply()
        end
        if prefs.changed and not InCombatLockdown() then
            local changed = prefs.changed
            prefs.changed = nil
            for key in pairs(changed) do prefs:OnChanged(key) end
        end
    end
end)

function theme:CreateWindowOptions(parent, appearance, options)
    local T = appearance or self.Settings
    local W = self:CreateWidgets(T)
    local panel = W:Card(parent, Text("Window and minimap", "Окно и миникарта"), nil, "panels")
    local rows, offset = {}, -35
    local selected = 1
    local function Current() return options.windows[selected].prefs end
    local function Add(row)
        T:Font(row.label, 11, "", T.text, "setting")
        local previous = rows[#rows]
        if previous then
            local separator = previous:CreateTexture(nil, "BACKGROUND")
            separator:SetPoint("BOTTOMLEFT", 0, -1)
            separator:SetPoint("BOTTOMRIGHT", 0, -1)
            separator:SetHeight(1)
            self:SnapTexture(separator)
            self:Tint(separator, "SetColorTexture", T.brass, .13)
        end
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", W.CARD_INSET, offset)
        row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -W.CARD_INSET, offset)
        offset = offset - row:GetHeight() - 2
        rows[#rows + 1] = row
    end
    local function Refresh()
        for _, row in ipairs(rows) do if row.Refresh then row:Refresh(false) end end
    end
    if #options.windows > 1 then
        local labels = {}
        for index, window in ipairs(options.windows) do labels[index] = window.label end
        Add(W:ChoiceRow(panel, Text("Window", "Окно"), labels, function() return selected end,
            function(value) selected = value; Refresh() end))
    end
    local function Get(key) return function() return Current():Get(key) end end
    local function Set(key) return function(value) Current():Set(key, value) end end
    Add(W:SliderRow(panel, Text("Window scale", "Масштаб окна"), 50, 200, 5, Get("scale"), Set("scale"), "%"))
    Add(W:SliderRow(panel, Text("Window opacity", "Непрозрачность окна"), 20, 100, 5, Get("opacity"), Set("opacity"), "%"))
    Add(W:Help(W:ChoiceRow(panel, Text("Window layer", "Слой окна"), {
        DEFAULT = Text("Default", "По умолчанию"), MEDIUM = Text("Normal", "Обычный"),
        HIGH = Text("High", "Повышенный"), DIALOG = Text("Dialog", "Диалоговый"),
    }, Get("layer"), Set("layer"), layerOrder), Text(
        "Controls which windows appear above this one. Default uses the addon's own layer.",
        "Задает порядок перекрытия окон. По умолчанию используется слой самого аддона.")))
    Add(W:Help(W:Toggle(panel, Text("Lock window", "Закрепить окно"), Get("locked"), Set("locked")),
        Text("Prevents dragging and resizing the window.", "Блокирует перетаскивание и изменение размера окна.")))
    Add(W:ActionRow(panel, Text("Window position", "Положение окна"), Text("Reset", "Сбросить"),
        function()
            local prefs = Current()
            W:Confirm(Text("Reset window position?", "Сбросить положение окна?"), function() prefs:ResetPosition() end)
        end))
    Add(W:ActionRow(panel, Text("Window size", "Размер окна"), Text("Reset", "Сбросить"),
        function()
            local prefs = Current()
            W:Confirm(Text("Reset window size?", "Сбросить размер окна?"), function() prefs:ResetSize() end)
        end))
    Add(W:Toggle(panel, Text("Minimap button", "Кнопка у миникарты"), options.getMinimap, options.setMinimap))
    panel:SetHeight(-offset + 8)
    panel:HookScript("OnShow", Refresh)
    panel.Refresh = Refresh
    return panel
end
