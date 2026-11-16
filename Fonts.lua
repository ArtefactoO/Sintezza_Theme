local name, ns = ...
local Fonts = {}
ns.Fonts = Fonts

local russian = ns:GetLocale() == "ruRU"
local mediaPath = "Interface\\AddOns\\" .. name .. "\\Media\\"
local bundled = {
    { "Fira Sans Medium", mediaPath .. "FiraSans Medium.ttf" },
    { "Fira Sans Bold", mediaPath .. "FiraSans Bold.ttf" },
    { "Spectral Medium", mediaPath .. "Spectral-Medium.ttf" },
}
local roles = {
    body = bundled[1][2],
    display = bundled[3][2],
    setting = bundled[3][2],
}
Fonts.label = russian and "Шрифт интерфейса" or "Interface font"

local function SharedMedia()
    return LibStub and LibStub:GetLibrary("LibSharedMedia-3.0", true)
end

function Fonts:GetSettings()
    if type(Sintezza_ThemeDB) ~= "table" then Sintezza_ThemeDB = {} end
    return Sintezza_ThemeDB
end

function Fonts:AdoptLegacySelection(legacy)
    local settings = self:GetSettings()
    if settings.migratedStandaloneUI then return end
    local selection = legacy.interfaceFont
    if not settings.interfaceFont and type(selection) == "string" and selection ~= "SHARED" then
        settings.interfaceFont = selection
        legacy.interfaceFont = "SHARED"
        ns:RefreshAppearance()
    end
    settings.migratedStandaloneUI = true
end

function Fonts:Current(settings, includeShared)
    local selected = settings.interfaceFont or (includeShared == false and "THEME" or "SHARED")
    for _, choice in ipairs(self:Choices(includeShared ~= false)) do
        if choice[1] == selected then return choice[2] end
    end
    return type(selected) == "string" and selected:match("^LSM:(.+)$") or self.label
end

function Fonts:Choices(includeShared)
    local values = {
        { "THEME", russian and "Шрифт оформления" or "Theme font" },
        { "DEFAULT", russian and "Шрифт WoW" or "WoW font" },
        { "COMBAT", russian and "Боевой шрифт" or "Combat text font" },
    }
    if includeShared then table.insert(values, 1, { "SHARED", russian and "Общий шрифт Sintezza" or "Shared Sintezza font" }) end
    local names = {}
    for _, font in ipairs(bundled) do
        values[#values + 1] = { "LSM:" .. font[1], font[1] }
        names[font[1]] = true
    end
    local media = SharedMedia()
    for _, name in ipairs(media and media:List("font") or {}) do
        if not names[name] then values[#values + 1] = { "LSM:" .. name, name } end
    end
    return values
end

function Fonts:Resolve(selection, role)
    if selection == "SHARED" or selection == nil then
        local settings = Sintezza_ThemeDB
        selection = ns.pendingAppearance and ns.activeFont
            or (type(settings) == "table" and settings.interfaceFont) or "THEME"
        if role == "display" then
            local titleFont
            if ns.pendingAppearance then titleFont = ns.activeTitleFont
            elseif type(settings) == "table" then titleFont = settings.titleFont end
            titleFont = titleFont or "THEME"
            if titleFont ~= "SHARED" then selection = titleFont end
        end
    end
    local path
    if selection == "DEFAULT" then
        path = ns.Theme:GetGameTextFont()
    elseif selection == "COMBAT" then
        path = ns.Theme:GetCombatTextFont()
    elseif type(selection) == "string" and selection:sub(1, 4) == "LSM:" then
        local name = selection:sub(5)
        for _, font in ipairs(bundled) do
            if font[1] == name then return font[2] end
        end
        local media = SharedMedia()
        if media then path = media:Fetch("font", name, true) end
    end
    if type(path) == "string" and path ~= "" then return path end
end

function Fonts:Apply(region, size, flags, role)
    local path = self:Resolve(nil, role)
    if not path then return false end
    local ok, result = pcall(region.SetFont, region, path, size, flags or "")
    return ok and result ~= false
end

function Fonts:Paint(region, size, flags, role)
    if self:Apply(region, size, flags, role) then return end
    if region:SetFont(roles[role] or roles.body, size, flags or "") then return end
    local fallback = ns.Theme:GetGameTextFont()
    if fallback then region:SetFont(fallback, size, flags or "") end
end

function Fonts:ApplyTheme(region, size, flags, _, role)
    self:Paint(region, size, flags, role)
    ns:TrackAppearance(region, "font", function(target) self:Paint(target, size, flags, role) end)
end

function Fonts:CreateText(parent, layer, template, settings)
    local region = parent:CreateFontString(nil, layer, template)
    local _, size, flags = region:GetFont()
    if size then self:ApplyTheme(region, size, flags, settings) end
    return region
end

-- WoW switches the line's font to match the alphabet. Keep CJK names
-- close to the Latin text height so they fit in fixed-height rows.
local alphabets = { "roman", "korean", "simplifiedchinese", "traditionalchinese", "russian" }
local cjk = { korean = true, simplifiedchinese = true, traditionalchinese = true }
local families, familyCount = {}, 0

local function ApplyFamily(region, size, flags)
    flags = flags or ""
    local path = Fonts:Resolve() or roles.body
    if CreateFontFamily and GameFontNormal and GameFontNormal.GetFontObjectForAlphabet then
        local key = ("%s:%s:%s"):format(path, size, flags)
        local family = families[key]
        if family == nil then
            local members = {}
            for _, alphabet in ipairs(alphabets) do
                local file = path
                if cjk[alphabet] then
                    local ok, font = pcall(GameFontNormal.GetFontObjectForAlphabet, GameFontNormal, alphabet)
                    file = ok and font and font.GetFont and font:GetFont()
                end
                if file then
                    members[#members + 1] = { alphabet = alphabet, file = file, flags = flags,
                        height = cjk[alphabet] and math.floor(size * .88 + .5) or size }
                end
            end
            familyCount = familyCount + 1
            local ok, result = pcall(CreateFontFamily, "Sintezza_ThemeFont" .. familyCount, members)
            family = ok and result or false
            families[key] = family
        end
        if family then region:SetFontObject(family); return end
    end
    Fonts:Paint(region, size, flags)
end

function Fonts:ApplyFamily(region, size, flags)
    ApplyFamily(region, size, flags)
    ns:TrackAppearance(region, "font", function(target) ApplyFamily(target, size, flags) end)
end

function Fonts:ApplyTree(frame, settings, skipFrame)
    if frame == skipFrame then return end
    if frame.GetRegions then
        for _, region in ipairs({ frame:GetRegions() }) do
            if region.GetObjectType and region:GetObjectType() == "FontString" and region.GetFont then
                local _, size, flags = region:GetFont()
                if size then self:ApplyTheme(region, size, flags, settings) end
            end
        end
    end
    if frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do self:ApplyTree(child, settings, skipFrame) end
    end
end

function Fonts:ShowPicker(owner, settings, after, includeShared)
    local entries = {}
    for index, option in ipairs(self:Choices(includeShared ~= false)) do
        entries[index] = { value = option[1], label = option[2] }
    end
    local selection = settings.interfaceFont or (includeShared == false and "THEME" or "SHARED")
    ns.Settings:OpenPicker(owner, entries, selection, function(value)
        settings.interfaceFont = value
        if after then after() end
    end)
end

