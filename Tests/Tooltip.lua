local root = ADDON_ROOT
local checks = 0
local function check(value, message) checks = checks + 1; assert(value, message) end
local frames, cursorX, cursorY = {}, 100, 400
local methods = {}
local function Frame(parent)
    local frame = setmetatable({ parent = parent, scripts = {}, visible = true, width = 800, height = 600, scale = 1 }, { __index = methods })
    frames[#frames + 1] = frame
    return frame
end
function methods:SetWidth(value) self.width = value end
function methods:SetHeight(value) self.height = value end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:GetEffectiveScale() return self.parent and self.parent:GetEffectiveScale() or self.scale end
function methods:SetPoint(...) self.point = { ... }; self.points = self.points or {}; self.points[select(1, ...)] = self.point; self.moves = (self.moves or 0) + 1 end
function methods:ClearAllPoints() self.point, self.points = nil, {} end
function methods:SetScript(key, callback) self.scripts[key] = callback end
function methods:GetScript(key) return self.scripts[key] end
function methods:HookScript(key, callback)
    local previous = self.scripts[key]
    self.scripts[key] = function(...) if previous then previous(...) end; callback(...) end
end
function methods:GetNumPoints() local count = 0; for _ in pairs(self.points or {}) do count = count + 1 end; return count end
function methods:GetPoint(index) for _, point in pairs(self.points or {}) do index = index - 1; if index == 0 then return unpack(point) end end end
function methods:SetText(text) self.text = text end
function methods:GetStringWidth() return #(self.text or '') * 5 end
function methods:GetStringHeight() return 14 * math.max(1, math.ceil(self:GetStringWidth() / math.max(1, self.width))) end
function methods:IsVisible() return self.visible end
function methods:GetBottom() return 100 end
function methods:Show() self.visible = true end
function methods:Hide()
    self.visible = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:CreateFontString() return Frame(self) end
function methods:CreateTexture() return Frame(self) end
function methods:RegisterEvent(event) self.events = self.events or {}; self.events[event] = true end
function methods:UnregisterEvent(event) if self.events then self.events[event] = nil end end
for _, name in ipairs({ 'SetFrameStrata', 'SetClampedToScreen', 'SetJustifyH', 'SetWordWrap', 'SetTexture', 'SetAllPoints' }) do
    methods[name] = function() end
end
local env = setmetatable({}, { __index = _G })
env._G = env
env.UIParent = Frame()
env.CreateFrame = function(_, _, parent) return Frame(parent) end
env.GetCursorPosition = function() return cursorX, cursorY end
local ns = { Settings = { input = {}, accentLine = {}, text = {}, muted = {} }, media = '' }
ns.GetLocale = function() return 'enUS' end
ns.Settings.Backdrop = function() end
ns.Settings.HeaderSurface = function() end
ns.Settings.Font = function(_, region, size, flags, color, role) region.fontRole = role end
ns.TrackAppearance = function() end
ns.Tint = function() end
local function load(name)
    local chunk = assert(loadfile(root .. '/' .. name)); setfenv(chunk, env); chunk('Sintezza_Theme', ns)
end
load('Help.lua')
load('Widgets.lua')
local W = ns:CreateWidgets(ns.Settings)
local owner = Frame(env.UIParent)
W:Tooltip(owner, 'Title', 'Body', 'cursor')
local tip
for _, frame in ipairs(frames) do if frame.owner == owner then tip = frame end end
check(tip and tip.point[2] == env.UIParent, 'cursor tooltip must anchor to screen, not the full owner row')
check(tip.point[1] == 'TOPLEFT' and tip.point[4] == 112 and tip.point[5] == 388, 'normal cursor offset')
check(tip:GetScript('OnUpdate') ~= nil, 'visible cursor tooltip should follow movement')
local moves = tip.moves
tip:GetScript('OnUpdate')(tip)
check(tip.moves == moves, 'stationary cursor should not reanchor every frame')
W:Tooltip(owner, 'Title', 'Body', 'cursor')
check(tip.point ~= nil, 'reopening the same cursor tooltip must keep its anchor')
env.UIParent.scale, env.UIParent.width, env.UIParent.height = .5, 1600, 1200
tip:GetScript('OnUpdate')(tip)
check(tip.point[4] == 212 and tip.point[5] == 788, 'visible tooltip must react to UI scale changes at a stationary cursor')
env.UIParent.scale, env.UIParent.width, env.UIParent.height = 1, 800, 600
cursorX, cursorY = 790, 10
tip:GetScript('OnUpdate')(tip)
check(tip.point[1] == 'BOTTOMRIGHT' and tip.point[4] == 778 and tip.point[5] == 22, 'cursor tooltip must flip near right/bottom edges')
ns:HideTooltip(owner)
check(not tip.visible and tip:GetScript('OnUpdate') == nil and tip.owner == nil, 'hide must stop tracking and release ownership')

W:Tooltip(owner, '', 'Default tooltip')
check(tip.point[2] == owner and tip:GetScript('OnUpdate') == nil, 'existing default tooltip anchoring must remain unchanged')
check(tip.note.text == 'Default tooltip', 'empty title must not add a blank header')
ns:HideTooltip(owner)
env.UIParent.scale = .5
cursorX, cursorY = 100, 200
W:Tooltip(owner, 'Scaled', 'Body', 'cursor')
check(tip.point[4] == 212 and tip.point[5] == 388, 'cursor position must respect effective UI scale')
owner.visible = false
tip:GetScript('OnUpdate')(tip)
check(not tip.visible and tip:GetScript('OnUpdate') == nil, 'hidden owners must stop cursor tracking')
owner.visible = true
env.GetCursorPosition = false
W:Tooltip(owner, 'Fallback', 'Body', 'cursor')
check(tip.point[2] == owner and tip:GetScript('OnUpdate') == nil, 'missing cursor API should use normal owner anchoring')
ns:HideTooltip(owner)

local window = Frame(env.UIParent)
local header = W:WindowHeader(window, { title = 'Sintezza Rivals', version = '1.14.0', close = false, icon = 'icon' })
check(header.title.points.LEFT[5] == 0 and header.subtitle == nil, 'subtitle-free header title must be vertically centered')
check(header.version.points.LEFT[2] == header.title and header.version.points.LEFT[3] == 'RIGHT', 'version should sit beside the title')
check(header.title.fontRole == 'display', 'shared header must use Theme heading font role')
local row, label = Frame(env.UIParent), Frame()
label:SetWidth(0); label:SetText('Short')
ns:AttachHelp(row, ns.Settings, 'Help', label)
check(row.helpButton.point[4] == 31, 'unresolved label width must not move the help button onto its text')
label:SetWidth(250); label:SetText('A much longer heading')
ns:AttachHelp(row, ns.Settings, 'New help', label)
check(row.helpButton.point[4] == label:GetStringWidth() + 6 and row.helpButton.helpText == 'New help',
    'reusing help after a caption change must reposition the trigger')
print('PASS: ' .. checks .. ' shared tooltip and header assertions')
