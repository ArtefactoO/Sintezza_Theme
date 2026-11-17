local name, ns = ...
local fonts = ns.Fonts
local english = ns:GetLocale() == "enUS"
local function Text(en, ru) return english and en or ru end
local title = "Sintezza Theme"
local minimapButton
local sharedFont = Text("Interface font", "Шрифт интерфейса")
local headingFont = english and "Heading font" or "Шрифт заголовков"
local palettes = {
    { "BRASS", english and "Teal" or "Бирюза" },
    { "EMBER", english and "Ember" or "Эмбер" },
    { "COPPER", english and "Copper" or "Медь" },
    { "FOREVER", english and "Old Gold" or "Старое золото" },
    { "FROST", english and "Ice" or "Лед" },
    { "ARCANE", english and "Amethyst" or "Аметист" },
    { "GRAPHITE", Text("Graphite", "Графит") },
}

local panel = CreateFrame("Frame", "Sintezza_ThemeSettings", UIParent, "BackdropTemplate")
panel:Hide()
panel:SetSize(780, 460)
panel:SetPoint("CENTER")
panel:SetFrameStrata("DIALOG")
panel:SetClampedToScreen(true)
panel:SetMovable(true)
panel:EnableMouse(true)
if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = panel:GetName() end

local widgets = ns:CreateWidgets(ns.Settings)
local theme = ns.Settings
theme:WindowSurface(panel)
local header = widgets:WindowHeader(panel, {
    title = title, addonName = name, icon = ns.icons.Sintezza_Theme,
})
local window = ns:NewWindowPreferences(function() return fonts:GetSettings() end, nil, "settingsWindow")
header:EnableMouse(true)
header:RegisterForDrag("LeftButton")
header:SetScript("OnDragStart", function()
    if window:CanMove() then panel:StartMoving() end
end)
header:SetScript("OnDragStop", function() panel:StopMovingOrSizing() end)
panel:HookScript("OnHide", function() panel:StopMovingOrSizing() end)

local scroll, shell, bar = widgets:ScrollFrame(panel)
scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -19, 12)
bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 2, -4)
bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 2, 3)
local function Section(label)
    local section = widgets:Section(shell, label, nil, "settings")
    section:SetHeight(section.headerHeight)
    return section
end

local paletteTitle = Section(Text("Color scheme", "Цветовая схема"))
local buttonTitle = Section(Text("Buttons and background", "Кнопки и фон"))
local interfaceTitle = Section(Text("Interface", "Интерфейс"))
local windows = Section(Text("All addon windows", "Окна всех аддонов"))
local Layout
local notice = widgets:Label(shell, "", 11, theme.muted)
notice:SetHeight(16)
local function RefreshNotice()
    local preference = fonts:GetSettings().locale
    if ns:ResolveLocale(preference) ~= ns:GetLocale() then
        notice:SetText(english and "Use /reload to apply the language." or "Для смены языка введи /reload.")
    elseif ns.pendingAppearance then
        notice:SetText(english and "Applies after combat." or "Применится после боя.")
    else
        notice:SetText("")
    end
    if Layout then Layout(scroll, scroll:GetWidth()) end
end
local function ApplyAppearance()
    ns:RefreshAppearance()
    RefreshNotice()
end

local function MinimapSettings()
    local settings = fonts:GetSettings()
    if type(settings.minimap) ~= "table" then settings.minimap = { minimapPos = 285 } end
    return settings.minimap
end

local function RefreshMinimap()
    local settings = MinimapSettings()
    if minimapButton then
        minimapButton:Refresh(settings)
    else
        minimapButton = ns:CreateMinimapButton(name, ns.icons.Sintezza_Theme, settings,
            {
                window = function() return panel end,
                open = function() ns:OpenSettings() end,
            },
            function(tooltip)
                tooltip:AddLine(title)
                ns:AddMinimapToggleHint(tooltip)
            end)
    end
end

local swatches = {}
local function RefreshSwatches()
    local current = ns:GetPalette()
    for _, entry in ipairs(swatches) do theme:PaintButton(entry.button, entry.id == current) end
end

