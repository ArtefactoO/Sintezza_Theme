local _, ns = ...
local Transfer = {}
ns.DataTransfer = Transfer

local MAX_BYTES, MAX_ROWS, MAX_COLUMNS = 8 * 1024 * 1024, 24000, 48
local MAX_RECORD, MAX_DEPTH, MAX_NODES = 256 * 1024, 18, 15000
local russian = ns:GetLocale() == "ruRU"
local function Text(ru, en) return russian and ru or en end
local INVALID = Text("Неверный формат данных.", "Invalid data format.")
local TOO_LARGE = Text("Данные слишком большие. Выбери меньший раздел.", "Data is too large. Choose a smaller section.")
local WRONG_SCHEMA = Text("CSV относится к другому аддону или версии формата.", "This CSV belongs to a different addon or schema version.")
local FAILED = Text("Операция не выполнена.", "The operation could not be completed.")

local function Finite(value)
    return type(value) == "number" and not (issecretvalue and issecretvalue(value))
        and value == value and math.abs(value) < math.huge
end

local function Scalar(value)
    if issecretvalue and issecretvalue(value) then return end
    if type(value) == "string" then return value end
    if type(value) == "boolean" then return value and "true" or "false" end
    if Finite(value) then return tostring(value) end
end

local function Call(callback, ...)
    local ok, result, detail = pcall(callback, ...)
    if ok then return result, detail end
    return nil, FAILED
end

local function FormatCell(value)
    local text = Scalar(value)
    if not text or text:find("%z") then return end
    -- Preserve string values without letting spreadsheets interpret formulas.
    if type(value) == "string" and text:find("^['=+@%-%s]") then text = "'" .. text end
    if text:find('[,"\r\n]') then text = '"' .. text:gsub('"', '""') .. '"' end
    return text
end

local function DecodeCell(value)
    if value:sub(1, 1) == "'" and value:sub(2, 2):find("^['=+@%-%s]") then return value:sub(2) end
    return value
end

