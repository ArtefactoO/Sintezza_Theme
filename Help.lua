local _, ns = ...
local T = ns.Settings
local SIZE, GAP, PAD = 18, 6, 10
local tooltip

local function Resize(frame)
    frame:SetHeight(math.max(14, frame.note:GetStringHeight()) + PAD * 2)
end

local function CreateHelp()
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:Hide()
    frame:SetFrameStrata("TOOLTIP")
    frame:SetClampedToScreen(true)
    frame:SetWidth(260)
    T:Backdrop(frame, T.input, T.accentLine)
    local note = frame:CreateFontString(nil, "ARTWORK")
    note:SetPoint("TOPLEFT", PAD, -PAD)
    note:SetWidth(260 - PAD * 2)
    note:SetHeight(0)
    note:SetJustifyH("LEFT")
    note:SetWordWrap(true)
    T:Font(note, 11, "", T.text)
    frame.note = note
    ns:TrackAppearance(frame, "state", Resize)
    frame:SetScript("OnHide", function(self)
        self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        self:UnregisterEvent("PLAYER_REGEN_DISABLED")
        self.owner, self.pinned = nil, nil
    end)
    frame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" or not self.owner or not self.owner:IsMouseOver() then
            self:Hide()
        end
    end)
    return frame
end

local function Hide(owner)
    if tooltip and tooltip.owner == owner then tooltip:Hide() end
end

function ns:DismissHelp(window)
    local owner = tooltip and tooltip.owner
    while owner and owner ~= window do owner = owner:GetParent() end
    if not owner then return false end
    tooltip:Hide()
    return true
end

local function Show(owner, pinned)
    if not owner:IsVisible() then return end
    if tooltip and tooltip.owner == owner then
        if tooltip.pinned then
            if pinned then tooltip:Hide() end
            return
        end
    elseif tooltip then
        tooltip:Hide()
    end
    tooltip = tooltip or CreateHelp()
    tooltip.owner, tooltip.pinned = owner, pinned
    tooltip.note:SetText(owner.helpText)
    tooltip:Show()
    Resize(tooltip)
    tooltip:ClearAllPoints()
    local below = owner:GetBottom()
    local scale = owner:GetEffectiveScale() / tooltip:GetEffectiveScale()
    if below and below * scale < tooltip:GetHeight() + GAP then
        tooltip:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, GAP)
    else
        tooltip:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -GAP)
    end
    if pinned then
        tooltip:RegisterEvent("GLOBAL_MOUSE_DOWN")
    end
    tooltip:RegisterEvent("PLAYER_REGEN_DISABLED")
end

function ns:AttachHelp(row, appearance, note, label)
    label = label or row.label
    if not label or type(note) ~= "string" or note == "" then return row end
    if row.helpButton then
        row.helpButton.helpText = note
        return row
    end

    local button = CreateFrame("Button", nil, row)
    row.helpButton, button.helpText = button, note
    button:SetSize(SIZE, SIZE)
    local rim = button:CreateTexture(nil, "BACKGROUND")
    rim:SetAllPoints()
    rim:SetTexture(ns.media .. "help-ring.tga")
    ns:Tint(rim, "SetVertexColor", appearance.accent, .64)
    local mark = button:CreateFontString(nil, "OVERLAY")
    mark:SetPoint("CENTER")
    appearance:Font(mark, 11, "", appearance.accent)
    mark:SetText("?")

    -- Leave room for the trigger when a column constrains the label.
    for index = 1, label:GetNumPoints() do
        local point, relative, edge, x, y = label:GetPoint(index)
        if point:find("RIGHT", 1, true) then
            label:SetPoint(point, relative or row, edge or point, (x or 0) - SIZE - GAP, y or 0)
        end
    end
    local function Layout()
        local width = math.min(label:GetWidth(), label:GetStringWidth())
        button:ClearAllPoints()
        button:SetPoint("LEFT", label, "LEFT", width + GAP, 0)
    end
    row:HookScript("OnSizeChanged", Layout)
    row:HookScript("OnShow", Layout)
    self:TrackAppearance(button, "state", Layout)
    Layout()
    if row.LayoutTitleRule then
        local function LayoutTitleRule() row:LayoutTitleRule() end
        button:HookScript("OnShow", LayoutTitleRule)
        button:HookScript("OnHide", LayoutTitleRule)
        LayoutTitleRule()
    end

    button:SetScript("OnEnter", function(owner) Show(owner, false) end)
    button:SetScript("OnLeave", function(owner) if not (tooltip and tooltip.pinned) then Hide(owner) end end)
    button:SetScript("OnClick", function(owner) Show(owner, true) end)
    button:SetScript("OnHide", Hide)
    button.settingsOnBlur = Hide
    return row
end