for _, option in ipairs(palettes) do
    local id, label = unpack(option)
    local button = widgets:Button(shell, label, function()
        fonts:GetSettings().palette = id
        ApplyAppearance()
        if not ns.pendingAppearance then RefreshSwatches() end
    end)
    button:SetHeight(42)
    button.text:ClearAllPoints()
    button.text:SetPoint("BOTTOMLEFT", 3, 5)
    button.text:SetPoint("BOTTOMRIGHT", -3, 5)
    local previous
    for _, color in ipairs({ ns:GetPaletteSwatch(id) }) do
        local sample = button:CreateTexture(nil, "ARTWORK")
        sample:SetColorTexture(unpack(color))
        sample:SetSize(18, 9)
        if previous then sample:SetPoint("LEFT", previous, "RIGHT")
        else sample:SetPoint("TOPLEFT", button, "TOP", -27, -6) end
        previous = sample
    end
    swatches[#swatches + 1] = { id = id, button = button }
end
local function FontChoices()
    local choices = {}
    for _, option in ipairs(fonts:Choices(false)) do choices[option[1]] = option[2] end
    return choices
end
local function HeadingFontChoices()
    local choices = FontChoices()
    choices.SHARED = english and "Same as interface" or "Как в интерфейсе"
    choices.THEME = "Spectral"
    return choices
end
local font = widgets:ChoiceRow(shell, sharedFont, FontChoices,
    function() return fonts:GetSettings().interfaceFont or "THEME" end,
    function(value)
        fonts:GetSettings().interfaceFont = value
        ApplyAppearance()
    end, { THEME = 1, DEFAULT = 2, COMBAT = 3 })
local heading = widgets:ChoiceRow(shell, headingFont, HeadingFontChoices,
    function() return fonts:GetSettings().titleFont or "THEME" end,
    function(value)
        fonts:GetSettings().titleFont = value
        ApplyAppearance()
    end, { THEME = 1, SHARED = 2, DEFAULT = 3, COMBAT = 4 })
local buttonStyle = widgets:ChoiceRow(shell, Text("Button style", "Стиль кнопок"), {
    BRONZE = Text("Clipped Corners", "Срезанные углы"),
    STEEL = Text("Fine Edge", "Тонкая кромка"),
    BRACKETS = Text("Brackets", "Скобы"),
    WEDGE = Text("Slanted Edge", "Косой край"),
    COIN = Text("Minted Stamp", "Чеканка"),
}, function() return ns:GetButtonStyle() end, function(value)
    ns:SetButtonStyle(value)
    RefreshNotice()
end, { BRONZE = 1, STEEL = 2, BRACKETS = 3, WEDGE = 4, COIN = 5 })
local motion = widgets:Toggle(shell, Text("Animations and effects", "Анимации и эффекты"),
    function() return fonts:GetSettings().animateControls ~= false end,
    function(value)
        fonts:GetSettings().animateControls = value
        ApplyAppearance()
    end)
widgets:Help(motion, english and "Controls the header sheen and transitions of shared interface controls."
    or "Управляет бликом в шапках и плавными переходами общих элементов интерфейса.")
local language = widgets:ChoiceRow(shell, english and "Addon language" or "Язык аддонов", {
    auto = english and "Game language" or "Язык игры",
    ruRU = "Русский",
    enUS = "English",
}, function()
    local preference = fonts:GetSettings().locale
    return (preference == "ruRU" or preference == "enUS") and preference or "auto"
end, function(value)
    fonts:GetSettings().locale = value ~= "auto" and value or nil
    RefreshNotice()
end, { auto = 1, ruRU = 2, enUS = 3 })
local minimap = widgets:Toggle(shell, Text("Theme minimap button", "Значок Theme у миникарты"),
    function() return not MinimapSettings().hide end, function(show)
        MinimapSettings().hide = not show
        RefreshMinimap()
    end)

local function SliderHelp(row, text)
    row.label:SetPoint("RIGHT", row.slider, "LEFT", -8, 0)
    return widgets:Help(row, text)
end

local function BackgroundSlider(key, label, help)
    local row = widgets:SliderRow(shell, label, 0, 100, 5,
        function() return ns:GetBackgroundStrength(key) end,
        function(value)
            ns:SetBackgroundStrength(key, value)
            RefreshNotice()
        end, "%")
    return SliderHelp(row, help)
end

local tint = BackgroundSlider("tint", Text("Background tint", "Тонировка фона"),
    Text("Controls how strongly the color scheme tints the stone background.",
        "Задает, насколько сильно цвета схемы тонируют каменный фон."))
local texture = BackgroundSlider("texture", Text("Background texture", "Фактура фона"),
    Text("Controls the visibility of the stone pattern and grain.",
        "Задает видимость рисунка и зерна камня."))

local draft = ns:GetGlobalWindowOptions()
local applyRow
local function DraftSetter(key)
    return function(value)
        draft[key] = value
        if applyRow then applyRow.label:SetText("") end
    end
end
local scale = SliderHelp(widgets:SliderRow(shell, Text("Scale", "Масштаб"), 50, 200, 5,
    function() return draft.scale end, DraftSetter("scale"), "%"),
    Text("Sets the scale of the connected Sintezza windows.", "Задает масштаб подключенных окон Sintezza."))
local opacity = SliderHelp(widgets:SliderRow(shell, Text("Opacity", "Непрозрачность"), 20, 100, 5,
    function() return draft.opacity end, DraftSetter("opacity"), "%"),
    Text("Sets how opaque the connected Sintezza windows are.", "Задает непрозрачность подключенных окон Sintezza."))
local layer = widgets:Help(widgets:ChoiceRow(shell, Text("Layer", "Слой"), {
    DEFAULT = Text("Default", "По умолчанию"),
    MEDIUM = Text("Normal", "Обычный"),
    HIGH = Text("High", "Повышенный"),
    DIALOG = Text("Dialog", "Диалоговый"),
}, function() return draft.layer end, DraftSetter("layer"), { DEFAULT = 1, MEDIUM = 2, HIGH = 3, DIALOG = 4 }),
    Text("Sets which windows appear above the others. Default uses each window's own layer.",
        "Задает порядок перекрытия. По умолчанию сохраняется штатный слой каждого окна."))

local function ApplyWindows(values, confirmed)
    local conflicts = ns:GetGlobalWindowConflicts(values)
    local names = table.concat(conflicts, ", ")
    if #conflicts > 0 and names ~= confirmed then
        local question = Text(
            "These addons have different window settings:\n%s\n\nApply the displayed scale, opacity and layer to all connected windows?",
            "У этих аддонов заданы другие параметры окон:\n%s\n\nПрименить выбранные масштаб, непрозрачность и слой ко всем подключенным окнам?")
        widgets:Confirm(question:format(names), function() ApplyWindows(values, names) end)
        return
    end
    ns:ApplyGlobalWindowOptions(values)
    applyRow.label:SetText(InCombatLockdown() and Text("Applies after combat.", "Применится после боя.")
        or Text("Applied.", "Применено."))
end

applyRow = widgets:ActionRow(shell, "", Text("Apply to all", "Применить ко всем"), function()
    ApplyWindows({ scale = draft.scale, opacity = draft.opacity, layer = draft.layer })
end, true)
applyRow.button:SetWidth(154)
applyRow.label:SetPoint("RIGHT", applyRow.button, "LEFT", -8, 0)

local appearanceRows = { buttonTitle, buttonStyle, tint, texture, motion }
local interfaceRows = { interfaceTitle, font, heading, language, minimap }
local windowSizeRows = { scale, opacity }
local windowLayerRows = { layer, applyRow }
local lastWidth, lastNotice
Layout = function(_, width)
    local showNotice = (notice:GetText() or "") ~= ""
    if width <= 0 or (width == lastWidth and showNotice == lastNotice) then return end
    lastWidth, lastNotice = width, showNotice
    shell:SetWidth(width)

    local inset, gutter = 20, 16
    local available = math.max(1, width - 2 * inset)
    local columnWidth = (available - gutter) / 2
    local twoColumns = columnWidth >= 312
    local fitting = math.max(1, math.floor((available + 6) / 102))
    local columns = fitting >= #swatches and #swatches or math.min(fitting, 4)
    local swatchWidth = math.max(1, math.floor((available - (columns - 1) * 6) / columns))

    local function Place(row, x, y, rowWidth)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", shell, "TOPLEFT", x, y)
        row:SetWidth(rowWidth)
    end
    local function Stack(rows, x, y, rowWidth)
        for _, row in ipairs(rows) do
            Place(row, x, y, rowWidth)
            y = y - row:GetHeight() - 2
        end
        return y
    end
    local function Arrange(left, right, y)
        if twoColumns then
            local leftEnd = Stack(left, inset, y, columnWidth)
            local rightEnd = Stack(right, inset + columnWidth + gutter, y, columnWidth)
            return math.min(leftEnd, rightEnd)
        end
        local leftEnd = Stack(left, inset, y, available)
        return Stack(right, inset, leftEnd - 10, available)
    end

    Place(paletteTitle, inset, -12, available)
    local offset = -12 - paletteTitle:GetHeight() - 4
    for index, entry in ipairs(swatches) do
        local col = (index - 1) % columns
        local row = math.floor((index - 1) / columns)
        Place(entry.button, inset + col * (swatchWidth + 6), offset - row * 48, swatchWidth)
    end
    offset = offset - math.ceil(#swatches / columns) * 48 - 8
    offset = Arrange(appearanceRows, interfaceRows, offset) - 12
    notice:SetShown(showNotice)
    if showNotice then
        Place(notice, inset, offset, available)
        offset = offset - notice:GetHeight() - 8
    end
    Place(windows, inset, offset, available)
    offset = Arrange(windowSizeRows, windowLayerRows, offset - windows:GetHeight() - 2)
    shell:SetHeight(-offset + 8)
    scroll:RefreshRange()
end
scroll:HookScript("OnSizeChanged", Layout)
Layout(scroll, scroll:GetWidth())
window:Bind(panel, { resize = { minWidth = 630, minHeight = 430, maxWidth = 1100, maxHeight = 850 } })

panel:SetScript("OnShow", function()
    draft = ns:GetGlobalWindowOptions()
    RefreshSwatches()
    for _, row in ipairs({ font, heading, language, buttonStyle, motion, minimap, tint, texture, scale, opacity, layer }) do
        row:Refresh(false)
    end
    applyRow.label:SetText("")
    RefreshNotice()
end)

local category
local firstRunPending
local function OpenFirstRun()
    if firstRunPending and not InCombatLockdown() then ns:OpenSettings() end
end
panel:RegisterEvent("ADDON_LOADED")
panel:RegisterEvent("PLAYER_LOGIN")
panel:RegisterEvent("PLAYER_REGEN_ENABLED")
panel:SetScript("OnEvent", function(self, event, loaded)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent(event)
        RefreshMinimap()
        firstRunPending = fonts:GetSettings().settingsOpened ~= true
        OpenFirstRun()
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        if ns.pendingAppearance then ApplyAppearance(); RefreshSwatches() end
        OpenFirstRun()
        return
    end
    if loaded ~= name then return end
    self:UnregisterEvent("ADDON_LOADED")
    ApplyAppearance()
    RefreshSwatches()
    category = ns:RegisterLauncherPage({
        title = title, icon = ns.icons.Sintezza_Theme,
        buttonLabel = Text("Open settings", "Открыть настройки"),
        open = function() ns:OpenSettings() end,
    })
    RefreshMinimap()
end)

function ns:OpenSettings()
    if not panel:IsShown() then panel:Show() end
    panel:Raise()
    if panel:IsShown() then
        fonts:GetSettings().settingsOpened = true
        firstRunPending = nil
    end
end

function ns:RegisterSettingsPage(frame, label)
    if category and Settings.RegisterCanvasLayoutSubcategory then
        return Settings.RegisterCanvasLayoutSubcategory(category, frame, label)
    end
end

SLASH_SINTEZZA_THEME1 = "/stheme"
SLASH_SINTEZZA_THEME2 = "/sintezzatheme"
SlashCmdList.SINTEZZA_THEME = function() ns:OpenSettings() end
