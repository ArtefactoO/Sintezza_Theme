local _, theme = ...
local Preferences = {}
local contexts = setmetatable({}, { __mode = "k" })
local globalContexts = setmetatable({}, { __mode = "k" })
local globalKeys = { scale = true, opacity = true, layer = true }
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

function Preferences:Storage(readOnly)
    local owner = self.getOwner()
    if not owner then return end
    local db = owner[self.key]
    if type(db) ~= "table" then
        db = self.import and self.import(owner) or {}
        if not readOnly then owner[self.key] = db end
    end
    return db
end

local function GlobalStorage()
    local settings = Sintezza_ThemeDB
    local storage = type(settings) == "table" and settings.windowDefaults
    if type(storage) == "table" then return storage end
end

function Preferences:Get(key)
    local db = self:Storage()
    if db and db[key] ~= nil then return Normalize(key, db[key]) end
    if globalContexts[self] and globalKeys[key] then
        local shared = GlobalStorage()
        return Normalize(key, shared and shared[key])
    end
    return defaults[key]
end

function Preferences:CanMove()
    return not InCombatLockdown() and not self:Get("locked")
end

function Preferences:NotifyChanged(key)
    if self.OnChanged then
        if InCombatLockdown() then
            self.changed = self.changed or {}
            self.changed[key] = true
        else
            self:OnChanged(key)
        end
    end
end

function Preferences:Set(key, value)
    local db = self:Storage()
    if not db then return end
    db[key] = Normalize(key, value)
    self:Apply()
    self:NotifyChanged(key)
end

function theme:RegisterGlobalWindowPreferences(label, prefs)
    if type(label) ~= "string" or label == "" or not contexts[prefs] then return end
    globalContexts[prefs] = label
    prefs:Apply()
    return prefs
end

function theme:GetGlobalWindowOptions()
    local shared, values = GlobalStorage(), {}
    for key in pairs(globalKeys) do values[key] = Normalize(key, shared and shared[key]) end
    return values
end

local function GlobalValues(values)
    local normalized = {}
    if type(values) ~= "table" then return normalized end
    for key in pairs(globalKeys) do
        local value = values[key]
        if key == "layer" then
            if layerOrder[value] then normalized[key] = value end
        else
            local number = tonumber(value)
            if number and number == number then normalized[key] = Normalize(key, number) end
        end
    end
    return normalized
end

