local assertions = 0
local function Check(value, description)
    assertions = assertions + 1
    assert(value, description)
end

local function Machine(saved, inCombat, locale)
    local state = { combat = inCombat }
    local frames = {}
    local methods = {}
    local function Frame(name)
        local frame = setmetatable({ name = name, width = 760, height = 28, shown = true,
            scripts = {}, events = {}, showCalls = 0, raiseCalls = 0 }, { __index = methods })
        if name then frames[name] = frame end
        return frame
    end
    function methods:GetName() return self.name end
    function methods:Hide()
        local changed = self.shown
        self.shown = false
        if changed and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function methods:Show()
        self.showCalls = self.showCalls + 1
        if state.failShow then error("show failed") end
        if state.suppressShow then return end
        local changed = not self.shown
        self.shown = true
        if changed and self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function methods:Raise()
        self.raiseCalls = self.raiseCalls + 1
        if state.failRaise then error("raise failed") end
    end
    function methods:IsShown() return self.shown end
    function methods:IsVisible() return self.shown end
    function methods:SetShown(value) if value then self:Show() else self:Hide() end end
    function methods:SetSize(width, height) self.width, self.height = width, height end
    function methods:SetWidth(width) self.width = width end
    function methods:GetWidth() return self.width end
    function methods:SetHeight(height) self.height = height end
    function methods:GetHeight() return self.height end
    function methods:SetText(text) self.text = text end
    function methods:GetText() return self.text end
    function methods:SetScript(event, callback) self.scripts[event] = callback end
    function methods:HookScript(event, callback)
        local original = self.scripts[event]
        self.scripts[event] = function(...)
            if original then original(...) end
            callback(...)
        end
    end
    function methods:RegisterEvent(event) self.events[event] = true end
    function methods:UnregisterEvent(event) self.events[event] = nil end
    function methods:SetPoint(...) self.point = { ... } end
    function methods:ClearAllPoints() self.point = nil end
    function methods:CreateTexture() return Frame() end
    function methods:Refresh() end
    function methods:RefreshRange() end
    function methods:SetFrameStrata() end
    function methods:SetClampedToScreen() end
    function methods:SetMovable() end
    function methods:EnableMouse() end
    function methods:RegisterForDrag() end
    function methods:StartMoving() end
    function methods:StopMovingOrSizing() end
    function methods:SetJustifyH() end
    function methods:SetWordWrap() end
    function methods:SetColorTexture() end
    local function Row()
        local row = Frame()
        row.label, row.slider, row.button, row.text = Frame(), Frame(), Frame(), Frame()
        return row
    end
    local widgets = {}
    function widgets:WindowHeader() return Frame() end
    function widgets:ScrollFrame() return Frame(), Frame(), Frame() end
    function widgets:Section()
        local row = Frame()
        row.headerHeight = 24
        return row
    end
    function widgets:Label(_, text)
        local row = Frame()
        row:SetText(text)
        return row
    end
    function widgets:Button() return Row() end
    function widgets:Toggle() return Row() end
    function widgets:ChoiceRow() return Row() end
    function widgets:SliderRow() return Row() end
    function widgets:ActionRow() return Row() end
    function widgets:Help(row) return row end
    local ns = {
        Settings = { muted = { .8, .7, .6 } }, icons = { Sintezza_Theme = "icon" },
    }
    function ns.Settings:WindowSurface() end
    function ns.Settings:PaintButton() end
    function ns:CreateWidgets() return widgets end
    function ns:NewWindowPreferences()
        return { CanMove = function() return true end, Bind = function() end }
    end
    function ns:RefreshAppearance() self.pendingAppearance = state.combat and true or nil end
    function ns:GetGlobalWindowOptions() return { scale = 100, opacity = 100, layer = "DEFAULT" } end
    function ns:GetGlobalWindowConflicts() return {} end
    function ns:ApplyGlobalWindowOptions() end
    function ns:GetPalette() return "BRASS" end
    function ns:GetPaletteSwatch() return { 1, 1, 1 }, { .2, .2, .2 }, { .6, .5, .4 } end
    function ns:GetButtonStyle() return "BRONZE" end
    function ns:GetBackgroundStrength() return 100 end
    function ns:CreateMinimapButton(_, _, _, action)
        local button = Frame()
        state.minimapAction = action
        return button
    end
    function ns:RegisterLauncherPage(options)
        state.launcher = options
        return {}
    end
    local env = setmetatable({
        Sintezza_ThemeDB = saved,
        GetLocale = function() return locale or "enUS" end,
        InCombatLockdown = function() return state.combat end,
        CreateFrame = function(_, name) return Frame(name) end,
        UISpecialFrames = {}, SlashCmdList = {}, UIParent = Frame("UIParent"), Settings = {},
    }, { __index = _G })
    for _, name in ipairs({ "Locale.lua", "Fonts.lua", "Settings.lua" }) do
        local chunk = assert(loadfile(ADDON_ROOT .. "/" .. name))
        setfenv(chunk, env)
        chunk("Sintezza_Theme", ns)
    end
    local panel = frames.Sintezza_ThemeSettings
    local result = { ns = ns, state = state, panel = panel, env = env }
    function result:Fire(event, name)
        panel.scripts.OnEvent(panel, event, name)
    end
    function result:Load()
        self:Fire("ADDON_LOADED", "OtherAddon")
        Check(panel.showCalls == 0, "another addon never opens Theme")
        self:Fire("ADDON_LOADED", "Sintezza_Theme")
        Check(panel.showCalls == 0, "loading Theme waits for login")
    end
    return result
end

