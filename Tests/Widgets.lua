local checks = 0
local function check(value, message) checks = checks + 1; assert(value, message) end
local methods = {}
local function factor(point)
    if point:find('LEFT', 1, true) then return 0 end
    if point:find('RIGHT', 1, true) then return 1 end
    return .5
end
local function Frame(parent)
    return setmetatable({ parent = parent, scripts = {}, anchors = {}, w = 0, h = 0, shown = true, enabled = true }, { __index = methods })
end
local function target(anchor, parent)
    local relative = anchor[2] or parent
    return (relative and relative:GetLeft() or 0) + (relative and relative:GetWidth() or 0) * factor(anchor[3] or anchor[1]) + (anchor[4] or 0)
end
function methods:GetWidth()
    local first
    for _, anchor in ipairs(self.anchors) do
        if not first then first = anchor
        elseif factor(anchor[1]) ~= factor(first[1]) then
            return (target(anchor, self.parent) - target(first, self.parent)) / (factor(anchor[1]) - factor(first[1]))
        end
    end
    return self.w
end
function methods:GetLeft()
    local first = self.anchors[1]
    return first and target(first, self.parent) - self:GetWidth() * factor(first[1]) or 0
end
function methods:GetRight() return self:GetLeft() + self:GetWidth() end
function methods:GetHeight() return self.h end
function methods:SetPoint(point, relative, edge, x, y)
    if type(relative) == 'number' then relative, edge, x, y = self.parent, point, relative, edge end
    relative, edge = relative or self.parent, edge or point
    for index, anchor in ipairs(self.anchors) do if anchor[1] == point then table.remove(self.anchors, index); break end end
    self.anchors[#self.anchors + 1] = { point, relative, edge, x or 0, y or 0 }
end
function methods:ClearAllPoints() self.anchors = {} end
function methods:SetSize(w, h)
    local changed = w ~= self.w or h ~= self.h
    self.w, self.h = w, h
    if changed and self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self, w, h) end
end
function methods:SetWidth(value) self:SetSize(value, self.h) end
function methods:SetHeight(value) self:SetSize(self.w, value) end
function methods:SetScript(key, callback) self.scripts[key] = callback end
function methods:HookScript(key, callback)
    local previous = self.scripts[key]
    self.scripts[key] = function(...) if previous then previous(...) end; callback(...) end
end
function methods:SetText(text) self.text = tostring(text or '') end
function methods:GetText() return self.text or '' end
function methods:SetFont(_, size) self.fontSize = size end
function methods:SetTextColor() end
function methods:HasFocus() return self.focused == true end
function methods:ClearFocus()
    if not self.focused then return end
    self.focused = false
    if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
end
function methods:GetParent() return self.parent end
function methods:SetEnabled(value) self.enabled = value end
function methods:SetAlpha() end
function methods:IsShown() return self.shown end
function methods:Hide() self.shown = false end
function methods:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:SetMinMaxValues(low, high)
    self.low, self.high = low, high
    if self.value then self:SetValue(self.value) end
end
function methods:SetValue(value)
    value = math.max(self.low, math.min(self.high, value))
    if self.value == value then return end
    self.value = value
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
end
function methods:GetValue() return self.value end
function methods:CreateFontString() return Frame(self) end
function methods:CreateTexture() return Frame(self) end
for _, name in ipairs({ 'SetJustifyH', 'SetWordWrap', 'SetOrientation', 'SetValueStep', 'SetObeyStepOnDrag',
    'SetAutoFocus', 'SetTexture', 'SetAllPoints', 'EnableMouse' }) do methods[name] = function() end end
local env = setmetatable({}, { __index = _G })
env._G = env
env.CreateFrame = function(_, _, parent) return Frame(parent) end
local T = { text = { 1, 1, 1 }, muted = {}, input = {}, lineSoft = {}, warning = { 1, .2, .1 } }
function T:Font(region, size) region:SetFont('Theme font', size) end
function T:SkinTab() end
function T:PaintButton(button, selected) button.selected = selected end
function T:SkinSlider() return function() end end
local ns = { Settings = T, media = '' }
ns.GetLocale = function() return 'enUS' end
ns.Tint, ns.SnapTexture = function() end, function() end
local chunk = assert(loadfile(ADDON_ROOT .. '/Widgets.lua')); setfenv(chunk, env); chunk('Sintezza_Theme', ns)
local W = ns:CreateWidgets(T)
local parent, selected = Frame(), 'killers'
parent:SetSize(1000, 600)
local tabs = W:Segmented(parent, { 'Killers', 'Attackers', 'Defeated' }, { 'killers', 'attackers', 'defeated' },
    function() return selected end, function(value) selected = value end, true)
