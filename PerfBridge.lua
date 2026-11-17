local addon, ns = ...
local bridge, api, points = {}, nil, {}
ns.PerfBridge = bridge
function bridge.Count(key)
    local point = points[key]
    if point then api:Count(point) end
end
local function Connect()
    local candidate = _G.Sintezza_PerfAPI
    if type(candidate) ~= "table" or candidate.version ~= 1 then return end
    local module = candidate:RegisterModule(addon, "data_transfer", { title = "Data transfer", titleRu = "Перенос данных" })
    if not module then return end
    api = candidate
    points.encode = api:RegisterPoint(module, "encode", { kind = "counter", title = "CSV exports", titleRu = "Экспорт CSV" })
    points.decode = api:RegisterPoint(module, "decode", { kind = "counter", title = "CSV imports", titleRu = "Импорт CSV" })
end
if _G.Sintezza_PerfAPI then
    Connect()
else
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:SetScript("OnEvent", function(self, event, name)
        if event == "ADDON_LOADED" and name == "Sintezza_Perf" then Connect() end
        if event == "PLAYER_LOGIN" or name == "Sintezza_Perf" then self:UnregisterAllEvents() end
    end)
end
