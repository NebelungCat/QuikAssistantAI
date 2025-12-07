-- Модуль для обработки CSV файлов с торговыми сигналами
-- CSVHandler

CSVHandler = {}

function CSVHandler:new()
    local obj = {}
    setmetatable(obj, {__index = self})
    return obj
end

-- Функция чтения CSV файла
function CSVHandler:read_csv(file_path)
    local file = io.open(file_path, "r")
    if not file then
        print("Ошибка: Не удалось открыть файл " .. file_path)
        return nil
    end
    
    local data = {}
    local headers = {}
    
    for line in file:lines() do
        local row = self:parse_csv_line(line)
        
        -- Если это первая строка, считаем её заголовками
        if #headers == 0 then
            headers = row
        else
            -- Преобразуем строку в таблицу с именованными полями
            local record = {}
            for i, value in ipairs(row) do
                record[headers[i]] = value
            end
            table.insert(data, record)
        end
    end
    
    file:close()
    return data, headers
end

-- Функция парсинга строки CSV
function CSVHandler:parse_csv_line(line)
    local fields = {}
    local field = ""
    local in_quotes = false
    
    for i = 1, #line do
        local char = line:sub(i, i)
        
        if char == '"' then
            in_quotes = not in_quotes
        elseif char == ',' and not in_quotes then
            table.insert(fields, field)
            field = ""
        else
            field = field .. char
        end
    end
    
    table.insert(fields, field)
    return fields
end

-- Функция записи CSV файла
function CSVHandler:write_csv(file_path, data, headers)
    local file = io.open(file_path, "w")
    if not file then
        print("Ошибка: Не удалось создать файл " .. file_path)
        return false
    end
    
    -- Записываем заголовки
    for i, header in ipairs(headers) do
        file:write(header)
        if i < #headers then
            file:write(",")
        end
    end
    file:write("\n")
    
    -- Записываем данные
    for _, row in ipairs(data) do
        for i, header in ipairs(headers) do
            file:write(row[header] or "")
            if i < #headers then
                file:write(",")
            end
        end
        file:write("\n")
    end
    
    file:close()
    return true
end

-- Функция фильтрации данных по времени
function CSVHandler:filter_by_time(data, start_time, end_time)
    local filtered_data = {}
    
    for _, record in ipairs(data) do
        local record_time = record.time or record.Time or record.datetime or record.DateTime
        
        if record_time then
            -- Преобразуем время в формат Lua
            local time_value = self:convert_to_time_value(record_time)
            
            if time_value then
                local current_time = os.time()
                
                -- Проверяем, попадает ли время записи в нужный диапазон
                if self:is_time_in_range(time_value, current_time, start_time, end_time) then
                    table.insert(filtered_data, record)
                end
            end
        end
    end
    
    return filtered_data
end

-- Функция преобразования времени в формат Lua
function CSVHandler:convert_to_time_value(time_str)
    -- Поддерживаемые форматы: HH:MM, HH:MM:SS, YYYY-MM-DD HH:MM:SS
    local year, month, day, hour, min, sec
    
    if string.match(time_str, "^%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d$") then
        -- Формат: YYYY-MM-DD HH:MM:SS
        year, month, day, hour, min, sec = string.match(time_str, "(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d):(%d%d)")
    elseif string.match(time_str, "^%d%d:%d%d:%d%d$") then
        -- Формат: HH:MM:SS
        hour, min, sec = string.match(time_str, "(%d%d):(%d%d):(%d%d)")
        -- Используем текущую дату
        local current = os.date("*t")
        year, month, day = current.year, current.month, current.day
    elseif string.match(time_str, "^%d%d:%d%d$") then
        -- Формат: HH:MM
        hour, min = string.match(time_str, "(%d%d):(%d%d)")
        sec = 0
        -- Используем текущую дату
        local current = os.date("*t")
        year, month, day = current.year, current.month, current.day
    else
        return nil
    end
    
    return os.time({year = year, month = month, day = day, hour = hour, min = min, sec = sec})
end

-- Функция проверки, попадает ли время в заданный диапазон
function CSVHandler:is_time_in_range(record_time, current_time, start_time, end_time)
    local start_time_value = self:convert_to_time_value(start_time)
    local end_time_value = self:convert_to_time_value(end_time)
    
    if not start_time_value or not end_time_value then
        return true  -- Если не указан диапазон, принимаем все
    end
    
    -- Если диапазон пересекает полночь
    if end_time_value < start_time_value then
        return record_time >= start_time_value or record_time <= end_time_value
    else
        return record_time >= start_time_value and record_time <= end_time_value
    end
end

return CSVHandler