local fresh = Machine(nil, false)
fresh:Load()
fresh:Fire("PLAYER_LOGIN")
Check(fresh.panel.showCalls == 1 and fresh.panel:IsShown(), "first login opens settings")
Check(fresh.env.Sintezza_ThemeDB.settingsOpened == true, "successful opening is saved")
Check(not fresh.panel.events.PLAYER_LOGIN, "login event is unregistered")
fresh.panel:Hide()
fresh:Fire("PLAYER_LOGIN")
fresh:Fire("PLAYER_REGEN_ENABLED")
Check(fresh.panel.showCalls == 1 and not fresh.panel:IsShown(), "duplicate login and combat-end do not reopen")

for _, reason in ipairs({ "reload", "other character", "reinstalled files" }) do
    local nextLogin = Machine(fresh.env.Sintezza_ThemeDB, false)
    nextLogin:Load()
    nextLogin:Fire("PLAYER_LOGIN")
    Check(nextLogin.panel.showCalls == 0, reason .. " keeps the completed introduction")
end

local old = { palette = "COPPER", interfaceFont = "LSM:Old font", custom = { untouched = 7 },
    minimap = { hide = true, minimapPos = 77 }, settingsWindow = { scale = 125 } }
local oldNested = old.custom
local legacy = Machine(old, false, "ruRU")
legacy:Load()
legacy:Fire("PLAYER_LOGIN")
Check(legacy.panel.showCalls == 1 and old.settingsOpened == true, "old profiles get one opening")
Check(legacy.env.Sintezza_ThemeDB == old and old.custom == oldNested, "old profile identity is retained")
Check(old.palette == "COPPER" and old.interfaceFont == "LSM:Old font" and old.custom.untouched == 7,
    "legacy fields are retained")
Check(old.minimap.hide and old.minimap.minimapPos == 77 and old.settingsWindow.scale == 125,
    "legacy minimap and window preferences are retained")

local waiting = Machine({}, true)
waiting:Load()
waiting:Fire("PLAYER_LOGIN")
Check(waiting.panel.showCalls == 0 and waiting.env.Sintezza_ThemeDB.settingsOpened == nil, "combat login defers opening")
waiting:Fire("PLAYER_REGEN_ENABLED")
Check(waiting.panel.showCalls == 0, "a combat-end event does not open during combat")
waiting.state.combat = false
waiting:Fire("PLAYER_REGEN_ENABLED")
Check(waiting.panel.showCalls == 1 and waiting.env.Sintezza_ThemeDB.settingsOpened, "combat end opens once")
waiting.panel:Hide()
waiting:Fire("PLAYER_REGEN_ENABLED")
Check(waiting.panel.showCalls == 1 and not waiting.panel:IsShown(), "later combat ends stay closed")

local manual = Machine({}, false)
manual:Load()
manual.ns:OpenSettings()
Check(manual.env.Sintezza_ThemeDB.settingsOpened, "manual opening records completion")
manual.panel:Hide()
manual:Fire("PLAYER_LOGIN")
Check(manual.panel.showCalls == 1 and not manual.panel:IsShown(), "manual opening before login completes introduction")

local deferredManual = Machine({}, true)
deferredManual:Load()
deferredManual:Fire("PLAYER_LOGIN")
deferredManual.env.SlashCmdList.SINTEZZA_THEME()
Check(deferredManual.panel.showCalls == 1 and deferredManual.env.Sintezza_ThemeDB.settingsOpened,
    "manual slash opening completes combat-pending introduction")
deferredManual.panel:Hide()
deferredManual.state.combat = false
deferredManual:Fire("PLAYER_REGEN_ENABLED")
Check(deferredManual.panel.showCalls == 1, "completed manual opening cancels deferred auto-open")

for _, entry in ipairs({ "launcher", "minimap" }) do
    local shortcut = Machine({}, false)
    shortcut:Load()
    if entry == "launcher" then shortcut.state.launcher.open()
    else shortcut.state.minimapAction.open() end
    shortcut.panel:Hide()
    shortcut:Fire("PLAYER_LOGIN")
    Check(shortcut.panel.showCalls == 1 and not shortcut.panel:IsShown(), entry .. " completes first run")
end

local alreadyOpen = Machine({}, false)
alreadyOpen:Load()
alreadyOpen.panel:Show()
alreadyOpen:Fire("PLAYER_LOGIN")
Check(alreadyOpen.panel.showCalls == 1 and alreadyOpen.env.Sintezza_ThemeDB.settingsOpened,
    "existing visible panel is recorded without showing it again")

for _, failure in ipairs({ "failShow", "failRaise", "suppressShow" }) do
    local retry = Machine({}, false)
    retry:Load()
    retry.state[failure] = true
    local ok = pcall(retry.Fire, retry, "PLAYER_LOGIN")
    Check(ok == (failure == "suppressShow"), "native failure reaches the caller")
    Check(retry.env.Sintezza_ThemeDB.settingsOpened == nil, failure .. " is not recorded as completion")
    retry.state[failure] = false
    retry:Fire("PLAYER_REGEN_ENABLED")
    Check(retry.env.Sintezza_ThemeDB.settingsOpened == true and retry.panel:IsShown(), failure .. " can retry")
end

local completedCombat = Machine({ settingsOpened = true }, true)
completedCombat:Load()
completedCombat:Fire("PLAYER_LOGIN")
completedCombat.state.combat = false
completedCombat:Fire("PLAYER_REGEN_ENABLED")
Check(completedCombat.panel.showCalls == 0, "completed accounts stay closed during combat login")

print("PASS: Theme first-run lifecycle (" .. assertions .. " assertions)")
return assertions
