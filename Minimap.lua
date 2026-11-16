local _, theme = ...

local function Atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x > 0 then return math.atan(y / x) end
    if x < 0 then return math.atan(y / x) + (y >= 0 and math.pi or -math.pi) end
    if y ~= 0 then return y > 0 and math.pi / 2 or -math.pi / 2 end
    return 0
end

function theme:CreateMinimapButton(name, icon, db, onClick, onTooltip)
    local map = Minimap
    if not map then return end
    local button = CreateFrame("Button", name .. "MinimapButton", map)
    button:SetSize(31, 31)
    button:SetFrameLevel(map:GetFrameLevel() + 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(25, 25)
    background:SetPoint("CENTER")
    button.background = background
    local art = button:CreateTexture(nil, "ARTWORK")
    art:SetTexture(icon)
    art:SetSize(21, 21)
    art:SetPoint("CENTER")
    button.icon = art
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    button.border = border
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local function Place()
        if button:GetParent() ~= map then return end
        local angle = math.rad(tonumber(db.minimapPos) or 225)
        local size = math.max(map:GetWidth(), map:GetHeight())
        local radius = size / 2 + 5
        button:ClearAllPoints()
        button:SetPoint("CENTER", map, "CENTER", radius * math.cos(angle), radius * math.sin(angle))
    end

    function button:Refresh(settings)
        db = settings or db
        Place()
        button:SetShown(not db.hide)
    end

    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        onTooltip(GameTooltip)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnDragStart", function(self)
        if self:GetParent() ~= map then return end
        GameTooltip:Hide()
        self:SetScript("OnUpdate", function()
            local cx, cy = map:GetCenter()
            local scale = map:GetEffectiveScale()
            if not cx or not cy or not scale or scale == 0 then return end
            local x, y = GetCursorPosition()
            db.minimapPos = math.deg(Atan2(y / scale - cy, x / scale - cx)) % 360
            Place()
        end)
    end)
    local function StopDrag(self) self:SetScript("OnUpdate", nil) end
    button:SetScript("OnDragStop", StopDrag)
    button:SetScript("OnHide", StopDrag)
    button:Refresh()
    return button
end
