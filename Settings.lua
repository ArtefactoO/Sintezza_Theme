local name, ns = ...
local fonts = ns.Fonts
local english = ns:GetLocale() == "enUS"
local title = "Sintezza Theme"
local minimapButton
local sharedFont = english and "Shared interface font" or "Общий шрифт интерфейса"
local headingFont = english and "Heading font" or "Шрифт заголовков"
local palettes = {
    { "BRASS", english and "Teal" or "Бирюза" },
    { "EMBER", english and "Ember" or "Эмбер" },
    { "COPPER", english and "Copper" or "Медь" },
    { "FOREVER", english and "Old Gold" or "Старое золото" },
    { "FROST", english and "Ice" or "Лед" },
    { "ARCANE", english and "Amethyst" or "Аметист" },
}

local panel = CreateFrame("Frame")
panel.name = title
local widgets = ns:CreateWidgets(ns.Settings)
local theme = ns.Settings
local shell = CreateFrame("Frame", nil, panel, "BackdropTemplate")
shell:SetPoint("TOPLEFT", 14, -14)
shell:SetPoint("TOPRIGHT", -14, -14)
theme:WindowSurface(shell)
local header = widgets:WindowHeader(shell, {
    title = title, icon = ns.icons.Sintezza_Theme, height = 64, titleSize = 22, close = false,
})
local section = CreateFrame("Frame", nil, shell, "BackdropTemplate")
section:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 12, -12)
section:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -12, -12)
section:SetHeight(27)
theme:SectionSurface(section)
local sectionTitle = widgets:Label(section, english and "Palette" or "Палитра", 12, theme.text, "display")
sectionTitle:SetPoint("LEFT", 10, 0)

local notice = widgets:Label(shell, "", 11, theme.muted)
local function RefreshNotice()
    local preference = fonts:GetSettings().locale
    if ns:ResolveLocale(preference) ~= ns:GetLocale() then
        notice:SetText(english and "Use /reload to apply the language." or "Для смены языка введи /reload.")
    elseif ns.pendingAppearance then
        notice:SetText(english and "Applies after combat." or "Применится после боя.")
    else
        notice:SetText("")
    end
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
            function(_, button) if button == "LeftButton" then ns:OpenSettings() end end,
            function(tooltip) tooltip:AddLine(title) end)
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
local motion = widgets:Toggle(shell, english and "Interface animations and decorative effects" or "Анимации интерфейса и декоративные эффекты",
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
local minimap = widgets:Toggle(shell, english and "Minimap button" or "Кнопка у миникарты",
    function() return not MinimapSettings().hide end, function(show)
        MinimapSettings().hide = not show
        RefreshMinimap()
    end)
notice:SetPoint("TOPLEFT", minimap, "BOTTOMLEFT", 0, -7)
local lastWidth
local function Layout(_, width)
    if width == lastWidth then return end
    lastWidth = width
    local twoColumns = width >= 620
    local columns = twoColumns and #swatches or 3
    local swatchWidth = math.max(78, math.floor((width - 44 - (columns - 1) * 6) / columns))
    for index, entry in ipairs(swatches) do
        local column, row = (index - 1) % columns, math.floor((index - 1) / columns)
        entry.button:ClearAllPoints()
        entry.button:SetWidth(swatchWidth)
        entry.button:SetPoint("TOPLEFT", section, "BOTTOMLEFT", 10 + column * (swatchWidth + 6), -6 - row * 48)
    end
    local offset = twoColumns and -58 or -106
    local function Place(row, y, column)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", section, column == "right" and "BOTTOM" or "BOTTOMLEFT",
            column == "right" and 7 or 10, y)
        row:SetPoint("TOPRIGHT", section, column == "left" and "BOTTOM" or "BOTTOMRIGHT",
            column == "left" and -7 or -10, y)
    end
    Place(font, offset, twoColumns and "left")
    Place(heading, twoColumns and offset or offset - 32, twoColumns and "right")
    Place(language, offset - (twoColumns and 32 or 64))
    Place(motion, offset - (twoColumns and 64 or 96))
    Place(minimap, offset - (twoColumns and 96 or 128))
    shell:SetHeight(twoColumns and 314 or 394)
end
shell:HookScript("OnSizeChanged", Layout)
Layout(shell, shell:GetWidth())
panel:SetScript("OnShow", function()
    RefreshSwatches()
    font:Refresh()
    heading:Refresh()
    language:Refresh()
    motion:Refresh(false)
    minimap:Refresh(false)
    RefreshNotice()
end)

local category
panel:RegisterEvent("ADDON_LOADED")
panel:RegisterEvent("PLAYER_LOGIN")
panel:RegisterEvent("PLAYER_REGEN_ENABLED")
panel:SetScript("OnEvent", function(self, event, loaded)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent(event)
        RefreshMinimap()
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        if ns.pendingAppearance then ApplyAppearance(); RefreshSwatches() end
        return
    end
    if loaded ~= name then return end
    self:UnregisterEvent("ADDON_LOADED")
    ApplyAppearance()
    RefreshSwatches()
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        category = Settings.RegisterCanvasLayoutCategory(panel, title)
        Settings.RegisterAddOnCategory(category)
    end
    RefreshMinimap()
end)

function ns:OpenSettings()
    if category and Settings.OpenToCategory then Settings.OpenToCategory(category:GetID()) end
end

function ns:RegisterSettingsPage(frame, label)
    if category and Settings.RegisterCanvasLayoutSubcategory then
        return Settings.RegisterCanvasLayoutSubcategory(category, frame, label)
    end
end

SLASH_SINTEZZA_THEME1 = "/stheme"
SLASH_SINTEZZA_THEME2 = "/sintezzatheme"
SlashCmdList.SINTEZZA_THEME = function() ns:OpenSettings() end
