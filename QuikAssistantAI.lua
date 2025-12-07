-- Модуль торгового ассистента для QUIK
-- QuikAssistantAI

-- Загружаем модули
local QuikAPI = require("QuikAPI")
local CSVHandler = require("CSVHandler")

-- Загружаем конфигурацию (сначала пробуем пользовательскую, затем стандартную)
local success, user_config = pcall(require, "user_config")
local config

if success then
    config = user_config
    print("Загружены пользовательские настройки")
else
    config = require("config")
    print("Загружены стандартные настройки")
end

QuikAssistantAI = {}

function QuikAssistantAI:new()
    local obj = {
        -- Основные параметры ассистента
        is_connected = false,
        connection_id = nil,
        orders = {},
        positions = {},
        api = QuikAPI,
        csv_handler = CSVHandler:new(),
        config = config,
        settings = {
            brokers = config.brokers,
            supported_securities = config.security_types,
            log_file = config.general.log_file,
            trade_time_start = config.general.trade_time_start,
            trade_time_end = config.general.trade_time_end,
            csv_file_path = config.general.csv_file_path,
            check_interval = config.general.check_interval,
            max_order_value = config.security.max_order_value,
            max_daily_volume = config.security.max_daily_volume,
            validate_orders = config.security.validate_orders
        }
    }
    
    setmetatable(obj, {__index = self})
    return obj
end

-- Функция подключения к QUIK
function QuikAssistantAI:connect()
    print("Подключение к QUIK...")
    -- Проверяем подключение к QUIK через API
    if self.api:isConnected() then
        self.is_connected = true
        print("Успешно подключено к QUIK")
        return true
    else
        print("Не удалось подключиться к QUIK")
        return false
    end
end

-- Функция отключения от QUIK
function QuikAssistantAI:disconnect()
    print("Отключение от QUIK...")
    self.is_connected = false
end

-- Функция запуска ассистента
function QuikAssistantAI:start()
    if self:connect() then
        print("Ассистент запущен")
        -- Здесь будет основная логика ассистента
        self:main_loop()
    else
        print("Не удалось запустить ассистент - нет подключения к QUIK")
    end
end

-- Основной цикл ассистента
function QuikAssistantAI:main_loop()
    print("Запуск основного цикла ассистента")
    
    -- Проверяем, входит ли текущее время в торговый интервал
    while self:is_trading_time() do
        -- Читаем торговые сигналы из CSV файла
        local signals = self:read_trade_signals(self.settings.csv_file_path)
        
        if signals then
            for _, signal in ipairs(signals) do
                self:process_trade_signal(signal)
            end
        end
        
        -- Ждем немного перед следующей итерацией
        sleep(self.settings.check_interval)  -- Интервал из настроек
    end
    
    print("Вне торгового времени. Ассистент завершает работу.")
end

-- Функция проверки торгового времени
function QuikAssistantAI:is_trading_time()
    local current_time = os.date("*t")
    local current_hour = current_time.hour
    local current_min = current_time.min
    local current_total_min = current_hour * 60 + current_min
    
    -- Парсим время начала и окончания торгов
    local start_hour, start_min = self.settings.trade_time_start:match("(%d%d):(%d%d)")
    local end_hour, end_min = self.settings.trade_time_end:match("(%d%d):(%d%d)")
    
    local start_total_min = tonumber(start_hour) * 60 + tonumber(start_min)
    local end_total_min = tonumber(end_hour) * 60 + tonumber(end_min)
    
    -- Проверяем, находится ли текущее время в пределах торгового времени
    return current_total_min >= start_total_min and current_total_min <= end_total_min
end

