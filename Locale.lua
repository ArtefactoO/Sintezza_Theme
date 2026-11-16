local _, ns = ...
local defaultLocale = GetLocale() == "ruRU" and "ruRU" or "enUS"

function ns:ResolveLocale(preference)
    if preference == "ruRU" or preference == "enUS" then return preference end
    return defaultLocale
end

local settings = Sintezza_ThemeDB
local activeLocale = ns:ResolveLocale(type(settings) == "table" and settings.locale)

function ns:GetLocale()
    return activeLocale
end