function theme:GetGlobalWindowConflicts(values)
    local normalized, conflicts, seen = GlobalValues(values), {}, {}
    for prefs, label in pairs(globalContexts) do
        local db = not seen[label] and prefs:Storage(true)
        if db then
            for key, value in pairs(normalized) do
                if db[key] ~= nil and Normalize(key, db[key]) ~= value then
                    seen[label] = true
                    conflicts[#conflicts + 1] = label
                    break
                end
            end
        end
    end
    table.sort(conflicts)
    return conflicts
end

function theme:ApplyGlobalWindowOptions(values)
    local normalized = GlobalValues(values)
    if not next(normalized) then return false end
    local shared = GlobalStorage()
    if not shared then
        shared = {}
        local settings = self.Fonts:GetSettings()
        settings.windowDefaults = shared
    end
    for key, value in pairs(normalized) do shared[key] = value end
    -- Only clear overrides in active profile owners that participated in the conflict check.
    for prefs in pairs(globalContexts) do
        local db = prefs:Storage()
        if db then for key in pairs(normalized) do db[key] = nil end end
    end
    for prefs in pairs(globalContexts) do
        prefs:Apply()
        for key in pairs(normalized) do prefs:NotifyChanged(key) end
    end
    return true
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

local function MinimumSize(frame, resize)
    return Dimension(resize.minWidth, frame), Dimension(resize.minHeight, frame)
end

local function RestoreSize(frame, resize, db)
    local minimumWidth, minimumHeight = MinimumSize(frame, resize)
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

    local function UpdateSize(drag)
        local x, y = GetCursorPosition()
        local width = Number(drag.width + math.floor((x - drag.x) / drag.scale + .5), drag.minWidth, drag.maxWidth)
        local height = Number(drag.height + math.floor((drag.y - y) / drag.scale + .5), drag.minHeight, drag.maxHeight)
        if frame:GetWidth() == width and frame:GetHeight() == height then return end
        if not drag.points then
            drag.points = {}
            for index = 1, frame:GetNumPoints() do
                drag.points[index] = { frame:GetPoint(index) }
            end
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", drag.left, drag.top)
        end
        frame:SetSize(width, height)
    end

    function resize.stop(save, applying)
        local drag = resize.dragging
        if not drag then return end
        grip:SetScript("OnUpdate", nil)
        if InCombatLockdown() then
            resize.stopPending, self.pending = true, true
            return
        end
        resize.dragging, resize.stopPending = nil, nil
        PaintGrip()
        if drag.points then
            resize.needsLayout = true
            local db = self:Storage()
            local width, height = frame:GetWidth(), frame:GetHeight()
            local changed = width ~= drag.width or height ~= drag.height
            if changed and save and db == drag.profile and self:CanMove() and (not options.active or options.active()) then
                width, height = math.floor(width + .5), math.floor(height + .5)
                if resize.save then
                    resize.save(width, height)
                else
                    if type(db.sizes) ~= "table" then db.sizes = {} end
                    db.sizes[resize.key] = { width = width, height = height }
                end
            else
                frame:ClearAllPoints()
                for _, point in ipairs(drag.points) do
                    frame:SetPoint(unpack(point, 1, 5))
                end
                if changed then frame:SetSize(drag.width, drag.height) end
            end
        end
        if not applying then self:ApplyTo(frame) end
    end

    local function CanResize(drag)
        return self:CanMove() and drag.profile == self:Storage()
            and frame:GetEffectiveScale() == drag.scale and (not options.active or options.active())
    end

    grip:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or resize.dragging or not self:CanMove() or (options.active and not options.active()) then return end
        local db = self:Storage()
        local left, top, scale = frame:GetLeft(), frame:GetTop(), frame:GetEffectiveScale()
        local parentLeft, parentTop = UIParent:GetLeft(), UIParent:GetTop()
        if not db or not left or not top or not parentLeft or not parentTop or scale <= 0 then return end
        local ratio = UIParent:GetEffectiveScale() / scale
        left, top = left - parentLeft * ratio, top - parentTop * ratio
        local width, height = frame:GetWidth(), frame:GetHeight()
        local minWidth, minHeight = MinimumSize(frame, resize)
        local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
        local maxWidth, maxHeight = screenWidth * ratio - left, screenHeight * ratio + top
        if options.fit ~= false then
            maxWidth = math.min(maxWidth, (screenWidth - 24) * ratio)
            if not options.fitHeight then maxHeight = math.min(maxHeight, (screenHeight - 24) * ratio) end
        end
        local x, y = GetCursorPosition()
        local drag = {
            profile = db, x = x, y = y, scale = scale, left = left, top = top,
            width = width, height = height, minWidth = minWidth, minHeight = minHeight,
            maxWidth = math.max(minWidth, math.min(resize.maxWidth or math.huge, math.max(width, math.floor(maxWidth)))),
            maxHeight = math.max(minHeight, math.min(resize.maxHeight or math.huge, math.max(height, math.floor(maxHeight)))),
        }
        resize.dragging = drag
        grip:SetScript("OnUpdate", function()
            if not CanResize(drag) then
                resize.stop(false)
            elseif IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
                resize.stop(true)
            else
                UpdateSize(drag)
            end
        end)
        PaintGrip()
    end)
    grip:SetScript("OnMouseUp", function(_, button)
        local drag = resize.dragging
        if button ~= "LeftButton" or not drag then return end
        local save = not resize.stopPending and CanResize(drag)
        if save then UpdateSize(drag) end
        resize.stop(save)
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
        if resize.dragging and (resize.stopPending or not unlocked or resize.dragging.profile ~= db) then resize.stop(false, true) end
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
    for _, options in pairs(self.windows) do
        if options.resize then options.resize.stop(false, true) end
    end
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
        if event == "PLAYER_REGEN_DISABLED" or event == "DISPLAY_SIZE_CHANGED" then
            for _, options in pairs(prefs.windows) do
                if options.resize then options.resize.stop(false, true) end
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
    local panel = CreateFrame("Frame", nil, parent)
    local rows, offset = {}, -3
    local inset = W.CONTROL_INSET
    if options.heading then
        local heading = W:Section(panel, Text("Window and minimap", "Окно и миникарта"), nil, "settings")
        heading:SetPoint("TOPLEFT")
        heading:SetPoint("TOPRIGHT")
        heading:SetHeight(heading.headerHeight)
        offset = -heading.headerHeight
    end
    local selected = 1
    local function Current() return options.windows[selected].prefs end
    local function Add(row, startsGroup)
        T:Font(row.label, 11, "", T.text, "setting")
        local previous = rows[#rows]
        if startsGroup then
            offset = offset - 5
        elseif previous then
            local separator = previous:CreateTexture(nil, "BACKGROUND")
            separator:SetPoint("BOTTOMLEFT", 0, -1)
            separator:SetPoint("BOTTOMRIGHT", 0, -1)
            separator:SetHeight(1)
            self:SnapTexture(separator)
            self:Tint(separator, "SetColorTexture", T.brass, .13)
        end
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", inset, offset)
        row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -inset, offset)
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
        Text("Prevents dragging and resizing the window.", "Блокирует перетаскивание и изменение размера окна.")), true)
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
    Add(W:Toggle(panel, Text("Minimap button", "Кнопка у миникарты"), options.getMinimap, options.setMinimap), true)
    panel:SetHeight(-offset + 4)
    panel:HookScript("OnShow", Refresh)
    panel.Refresh = Refresh
    return panel
end
