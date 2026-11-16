local _, ns = ...
local windows = setmetatable({}, { __mode = "k" })
local order, pending = 0, nil

local function Public(value)
    if not issecretvalue or not issecretvalue(value) then return value end
end

local function Accessible(frame)
    return Public(frame) and (not frame.IsForbidden or Public(frame:IsForbidden()) == false)
        and (not frame.CanBeAccessedInContext or Public(frame:CanBeAccessedInContext()) == true)
end

local function VisibleWindow(frame)
    return Accessible(frame) and Public(frame:GetParent()) == UIParent and Public(frame:IsVisible()) == true
end

local function HighestLevel(strata, highest, ...)
    for i = 1, select("#", ...) do
        local child = Public(select(i, ...))
        if Accessible(child) then
            if Public(child:GetFrameStrata()) == strata then
                highest = math.max(highest, Public(child:GetFrameLevel()) or highest)
            end
            highest = HighestLevel(strata, highest, child:GetChildren())
        end
    end
    return highest
end

function ns:RaiseWindow(frame)
    if not windows[frame] or not VisibleWindow(frame) then return end
    if InCombatLockdown() then pending = frame; return end
    order = order + 1
    windows[frame] = order
    local strata = Public(frame:GetFrameStrata())
    if not strata then return end

    local entries, level = {}, math.huge
    for sibling, rank in pairs(windows) do
        if VisibleWindow(sibling) and Public(sibling:GetFrameStrata()) == strata then
            local base = Public(sibling:GetFrameLevel())
            if base then
                level = math.min(level, base)
                entries[#entries + 1] = { frame = sibling, rank = rank, base = base }
            end
        end
    end
    if #entries < 2 then return end
    table.sort(entries, function(a, b) return a.rank < b.rank end)
    for _, entry in ipairs(entries) do
        entry.span = HighestLevel(strata, entry.base, entry.frame:GetChildren()) - entry.base + 1
    end
    for _, entry in ipairs(entries) do
        if entry.base ~= level then entry.frame:SetFrameLevel(level) end
        level = level + entry.span
    end
end

function ns:TrackWindow(frame)
    if not Accessible(frame) or Public(frame:GetParent()) ~= UIParent or windows[frame] then return end
    order = order + 1
    windows[frame] = order
    local function Raise() ns:RaiseWindow(frame) end
    frame:HookScript("OnShow", Raise)
    if hooksecurefunc and frame.Raise then hooksecurefunc(frame, "Raise", Raise) end
    Raise()
end

local events = CreateFrame("Frame")
events:RegisterEvent("GLOBAL_MOUSE_DOWN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        local frame = pending
        pending = nil
        if frame then ns:RaiseWindow(frame) end
        return
    end
    local focus
    if GetMouseFoci then
        local foci = Public(GetMouseFoci())
        focus = foci and Public(foci[1])
    elseif GetMouseFocus then
        focus = Public(GetMouseFocus())
    end
    while Accessible(focus) and focus ~= UIParent do
        if windows[focus] then ns:RaiseWindow(focus); return end
        focus = Public(focus:GetParent())
    end
end)