for _, width in ipairs({ 820, 320, 900, 180, 820 }) do
    tabs:SetSize(width, 32)
    tabs:Refresh()
    for index, button in ipairs(tabs.buttons) do
        check(button:GetWidth() > 0 and button:GetWidth() <= 138, 'segmented tab width is overconstrained')
        check(button:GetHeight() == 28, 'segmented tab height')
        check(button:GetLeft() >= 0 and button:GetRight() <= width + .01, 'segmented tab escapes the available width')
        if index > 1 then check(button:GetLeft() >= tabs.buttons[index - 1]:GetRight() + 1.99, 'segmented tabs overlap') end
    end
end
tabs.buttons[2].scripts.OnClick(tabs.buttons[2])
check(selected == 'attackers' and tabs.buttons[2].selected, 'segmented selection did not refresh')
tabs:Hide(); tabs.w = 600; tabs:Show()
check(tabs.buttons[1]:GetWidth() == 138, 'segmented tabs did not refresh after reopening')

local value, writes = 25, 0
local slider = W:SliderRow(parent, 'Episodes', -32, 60, 1, function() return value end,
    function(nextValue) value, writes = nextValue, writes + 1 end)
slider:SetWidth(400)
check(slider.edit:GetText() == '25' and writes == 0, 'initial slider refresh must not write the profile')
check(slider.edit:GetWidth() == 40 and slider.slider:GetWidth() == 130, 'numeric slider geometry changed')
slider:Hide(); value = 0; slider.edit:SetText(''); slider:Show()
check(slider.edit:GetText() == '0', 'reopening a slider must restore its zero value')
check(writes == 0, 'show refresh must not mutate stored values')
slider.slider:SetValue(7)
check(value == 7 and slider.edit:GetText() == '7', 'slider drag did not update value text')
slider.edit:SetText('0'); slider.edit.scripts.OnEnterPressed(slider.edit)
check(value == 0 and slider.edit:GetText() == '0', 'typed zero did not persist')
slider:SetRange(0, 20); slider:Refresh()
check(slider.edit:GetText() == '0', 'range refresh lost the zero value')

local accepted, commits, limited = 0, 0, nil
limited = W:SliderRow(parent, 'Accepted value', 0, 999, 1, function() return accepted end, function(proposed)
    commits = commits + 1
    accepted = math.min(996, proposed)
    limited:Refresh()
    if commits == 1 then limited.slider.scripts.OnValueChanged(limited.slider, proposed) end
end)
limited.slider:SetValue(999)
check(commits == 1, 'nested native notifications must not re-enter the profile setter')
check(limited.slider:GetValue() == 996 and limited.edit:GetText() == '996', 'knob and text must show the accepted stored value')
limited.slider.scripts.OnValueChanged(limited.slider, 996)
check(commits == 1, 'unchanged value notifications must not write the profile')

local linked = { 10, 15 }
local first, second
local writesA, writesB = 0, 0
first = W:SliderRow(parent, 'First', 0, 200, 1, function() return linked[1] end, function(v)
    writesA = writesA + 1; linked[1], linked[2] = v, math.max(v, linked[2]); first:Refresh(); second:Refresh()
end)
second = W:SliderRow(parent, 'Second', 0, 200, 1, function() return linked[2] end, function(v)
    writesB = writesB + 1; linked[2] = v
end)
first.slider:SetValue(30)
check(linked[1] == 30 and linked[2] == 30 and writesA == 1 and writesB == 0,
    'coupled updates should synchronize the second slider without invoking its setter')
check(first.edit:GetText() == '30' and second.edit:GetText() == '30', 'coupled text values disagree with stored values')
local fail, saved = true, 0
local recovering = W:SliderRow(parent, 'Recovery', 0, 20, 1, function() return saved end, function(v)
    if fail then error('fixture setter failed') end
    saved = v
end)
check(not pcall(recovering.slider.SetValue, recovering.slider, 5), 'setter failure must remain observable')
fail = false; recovering.slider:SetValue(6)
check(saved == 6 and recovering.edit:GetText() == '6', 'failed setter must not leave slider synchronization locked')
print('PASS: ' .. checks .. ' real shared-widget geometry and value assertions')