function Transfer:EncodeCSV(spec, rows)
    if type(rows) ~= "table" or #spec.columns + 2 > MAX_COLUMNS then return nil, INVALID end
    if #rows > MAX_ROWS then return nil, TOO_LARGE end

    local lines = { "addon,schema," .. table.concat(spec.columns, ",") }
    local size = #lines[1]
    for index, row in ipairs(rows) do
        if type(row) ~= "table" or #row ~= #spec.columns then return nil, INVALID end
        local cells = { spec.addon, "1" }
        for i = 1, #row do
            cells[#cells + 1] = FormatCell(row[i])
            if #cells ~= i + 2 then return nil, INVALID end
        end
        local line = table.concat(cells, ",")
        size = size + #line + 2
        if size > MAX_BYTES then return nil, TOO_LARGE end
        lines[index + 1] = line
    end
    return table.concat(lines, "\r\n")
end

local function ParseCell(input, cursor)
    if input:sub(cursor, cursor) ~= '"' then
        local stop = input:find('[,\r\n]', cursor) or #input + 1
        local part = input:sub(cursor, stop - 1)
        if part:find('"', 1, true) then return end
        return part, stop
    end

    local parts = {}
    cursor = cursor + 1
    while true do
        local quote = input:find('"', cursor, true)
        if not quote then return end
        parts[#parts + 1] = input:sub(cursor, quote - 1)
        if input:sub(quote + 1, quote + 1) ~= '"' then
            return table.concat(parts), quote + 1
        end
        parts[#parts + 1] = '"'
        cursor = quote + 2
    end
end

function Transfer:DecodeCSV(spec, input)
    if type(input) ~= "string" then return nil, INVALID end
    if #input > MAX_BYTES then return nil, TOO_LARGE end
    if input:find("%z") then return nil, INVALID end
    if input:sub(1, 3) == "\239\187\191" then input = input:sub(4) end
    local columnCount = #spec.columns + 2
    if #input == 0 or columnCount > MAX_COLUMNS then return nil, INVALID end

    local cursor, header = 1, true
    local rows = {}
    repeat
        local fields = {}
        for i = 1, columnCount do
            local field, stop = ParseCell(input, cursor)
            if not stop then return nil, INVALID end
            fields[i] = DecodeCell(field)
            local separator = input:sub(stop, stop)
            if i < columnCount then
                if separator ~= "," then return nil, INVALID end
                cursor = stop + 1
            elseif separator == "\r" then
                cursor = stop + (input:sub(stop + 1, stop + 1) == "\n" and 2 or 1)
            elseif separator == "\n" or separator == "" then
                cursor = stop + 1
            else
                return nil, INVALID
            end
        end
        if header then
            if fields[1] ~= "addon" or fields[2] ~= "schema" then return nil, WRONG_SCHEMA end
            for i, name in ipairs(spec.columns) do
                if fields[i + 2] ~= name then return nil, WRONG_SCHEMA end
            end
            header = false
        else
            if fields[1] ~= spec.addon or fields[2] ~= "1" then return nil, WRONG_SCHEMA end
            if #rows >= MAX_ROWS then return nil, TOO_LARGE end
            local row = {}
            for i = 1, #spec.columns do row[i] = fields[i + 2] end
            rows[#rows + 1] = row
        end
    until cursor > #input
    return rows
end

-- The payload preserves nested history records. Columns beside it remain readable in a spreadsheet.
function Transfer:EncodeRecord(record)
    if type(record) ~= "table" then return nil, INVALID end
    local path, parts = {}, {}
    local nodes, bytes = 0, 0
    local function Append(value)
        bytes = bytes + #value
        if bytes > MAX_RECORD then error(TOO_LARGE, 0) end
        parts[#parts + 1] = value
    end
    local function Encode(value, depth)
        nodes = nodes + 1
        if depth > MAX_DEPTH or nodes > MAX_NODES then error(TOO_LARGE, 0) end
        local kind = type(value)
        if kind == "string" then
            if value:find("%z") then error(INVALID, 0) end
            Append("s" .. #value .. ":" .. value)
        elseif Finite(value) then
            local number = ("%.17g"):format(value)
            Append("n" .. #number .. ":" .. number)
        elseif kind == "boolean" then
            Append(value and "t" or "f")
        elseif kind == "table" and not path[value] then
            path[value] = true
            local keys = {}
            for key in pairs(value) do
                if type(key) ~= "string" and not Finite(key) then error(INVALID, 0) end
                keys[#keys + 1] = key
                if #keys * 2 > MAX_NODES - nodes then error(TOO_LARGE, 0) end
            end
            table.sort(keys, function(first, second)
                if type(first) ~= type(second) then return type(first) < type(second) end
                return first < second
            end)
            Append("m" .. #keys .. ":")
            for _, key in ipairs(keys) do
                Encode(key, depth + 1)
                Encode(value[key], depth + 1)
            end
            path[value] = nil
        else
            error(INVALID, 0)
        end
    end
    local ok, reason = pcall(Encode, record, 0)
    if ok then return table.concat(parts) end
    return nil, reason == TOO_LARGE and TOO_LARGE or INVALID
end

function Transfer:DecodeRecord(data)
    if type(data) ~= "string" or #data == 0 then return nil, INVALID end
    if #data > MAX_RECORD then return nil, TOO_LARGE end
    if data:find("%z") then return nil, INVALID end
    local cursor, nodes = 1, 0
    local function Decode(depth)
        nodes = nodes + 1
        if depth > MAX_DEPTH or nodes > MAX_NODES then error(TOO_LARGE, 0) end
        local tag = data:sub(cursor, cursor)
        cursor = cursor + 1
        if tag == "t" then return true end
        if tag == "f" then return false end
        if tag ~= "m" and tag ~= "n" and tag ~= "s" then error(INVALID, 0) end

        local digits, after = data:match("^(%d+):()", cursor)
        if not digits or #digits > 6 then error(INVALID, 0) end
        local count = tonumber(digits)
        cursor = after
        if tag == "m" then
            if count * 2 > MAX_NODES - nodes then error(TOO_LARGE, 0) end
            local result = {}
            for _ = 1, count do
                local key = Decode(depth + 1)
                if (type(key) ~= "string" and not Finite(key)) or result[key] ~= nil then error(INVALID, 0) end
                result[key] = Decode(depth + 1)
            end
            return result
        end
        if count > #data - cursor + 1 then error(INVALID, 0) end
        local raw = data:sub(cursor, cursor + count - 1)
        cursor = cursor + count
        if tag == "s" then return raw end
        local value = tonumber(raw)
        if not Finite(value) then error(INVALID, 0) end
        return value
    end
    local ok, result = pcall(Decode, 0)
    if ok and type(result) == "table" and cursor == #data + 1 then return result end
    return nil, result == TOO_LARGE and TOO_LARGE or INVALID
end

function Transfer:GetMemoryKB(addon)
    local query = (C_AddOns and C_AddOns.GetAddOnMemoryUsage) or GetAddOnMemoryUsage
    local refresh = (C_AddOns and C_AddOns.UpdateAddOnMemoryUsage) or UpdateAddOnMemoryUsage
    if not query then return end
    if refresh then Call(refresh) end
    local kb = Call(query, addon)
    if Finite(kb) and kb >= 0 then return kb end
end

local theme, widgets
local function CreateWindow(name, width, height, title)
    theme = theme or ns:ForAddon()
    widgets = widgets or ns:CreateWidgets(theme)
    local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    frame:Hide()
    frame:SetSize(width, height)
    frame:SetPoint("CENTER", UIParent, "CENTER")
    if frame.SetIgnoreParentScale then frame:SetIgnoreParentScale(true) end
    if frame.SetIgnoreParentAlpha then frame:SetIgnoreParentAlpha(true) end
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    theme:WindowSurface(frame)
    frame.header = widgets:WindowHeader(frame, { title = title, icon = ns.icons.Sintezza_Theme })
    UISpecialFrames[#UISpecialFrames + 1] = name
    return frame
end

local function OpenWindow(frame, parent)
    if not parent or not parent:IsVisible() then parent = UIParent end
    frame:SetParent(parent)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:Show()
    frame:Raise()
end

local function PlaceWide(region, anchor, edge, y)
    region:SetPoint("TOPLEFT", anchor, edge .. "LEFT", 12, y)
    region:SetPoint("TOPRIGHT", anchor, edge .. "RIGHT", -12, y)
end

local function Status(label, message, warning)
    label:SetText(message or "")
    label:SetTextColor(unpack(warning and theme.warning or theme.muted))
end

local function ImportSummary(plan)
    if plan.message then return plan.message end
    if plan.replace then
        return Text("Будут заменены итоги выбранного периода.", "Totals for the selected period will be replaced.")
    end
    return Text("Новых записей: %d. Дубликатов: %d.", "New records: %d. Duplicates: %d."):format(plan.added or 0, plan.duplicates or 0)
end

local editor, maintenance
local function CreateEditor()
    local frame = CreateWindow("Sintezza_ThemeDataTransfer", 620, 417, Text("Перенос данных", "Transfer data"))
    local selectedScope, mode, spec, importText, exportText, syncing, checkedText, checkedSummary
    local tabs, scope, help, scroll, edit, status, action, apply
    local scopeKeys, scopeLabels, ranked = {}, {}, {}

    local function SetText(text)
        syncing = true
        edit:SetText(text or "")
        edit:SetCursorPosition(0)
        scroll:SetVerticalScroll(0)
        scroll:RefreshRange()
        syncing = false
    end

    local function SetExport()
        local rows, reason = Call(spec.export, selectedScope)
        local csv
        if rows then csv, reason = Transfer:EncodeCSV(spec, rows) end
        exportText = csv
        SetText(csv)
        action:SetEnabled(csv ~= nil)
        Status(status, reason, csv == nil)
    end

    local function SetMode(value)
        mode, checkedText, checkedSummary = value, nil, nil
        edit:ClearFocus()
        apply:Hide()
        local exporting = mode == "export"
        scope:SetShown(exporting and #scopeKeys > 1)
        help:SetText(exporting and Text("Выдели текст и скопируй его через Ctrl+C.", "Select the text and copy it with Ctrl+C.")
            or Text("Вставь CSV этого аддона через Ctrl+V.", "Paste this addon's CSV with Ctrl+V."))
        action.text:SetText(exporting and Text("Выделить CSV", "Select CSV") or Text("Проверить данные", "Check data"))
        action:Enable()
        Status(status)
        if exporting then SetExport() else SetText(importText) end
    end

    local function ImportPlan(text)
        local rows, reason = Transfer:DecodeCSV(spec, text)
        if not rows then return nil, reason end
        if #rows == 0 then return nil, Text("В CSV нет записей.", "The CSV has no records.") end
        local plan
        plan, reason = Call(spec.stage, rows)
        if type(plan) ~= "table" then return nil, reason or INVALID end
        return plan
    end

    local function Preview()
        if mode == "export" then edit:SetFocus(); edit:HighlightText(); return end
        local text = edit:GetText()
        local plan, reason = ImportPlan(text)
        checkedText, checkedSummary = nil, nil
        apply:Hide()
        if not plan then Status(status, reason, true); return end
        checkedText, checkedSummary = text, ImportSummary(plan)
        Status(status, checkedSummary)
        apply.text:SetText(plan.replace and Text("Заменить итоги", "Replace totals") or Text("Добавить записи", "Add records"))
        apply:SetShown(plan.replace == true or (plan.added or 0) > 0)
    end

    local tabsLabels = { Text("Экспорт", "Export"), Text("Импорт", "Import") }
    tabs = widgets:Segmented(frame, tabsLabels, { "export", "import" }, function() return mode end, SetMode)
    tabs:SetPoint("TOPLEFT", frame.header, "BOTTOMLEFT", 12, -11)
    tabs:SetWidth(240)
    scope = widgets:ChoiceRow(frame, Text("Раздел", "Subset"), function() return scopeLabels end,
        function() return selectedScope end, function(key) selectedScope = key; SetExport() end, ranked)
    scope:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -90)
    scope:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -90)
    help = widgets:Label(frame, "", 11, theme.muted)
    PlaceWide(help, frame, "TOP", -126)

    local surface = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    PlaceWide(surface, frame, "TOP", -148)
    surface:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 87)
    theme:Backdrop(surface, theme.input, theme.lineSoft)
    edit = CreateFrame("EditBox", nil, surface)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    if edit.SetMaxBytes then edit:SetMaxBytes(MAX_BYTES + 1) end
    theme:Font(edit, 11, "", theme.text)
    edit:SetTextInsets(5, 5, 4, 4)
    local bar
    scroll, _, bar = widgets:ScrollFrame(surface, edit, 24)
    scroll:SetPoint("TOPLEFT", surface, "TOPLEFT", 3, -3)
    scroll:SetPoint("BOTTOMRIGHT", surface, "BOTTOMRIGHT", -17, 3)
    bar:SetPoint("TOPRIGHT", surface, "TOPRIGHT", -3, -3)
    bar:SetPoint("BOTTOMRIGHT", surface, "BOTTOMRIGHT", -3, 3)
    scroll:HookScript("OnSizeChanged", function(_, width)
        edit:SetWidth(math.max(1, width))
    end)
    edit:SetScript("OnCursorChanged", function(_, _, y, _, height)
        local at = scroll:GetVerticalScroll()
        local nextOffset = math.max(0, -y + height - scroll:GetHeight())
        if -y < at then scroll:SetVerticalScroll(math.max(0, -y))
        elseif nextOffset > at then scroll:SetVerticalScroll(nextOffset) end
    end)
    scroll:EnableMouse(true)
    scroll:SetScript("OnMouseDown", function() edit:SetFocus() end)
    edit:SetScript("OnEscapePressed", function() frame:Hide() end)
    edit:SetScript("OnTextChanged", function(_, userInput)
        if syncing or not userInput then return end
        if mode == "export" then SetText(exportText); return end
        importText, checkedText, checkedSummary = edit:GetText(), nil, nil
        scroll:RefreshRange()
        apply:Hide()
        Status(status)
    end)

    status = widgets:Label(frame, "", 11, theme.muted)
    status:SetPoint("TOPLEFT", surface, "BOTTOMLEFT", 0, -8)
    status:SetPoint("TOPRIGHT", surface, "BOTTOMRIGHT", 0, -8)
    status:SetWordWrap(true)
    action = widgets:Button(frame, "", Preview)
    action:SetSize(160, 25)
    action:SetPoint("BOTTOMLEFT", 12, 12)
    apply = widgets:Button(frame, "", function()
        if not checkedText or edit:GetText() ~= checkedText then return end
        local plan, reason = ImportPlan(checkedText)
        if not plan then Status(status, reason, true); apply:Hide(); return end
        if ImportSummary(plan) ~= checkedSummary then
            Preview()
            return
        end
        local applied, detail = Call(spec.apply, plan)
        if not applied then Status(status, detail or FAILED, true); return end
        if spec.changed then Call(spec.changed) end
        SetText("")
        checkedText, checkedSummary, importText = nil, nil, nil
        apply:Hide()
        Status(status, Text("Импорт завершен.", "Import complete."))
    end, true)
    apply:SetSize(165, 25)
    apply:SetPoint("BOTTOMRIGHT", -12, 12)
    frame:SetScript("OnHide", function()
        if frame:IsShown() then frame:Hide() end
        edit:ClearFocus()
        SetText("")
        spec, checkedText, checkedSummary, importText, exportText = nil, nil, nil, nil, nil
    end)

    function frame:Open(parent, config, tab)
        self:Hide()
        spec = config
        wipe(scopeKeys)
        wipe(scopeLabels)
        wipe(ranked)
        for i, entry in ipairs(spec.scopes or {}) do
            scopeKeys[i] = entry.key
            scopeLabels[entry.key] = entry.label
            ranked[entry.key] = i
        end
        selectedScope, importText = scopeKeys[1] or "all", nil
        self.header.title:SetText(Text("Перенос данных", "Transfer data") .. " · " .. spec.title)
        scope:Refresh()
        OpenWindow(self, parent)
        SetMode(tab == "import" and "import" or "export")
        tabs:Refresh()
    end
    return frame
end

function Transfer:Open(parent, spec, tab)
    if maintenance then maintenance:Hide() end
    editor = editor or CreateEditor()
    editor:Open(parent, spec, tab)
end

local function CreateMaintenance()
    local frame = CreateWindow("Sintezza_ThemeDataMaintenance", 550, 430, Text("Обслуживание данных", "Data maintenance"))
    local spec, openIndex = nil, 0
    local function FitLabel(row)
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", row, "LEFT")
        row.label:SetPoint("RIGHT", row.button, "LEFT", -8, 0)
        row.label:SetWordWrap(true)
    end
    local memory = widgets:ActionRow(frame, "", Text("Обновить замер", "Refresh measurement"), function() frame:Refresh() end)
    FitLabel(memory)
    PlaceWide(memory, frame.header, "BOTTOM", -10)
    local description = widgets:Label(frame, "", 11, theme.muted)
    description:SetPoint("TOPLEFT", memory, "BOTTOMLEFT", 0, -6)
    description:SetPoint("TOPRIGHT", memory, "BOTTOMRIGHT", 0, -6)
    description:SetWordWrap(true)
    local status = widgets:Label(frame, "", 11, theme.muted)
    status:SetPoint("BOTTOMLEFT", 12, 12)
    status:SetPoint("BOTTOMRIGHT", -12, 12)
    status:SetWordWrap(true)
    local scroll, body, bar = widgets:ScrollFrame(frame)
    scroll:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -10)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -26, 36)
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 4, 0)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 4, 0)
    scroll:HookScript("OnSizeChanged", function(_, width) body:SetWidth(math.max(1, width)) end)
    local rows = {}

    local function GetCount(section)
        local count = Call(section.count)
        return (type(count) == "number" or type(count) == "string") and tostring(count) or "—"
    end
    local function Clear(index)
        local target, request = spec, openIndex
        local section = target.sections[index]
        local prompt = Text("Удалить данные? %s (%s)", "Delete data? %s (%s)"):format(section.label, GetCount(section))
        widgets:Confirm(prompt, function()
            if request ~= openIndex or spec ~= target or not frame:IsVisible() then return end
            local cleared, reason = Call(section.clear)
            if cleared and target.changed then Call(target.changed) end
            frame:Refresh()
            Status(status, cleared and Text("Данные очищены.", "Data cleared.") or reason or FAILED, not cleared)
        end, frame)
    end

    function frame:Refresh()
        local kb = Transfer:GetMemoryKB(spec.addon)
        local size = kb and (kb >= 1024 and ("%.2f MB"):format(kb / 1024) or ("%.0f KB"):format(kb)) or "—"
        memory.label:SetText(Text("Память аддона", "Addon memory") .. " · " .. size)
        for i, section in ipairs(spec.sections or {}) do
            if not rows[i] then
                local index = i
                local row = widgets:ActionRow(body, "", Text("Очистить", "Clear"), function() Clear(index) end)
                FitLabel(row)
                row:SetPoint("TOPLEFT", 0, -(i - 1) * 31)
                row:SetPoint("TOPRIGHT", 0, -(i - 1) * 31)
                rows[i] = row
            end
            local row, count = rows[i], GetCount(section)
            row.label:SetText(section.label .. " · " .. count)
            row:SetAvailable(section.clear ~= nil and count ~= "0")
            row:Show()
        end
        for i = #(spec.sections or {}) + 1, #rows do rows[i]:Hide() end
        body:SetHeight(math.max(1, #(spec.sections or {}) * 31))
        scroll:RefreshRange()
    end

    frame:SetScript("OnHide", function()
        if frame:IsShown() then frame:Hide() end
        spec = nil
    end)

    function frame:Open(parent, config)
        self:Hide()
        spec = config
        openIndex = openIndex + 1
        self.header.title:SetText(Text("Обслуживание данных", "Data maintenance") .. " · " .. spec.title)
        description:SetText(spec.note or Text("Замер включает код, интерфейс и данные аддона.", "Includes addon code, interface and data."))
        Status(status)
        OpenWindow(self, parent)
        self:Refresh()
        scroll:SetVerticalScroll(0)
    end
    return frame
end

function Transfer:OpenMaintenance(parent, spec)
    if editor then editor:Hide() end
    maintenance = maintenance or CreateMaintenance()
    maintenance:Open(parent, spec)
end