-- Функция чтения торговых сигналов из CSV файла
function QuikAssistantAI:read_trade_signals(file_path)
    print("Чтение торговых сигналов из файла: " .. file_path)
    
    local data, headers = self.csv_handler:read_csv(file_path)
    
    if not data then
        self:log("Не удалось прочитать файл торговых сигналов: " .. file_path)
        return nil
    end
    
    -- Фильтруем сигналы по времени
    local filtered_data = self.csv_handler:filter_by_time(
        data, 
        self.settings.trade_time_start, 
        self.settings.trade_time_end
    )
    
    self:log("Прочитано " .. #data .. " сигналов, после фильтрации осталось " .. #filtered_data)
    
    return filtered_data
end

-- Функция обработки торгового сигнала
function QuikAssistantAI:process_trade_signal(signal)
    local action = signal.action or signal.Action or signal.operation or signal.Operation
    local class_code = signal.class_code or signal.ClassCode or signal.class or signal.Class
    local sec_code = signal.sec_code or signal.SecCode or signal.code or signal.Code
    local quantity = tonumber(signal.quantity or signal.Quantity or signal.amount or signal.Amount)
    local price = tonumber(signal.price or signal.Price)
    local account = signal.account or signal.Account
    local client_code = signal.client_code or signal.ClientCode
    
    if not action or not class_code or not sec_code or not quantity or not price then
        self:log("Неполные данные в торговом сигнале: " .. tostring(signal))
        return
    end
    
    -- Преобразуем действие в формат QUIK ('buy' -> 'B', 'sell' -> 'S')
    local side = self:convert_action_to_side(action)
    
    if not side then
        self:log("Неизвестное действие в торговом сигнале: " .. action)
        return
    end
    
    -- Выставляем заявку
    local order_id, error = self:place_order(class_code, sec_code, side, quantity, price, account, client_code)
    
    if order_id then
        self:log("Успешно обработан торговый сигнал: " .. action .. " " .. quantity .. " " .. sec_code)
    else
        self:log("Ошибка обработки торгового сигнала: " .. error)
    end
end

-- Функция преобразования действия в формат QUIK
function QuikAssistantAI:convert_action_to_side(action)
    local action_lower = string.lower(action)
    
    if action_lower == "buy" or action_lower == "покупка" or action_lower == "b" then
        return "B"  -- Покупка
    elseif action_lower == "sell" or action_lower == "продажа" or action_lower == "s" then
        return "S"  -- Продажа
    else
        return nil
    end
end

-- Функция получения рыночных данных
function QuikAssistantAI:get_market_data(class_code, sec_code)
    print("Получение рыночных данных для: " .. class_code .. ":" .. sec_code)
    
    local market_data = {
        last_price = self.api:getLastPrice(class_code, sec_code),
        best_bid = self.api:getBestBidPrice(class_code, sec_code),
        best_ask = self.api:getBestAskPrice(class_code, sec_code),
        volume = self.api:getTradeVolume(class_code, sec_code),
        open_position = self.api:getOpenPosition(class_code, sec_code),
        security_info = self.api:getSecurityInfo(class_code, sec_code)
    }
    
    return market_data
end

-- Функция выставления заявки
function QuikAssistantAI:place_order(class_code, sec_code, side, quantity, price, account, client_code)
    print("Выставление заявки: " .. (side == "B" and "покупка" or "продажа") .. " " .. quantity .. " " .. sec_code .. " по цене " .. price)
    
    -- Проверяем корректность заявки перед выставлением
    if not self:validate_order(class_code, sec_code, side, quantity, price) then
        self:log("Ошибка: Заявка не прошла проверку корректности")
        return false, "Заявка не прошла проверку корректности"
    end
    
    -- Выставляем заявку через API
    local order_id, error = self.api:transmit_order(class_code, sec_code, side, quantity, price, account, client_code)
    
    if order_id then
        self:log("Заявка успешно выставлена. ID: " .. order_id)
        table.insert(self.orders, {
            id = order_id,
            class_code = class_code,
            sec_code = sec_code,
            side = side,
            quantity = quantity,
            price = price,
            status = "active"
        })
        return order_id
    else
        self:log("Ошибка выставления заявки: " .. error)
        return nil, error
    end
end

-- Функция проверки корректности заявки
function QuikAssistantAI:validate_order(class_code, sec_code, side, quantity, price)
    print("Проверка корректности заявки")
    
    -- Проверяем параметры
    if not class_code or not sec_code then
        self:log("Ошибка: Не указаны коды класса или инструмента")
        return false
    end
    
    if side ~= "B" and side ~= "S" then
        self:log("Ошибка: Некорректная операция (должна быть 'B' для покупки или 'S' для продажи)")
        return false
    end
    
    if quantity <= 0 then
        self:log("Ошибка: Количество должно быть больше 0")
        return false
    end
    
    if price <= 0 then
        self:log("Ошибка: Цена должна быть больше 0")
        return false
    end
    
    -- Получаем информацию об инструменте
    local sec_info = self.api:getSecurityInfo(class_code, sec_code)
    if not sec_info then
        self:log("Ошибка: Инструмент не найден")
        return false
    end
    
    -- Проверяем лимиты
    local order_value = quantity * price
    
    -- Проверяем максимальную стоимость одной заявки
    if self.settings.max_order_value and order_value > self.settings.max_order_value then
        self:log("Ошибка: Стоимость заявки превышает максимальное значение (" .. order_value .. " > " .. self.settings.max_order_value .. ")")
        return false
    end
    
    -- Здесь можно добавить другие проверки
    
    return true
end

-- Функция получения информации о позициях
function QuikAssistantAI:get_positions()
    print("Получение информации о позициях")
    
    local positions = {}
    local securities = self.api:get_all_securities()
    
    for _, sec in ipairs(securities) do
        local position = self.api:getPosition(sec.class, sec.code)
        if position and position.currentbal and position.currentbal ~= 0 then
            table.insert(positions, {
                class_code = sec.class,
                sec_code = sec.code,
                name = sec.name,
                balance = position.currentbal,
                open_qty = position.openbal,
                current_qty = position.currentpos
            })
        end
    end
    
    self.positions = positions
    return positions
end

-- Функция автоматического закрытия позиций
function QuikAssistantAI:close_positions()
    print("Автоматическое закрытие позиций")
    
    local positions = self:get_positions()
    
    for _, pos in ipairs(positions) do
        if pos.balance ~= 0 then
            local side = pos.balance > 0 and "S" or "B"  -- Продажа если в плюсе, покупка если в минусе
            local quantity = math.abs(pos.balance)
            
            -- Получаем текущую рыночную цену для закрытия позиции
            local market_data = self:get_market_data(pos.class_code, pos.sec_code)
            local price
            
            if side == "S" then
                price = market_data.best_bid or market_data.last_price
            else
                price = market_data.best_ask or market_data.last_price
            end
            
            if price then
                local order_id, error = self:place_order(pos.class_code, pos.sec_code, side, quantity, price)
                
                if order_id then
                    self:log("Выставлена заявка на закрытие позиции: " .. pos.sec_code .. " " .. quantity .. " шт. по цене " .. price)
                else
                    self:log("Ошибка закрытия позиции: " .. error)
                end
            else
                self:log("Не удалось получить цену для закрытия позиции: " .. pos.sec_code)
            end
        end
    end
end

-- Функция логирования
function QuikAssistantAI:log(message)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local log_entry = timestamp .. " - " .. message
    print(log_entry)
    -- Запись в файл лога
    local file = io.open(self.settings.log_file, "a")
    if file then
        file:write(log_entry .. "\n")
        file:close()
    end
end

return QuikAssistantAI