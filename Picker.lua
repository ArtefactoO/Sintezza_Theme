local _, ns = ...
local T = ns.Settings
local ROW_HEIGHT, PAD, MAX_ROWS = 24, 5, 11
local popup
local watchedOwners = setmetatable({}, { __mode = "k" })

function T:ClosePicker(owner)
    if popup and (not owner or owner == popup.owner) then popup:Hide() end
end

local function Paint(row)
    row.wash:SetShown(row.hovered or row.index == popup.focusIndex)
    row.check:SetShown(row.selected)
    row.label:SetTextColor(unpack(row.enabled and T.text or T.dim))
end

local function Select(row)
    if not row or not row.enabled then return end
    local value, commit = row.value, popup.commit
    popup:Hide()
    commit(value)
end

local function ScrollTo(index)
    local scroll = popup.scroll
    local top = (index - 1) * ROW_HEIGHT
    local offset = scroll:GetVerticalScroll()
    if top < offset then offset = top
    elseif top + ROW_HEIGHT > offset + scroll:GetHeight() then
        offset = top + ROW_HEIGHT - scroll:GetHeight()
    else return end
    scroll:SetVerticalScroll(offset)
end

local function MoveFocus(direction)
    local index = popup.focusIndex
    repeat
        index = index + direction
        if index < 1 or index > popup.count then return end
    until popup.rows[index].enabled
    local old = popup.rows[popup.focusIndex]
    popup.focusIndex = index
    if old then Paint(old) end
    Paint(popup.rows[index])
    ScrollTo(index)
end

local function CreateRow(index)
    local row = CreateFrame("Button", nil, popup.body)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:SetPoint("TOPRIGHT", 0, -(index - 1) * ROW_HEIGHT)
    row:SetHeight(ROW_HEIGHT)
    row.index = index
    row.wash = T:MenuHighlight(row)
    row.check = T:Glyph(row, "check", 14, T.accent)
    row.check:SetPoint("LEFT", 5, 0)
    row.label = row:CreateFontString(nil, "OVERLAY")
    row.label:SetPoint("LEFT", 26, 0)
    row.label:SetPoint("RIGHT", -7, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    T:Font(row.label, 11, "", T.text)
    row:SetScript("OnClick", Select)
    row:SetScript("OnEnter", function(self) self.hovered = true; Paint(self) end)
    row:SetScript("OnLeave", function(self) self.hovered = nil; Paint(self) end)
    ns:TrackAppearance(row, "state", Paint)
    popup.rows[index] = row
    return row
end

local function CreatePicker()
    local frame = CreateFrame("Frame", "Sintezza_ThemePicker", UIParent, "BackdropTemplate")
    frame:Hide()
    frame:SetSize(180, 36)
    frame:SetFrameStrata("TOOLTIP")
    frame:EnableMouse(true)
    T:Glow(frame, .78)
    T:MenuBackdrop(frame)
    frame.rows = {}

    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", PAD, -PAD)
    scroll:SetPoint("BOTTOMRIGHT", -PAD - 13, PAD)
    local body = CreateFrame("Frame", nil, scroll)
    body:SetSize(1, 1)
    scroll:SetScrollChild(body)
    T:AttachScrollBar(scroll, frame, ROW_HEIGHT * 2)
    frame.scroll, frame.body = scroll, body
    frame:HookScript("OnShow", function(self)
        self:RegisterEvent("GLOBAL_MOUSE_DOWN")
        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        if self.SetPropagateKeyboardInput and self.EnableKeyboard and not InCombatLockdown() then
            self:SetPropagateKeyboardInput(true)
            self:EnableKeyboard(true)
        end
    end)
    frame:SetScript("OnHide", function(self)
        self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        self:UnregisterEvent("PLAYER_REGEN_DISABLED")
        if self.EnableKeyboard then self:EnableKeyboard(false) end
        self.owner, self.commit = nil, nil
    end)
    frame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" or not self.owner or not (self:IsMouseOver() or self.owner:IsMouseOver()) then
            self:Hide()
        end
    end)
    if frame.SetPropagateKeyboardInput then
        frame:SetScript("OnKeyDown", function(self, key)
            if InCombatLockdown() then return end
            local handled = key == "ESCAPE" or key == "UP" or key == "DOWN" or key == "ENTER"
            self:SetPropagateKeyboardInput(not handled)
            if key == "ESCAPE" then self:Hide()
            elseif key == "UP" or key == "DOWN" then MoveFocus(key == "UP" and -1 or 1)
            elseif key == "ENTER" then Select(self.rows[self.focusIndex]) end
        end)
    end
    return frame
end

-- Entries have value, label and optional disabled fields.
function T:OpenPicker(owner, entries, selected, commit)
    if popup and popup:IsShown() and popup.owner == owner then popup:Hide(); return end
    self:ClosePicker()
    if #entries == 0 or not owner:IsVisible() then return end
    local left, bottom, top = owner:GetLeft(), owner:GetBottom(), owner:GetTop()
    if not (left and bottom and top) then return end
    popup = popup or CreatePicker()
    popup.owner, popup.commit, popup.count = owner, commit, #entries
    popup.focusIndex = 0
    if not watchedOwners[owner] then
        owner:HookScript("OnHide", function(button) T:ClosePicker(button) end)
        watchedOwners[owner] = true
    end

    local scale = owner:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local width = owner:GetWidth()
    local firstEnabled
    for index, entry in ipairs(entries) do
        local row = popup.rows[index] or CreateRow(index)
        row.value, row.selected, row.hovered = entry.value, entry.value == selected, nil
        row.enabled = entry.disabled ~= true
        row.label:SetText(entry.label)
        width = math.max(width, row.label:GetStringWidth() + 53)
        if row.enabled then
            firstEnabled = firstEnabled or index
            if row.selected then popup.focusIndex = index end
        end
        row:Show()
        Paint(row)
    end
    if popup.focusIndex == 0 then popup.focusIndex = firstEnabled or 0 end
    if popup.focusIndex > 0 then Paint(popup.rows[popup.focusIndex]) end
    for index = #entries + 1, #popup.rows do popup.rows[index]:Hide() end

    local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
    local below, above = bottom * scale - 12, screenHeight - top * scale - 12
    local height = math.min(#entries, MAX_ROWS) * ROW_HEIGHT + PAD * 2
    local opensBelow = below >= height * scale or below >= above
    local room = (opensBelow and below or above) / scale
    height = math.min(height, math.max(ROW_HEIGHT + PAD * 2, room))
    width = math.min(width, (screenWidth - 16) / scale)
    local x = math.max(8, math.min(left * scale, screenWidth - width * scale - 8))
    popup:SetScale(scale)
    popup:ClearAllPoints()
    popup:SetPoint(opensBelow and "TOPLEFT" or "BOTTOMLEFT", UIParent, "BOTTOMLEFT",
        x / scale, opensBelow and bottom - 3 or top + 3)
    popup:SetSize(width, height)
    popup.body:SetSize(math.max(1, width - PAD * 2 - 13), #entries * ROW_HEIGHT)
    popup:Show()
    popup.scroll:SetVerticalScroll(0)
    popup.scroll:RefreshRange()
    if popup.focusIndex > 0 then ScrollTo(popup.focusIndex) end
    return popup
end
