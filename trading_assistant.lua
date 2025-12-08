-- Торговый ассистент для QUIK
-- Основной файл системы автоматической торговли

require("quik")
local broker_config = require("broker_config")
local bond_handler = require("bond_handler")
local error_handler = require("error_handler")

-- Получаем параметры брокеров из конфигурационного файла
local broker_params = broker_config.brokers

-- Таблица с текущими заявками для предотвращения дублирования
local active_orders = {}

-- Таблица с текущими позициями
local positions = {}

-- Уровни логирования
local log_levels = {
    DEBUG = 1,
    INFO = 2,
    ERROR = 3
}

local current_log_level = log_levels.INFO

-- Функция логирования
local function log(message, level)
    level = level or log_levels.INFO
    if level >= current_log_level then
        local timestamp = os.date("%Y-%m-%d %H:%M:%S")
        local level_str = {
            [log_levels.DEBUG] = "DEBUG",
            [log_levels.INFO] = "INFO", 
            [log_levels.ERROR] = "ERROR"
        }[level] or "UNKNOWN"
        
        print(string.format("[%s] %s: %s", timestamp, level_str, message))
        
        -- Также записываем в лог-файл
        local log_file = io.open("trading_assistant.log", "a")
        if log_file then
            log_file:write(string.format("[%s] %s: %s\n", timestamp, level_str, message))
            log_file:close()
        end
    end
end

-- Функция определения брокера по userId
local function get_broker_by_userid()
    log("Получение идентификатора клиента для определения брокера", log_levels.DEBUG)
    
    -- В QUIK нет прямой функции получения userId, но можно использовать информацию о фирмах
    local firm_list = getFirmList()
    log("Список фирм: " .. tostring(firm_list), log_levels.DEBUG)
    
    -- Разбиваем список фирм и ищем подходящего брокера
    if firm_list then
        for firm_code in string.gmatch(firm_list, "([^,]+)") do
            firm_code = firm_code:gsub("^%s+", ""):gsub("%s+$", "") -- Убираем пробелы
            
            -- Проверяем каждый брокерский код
            for broker_code, params in pairs(broker_params) do
                if firm_code == params.FirmId then
                    log("Определен брокер по FirmId: " .. broker_code, log_levels.INFO)
                    return broker_code, params
                end
            end
        end
    end
    
    -- Если не удалось определить по FirmId, пробуем определить по другим признакам
    -- Например, можно проверить наличие счетов
    for broker_code, params in pairs(broker_params) do
        local acc_bal = getAccountBalance(params.AccountCode)
        if acc_bal then
            log("Определен брокер по наличию счета: " .. broker_code, log_levels.INFO)
            return broker_code, params
        end
        
        -- Проверяем также СПБ счет
        acc_bal = getAccountBalance(params.AccountCodeSpb)
        if acc_bal then
            log("Определен брокер по наличию СПБ счета: " .. broker_code, log_levels.INFO)
            return broker_code, params
        end
    end
    
    -- Если не удалось точно определить, используем FINAM по умолчанию
    log("Не удалось точно определить брокера, используем FINAM по умолчанию", log_levels.ERROR)
    return "FINAM", broker_params.FINAM
end

-- Функция загрузки параметров брокера
local function load_broker_params()
    local broker_code, params = get_broker_by_userid()
    log("Определен брокер: " .. broker_code, log_levels.INFO)
    return broker_code, params
end

-- Функция чтения CSV файла с заявками
local function read_orders_from_csv(file_path)
    log("Чтение заявок из файла: " .. file_path, log_levels.DEBUG)
    
    local orders = {}
    local file = io.open(file_path, "r")
    
    if not file then
        log("Не удалось открыть файл: " .. file_path, log_levels.ERROR)
        return orders
    end
    
    for line in file:lines() do
        -- Пропускаем комментарии (начинающиеся с "--")
        if not string.match(line, "^%s*%-") then
            local parts = {}
            for part in string.gmatch(line, "([^;]+)") do
                table.insert(parts, part)
            end
            
            if #parts >= 5 then
                local order = {
                    name = parts[1],
                    operation = parts[2],
                    code = parts[3],
                    quantity = tonumber(parts[4]),
                    price = tonumber(parts[5])
                }
                
                if order.quantity and order.price then
                    table.insert(orders, order)
                    log(string.format("Загружена заявка: %s (%s), кол-во: %d, цена: %.2f", 
                        order.name, order.code, order.quantity, order.price), log_levels.DEBUG)
                else
                    log("Некорректные данные в строке: " .. line, log_levels.ERROR)
                end
            end
        end
    end
    
    file:close()
    return orders
end

-- Функция проверки существования заявки на тот же инструмент
local function is_duplicate_order(security_code, operation)
    for _, order in ipairs(active_orders) do
        if order.security_code == security_code and order.operation == operation then
            return true
        end
    end
    return false
end

-- Функция получения текущей цены инструмента
local function get_current_price(class_code, security_code, operation)
    -- В QUIK получаем текущую цену из стакана
    local market_data = getParamEx(class_code, security_code, "LAST")
    if market_data and market_data.param_value then
        return tonumber(market_data.param_value)
    else
        -- Пытаемся получить цену другим способом
        local bid_data = getParamEx(class_code, security_code, "BID")
        local offer_data = getParamEx(class_code, security_code, "OFFER")
        
        if operation == "B" and bid_data and bid_data.param_value then
            return tonumber(bid_data.param_value)
        elseif operation == "S" and offer_data and offer_data.param_value then
            return tonumber(offer_data.param_value)
        end
    end
    return nil
end

-- Функция проверки цены заявки
local function check_price_validity(current_price, order_price, operation)
    if not current_price then
        log("Не удалось получить текущую цену для проверки", log_levels.DEBUG)
        return true -- Если не можем получить текущую цену, пропускаем проверку
    end
    
    if operation == "B" then -- Покупка: заявка должна быть <= текущей цены
        return order_price <= current_price
    elseif operation == "S" then -- Продажа: заявка должна быть >= текущей цены
        return order_price >= current_price
    end
    return true
end

-- Функция получения шага цены инструмента
local function get_price_step(class_code, security_code)
    local step_data = getParamEx(class_code, security_code, "SEC_PRICE_STEP")
    if step_data and step_data.param_value then
        return tonumber(step_data.param_value)
    end
    return 0.01 -- Значение по умолчанию
end

-- Функция корректировки цены по шагу
local function adjust_price_to_step(price, price_step)
    if price_step and price_step > 0 then
        return math.floor(price / price_step) * price_step
    end
    return price
end

-- Функция проверки лимитов объема
local function check_volume_limits(quantity, broker_params)
    return quantity >= broker_params.MinOrderVolume and quantity <= broker_params.MaxOrderVolume
end

-- Функция проверки наличия позиции для продажи
local function check_position_for_sell(security_code, required_quantity)
    local position = positions[security_code] or 0
    return position >= required_quantity
end

-- Функция проверки номинала облигаций
local function check_bond_nominal(security_code, quantity, price, broker_params)
    return bond_handler.check_bond_nominal_limit(security_code, quantity, price, broker_params)
end

-- Функция проверки минимальной доходности
local function check_min_yield(security_code, broker_params)
    return bond_handler.check_min_yield(security_code, broker_params)
end

-- Функция проверки инструмента на минимальную/максимальную цену
local function check_price_limits(order_price, class_code, security_code)
    local min_price_data = getParamEx(class_code, security_code, "MINPRICE")
    local max_price_data = getParamEx(class_code, security_code, "MAXPRICE")
    
    if min_price_data and min_price_data.param_value then
        local min_price = tonumber(min_price_data.param_value)
        if order_price < min_price then
            return false, "Цена ниже минимальной разрешенной"
        end
    end
    
    if max_price_data and max_price_data.param_value then
        local max_price = tonumber(max_price_data.param_value)
        if order_price > max_price then
            return false, "Цена выше максимальной разрешенной"
        end
    end
    
    return true, "Цена в допустимом диапазоне"
end

-- Функция определения класса инструмента
local function get_security_class(security_code)
    -- В реальной системе нужно определять класс инструмента
    -- Пока возвращаем общий класс
    local classes = {
        {"TQBR", "EQTV"}, -- Обычные акции
        {"TQDE", "BOND"}, -- Облигации
        {"SPBFUT", "FUT"} -- Фьючерсы
    }
    
    -- Примерная логика определения класса
    if string.match(security_code, "^SU%d+") then
        return "TQDE" -- Скорее всего ОФЗ
    else
        return "TQBR" -- Скорее всего акции
    end
end

-- Функция отправки заявки в QUIK с обработкой ошибок
local function send_order(order, broker_params, is_edge_strategy, attempt_number)
    attempt_number = attempt_number or 1
    log(string.format("Подготовка к отправке заявки (попытка %d): %s (%s), кол-во: %d, цена: %.2f", 
        attempt_number, order.name, order.code, order.quantity, order.price), log_levels.DEBUG)
    
    -- Проверяем дубликаты
    if is_duplicate_order(order.code, order.operation) then
        log(string.format("Заявка на инструмент %s уже существует, пропускаем", order.code), log_levels.INFO)
        return false, "Дубликат заявки"
    end
    
    -- Определяем класс инструмента
    local class_code = get_security_class(order.code)
    
    -- Проверяем минимальную/максимальную цену
    local price_ok, price_msg = check_price_limits(order.price, class_code, order.code)
    if not price_ok then
        log(string.format("Проверка цены не пройдена для %s: %s", order.code, price_msg), log_levels.ERROR)
        return false, price_msg
    end
    
    -- Проверяем объем
    if not check_volume_limits(order.quantity, broker_params) then
        local error_msg = string.format("Объем %d вне допустимого диапазона [%d, %d]", 
            order.quantity, broker_params.MinOrderVolume, broker_params.MaxOrderVolume)
        log(error_msg, log_levels.ERROR)
        return false, error_msg
    end
    
    -- Проверяем текущую цену относительно заявки
    local current_price = get_current_price(class_code, order.code, order.operation)
    if not check_price_validity(current_price, order.price, order.operation) then
        local error_msg = string.format("Цена заявки не соответствует рыночной цене для %s", order.code)
        log(error_msg, log_levels.ERROR)
        return false, error_msg
    end
    
    -- Для стратегии Edge корректируем цену
    if is_edge_strategy then
        local price_step = get_price_step(class_code, order.code)
        if order.operation == "B" then
            -- Для покупки устанавливаем минимально возможную цену
            order.price = adjust_price_to_step(current_price or order.price, price_step)
        elseif order.operation == "S" then
            -- Для продажи устанавливаем максимально возможную цену
            order.price = adjust_price_to_step(current_price or order.price, price_step)
        end
    end
    
    -- Проверяем шаг цены
    local price_step = get_price_step(class_code, order.code)
    order.price = adjust_price_to_step(order.price, price_step)
    
    -- Проверяем наличие позиции при продаже
    if order.operation == "S" and not check_position_for_sell(order.code, order.quantity) then
        local error_msg = string.format("Недостаточно позиций для продажи %s", order.code)
        log(error_msg, log_levels.ERROR)
        return false, error_msg
    end
    
    -- Проверяем номинал облигаций
    local nominal_ok, nominal_msg = check_bond_nominal(order.code, order.quantity, order.price, broker_params)
    if not nominal_ok then
        local error_msg = string.format("Проверка номинала облигации не пройдена для %s: %s", order.code, nominal_msg)
        log(error_msg, log_levels.ERROR)
        return false, error_msg
    end
    
    -- Проверяем минимальную доходность
    local yield_ok, yield_msg = check_min_yield(order.code, broker_params)
    if not yield_ok then
        local error_msg = string.format("Проверка минимальной доходности не пройдена для %s: %s", order.code, yield_msg)
        log(error_msg, log_levels.ERROR)
        return false, error_msg
    end
    
    -- Отправляем заявку в QUIK
    local result = sendTransaction({
        ACTION = "NEW_ORDER",
        ACCOUNT = broker_params.AccountCode,
        CLASSCODE = class_code,
        SECCODE = order.code,
        QUANTITY = order.quantity,
        OPERATION = order.operation,
        PRICE = order.price
    })
    
    if type(result) == "table" and result.success == false then
        -- Обработка ошибки QUIK
        local error_code = result.code or "unknown"
        local error_message = result.message or "без сообщения"
        log(string.format("Ошибка при отправке заявки %s: %s (код: %s)", order.code, error_message, error_code), log_levels.ERROR)
        
        -- Анализируем ошибку и определяем действие
        local action, action_desc = error_handler.analyze_error(error_code, error_message)
        log(string.format("Определено действие для ошибки: %s (%s)", action, action_desc), log_levels.DEBUG)
        
        -- Если максимальное количество попыток достигнуто, прекращаем
        if attempt_number >= 3 then
            log(string.format("Достигнуто максимальное количество попыток для заявки %s", order.code), log_levels.ERROR)
            return false, error_message
        end
        
        -- Выполняем действие в зависимости от типа ошибки
        if action == "adjust_price" then
            local adjusted_order = error_handler.adjust_price_for_error(order, action, class_code, order.code)
            log(string.format("Корректируем цену заявки %s: старая цена %.2f, новая цена %.2f", 
                order.code, order.price, adjusted_order.price), log_levels.INFO)
            return send_order(adjusted_order, broker_params, is_edge_strategy, attempt_number + 1)
        elseif action == "reduce_volume" then
            local reduced_order = error_handler.reduce_volume(order, broker_params)
            log(string.format("Уменьшаем объем заявки %s: старый объем %d, новый объем %d", 
                order.code, order.quantity, reduced_order.quantity), log_levels.INFO)
            return send_order(reduced_order, broker_params, is_edge_strategy, attempt_number + 1)
        elseif action == "split_order" then
            local split_orders = error_handler.split_order(order, broker_params)
            log(string.format("Разбиваем заявку %s на %d частей", order.code, #split_orders), log_levels.INFO)
            local success_count = 0
            for _, split_order in ipairs(split_orders) do
                local success, result = send_order(split_order, broker_params, is_edge_strategy, attempt_number + 1)
                if success then
                    success_count = success_count + 1
                end
            end
            if success_count > 0 then
                return true, string.format("Успешно отправлено %d из %d частей заявки", success_count, #split_orders)
            else
                return false, "Не удалось отправить ни одну часть разбитой заявки"
            end
        elseif action == "delay_and_retry" then
            log(string.format("Задержка перед повторной попыткой для заявки %s", order.code), log_levels.INFO)
            error_handler.delay_before_retry(attempt_number)
            return send_order(order, broker_params, is_edge_strategy, attempt_number + 1)
        elseif action == "retry_with_adjustments" then
            -- Повторяем с небольшими корректировками
            local adjusted_order = error_handler.adjust_price_for_error(order, "adjust_price", class_code, order.code)
            log(string.format("Повторная попытка с корректировками для заявки %s", order.code), log_levels.INFO)
            return send_order(adjusted_order, broker_params, is_edge_strategy, attempt_number + 1)
        else
            -- Для всех остальных действий (например, skip_order) просто возвращаем ошибку
            log(string.format("Пропускаем заявку %s из-за ошибки: %s", order.code, action_desc), log_levels.INFO)
            return false, action_desc
        end
    elseif result ~= "" then
        -- Заявка успешно отправлена
        local order_info = {
            security_code = order.code,
            operation = order.operation,
            quantity = order.quantity,
            price = order.price,
            trans_id = result
        }
        table.insert(active_orders, order_info)
        
        log(string.format("Заявка отправлена: %s (%s), кол-во: %d, цена: %.2f, trans_id: %s", 
            order.name, order.code, order.quantity, order.price, result), log_levels.INFO)
        
        return true, result
    else
        local error_msg = string.format("Не удалось отправить заявку для %s", order.code)
        log(error_msg, log_levels.ERROR)
        return false, error_msg
    end
end

-- Функция обработки файла заявок
local function process_orders_file(file_path, broker_params)
    log("Обработка файла заявок: " .. file_path, log_levels.INFO)
    
    -- Определяем, является ли это файлом с Edge стратегией
    local is_edge_strategy = string.match(file_path, "_Edge")
    
    local orders = read_orders_from_csv(file_path)
    local success_count = 0
    local error_count = 0
    
    for _, order in ipairs(orders) do
        local success, result = send_order(order, broker_params, is_edge_strategy)
        if success then
            success_count = success_count + 1
        else
            error_count = error_count + 1
            log(string.format("Ошибка при обработке заявки %s: %s", order.code, result), log_levels.ERROR)
        end
    end
    
    log(string.format("Обработка файла завершена: %d успешных, %d ошибок", success_count, error_count), log_levels.INFO)
end

-- Функция определения файлов для текущего брокера
local function find_broker_files(broker_code)
    local files = {}
    local data_dir = "/workspace/Data/"
    
    local handle = io.popen('ls ' .. data_dir .. broker_code .. '*Orders*.csv')
    if handle then
        for file in handle:lines() do
            table.insert(files, file)
        end
        handle:close()
    end
    
    return files
end

-- Основная функция запуска системы
local function main()
    log("Запуск торгового ассистента для QUIK", log_levels.INFO)
    
    -- Загружаем параметры брокера
    local broker_code, broker_params = load_broker_params()
    
    -- Проверяем, разрешено ли торговать в текущее время
    if not broker_config.is_time_allowed(broker_code) then
        log("Торговля не разрешена в текущее время для брокера " .. broker_code, log_levels.INFO)
        return
    end
    
    -- Находим файлы с заявками для текущего брокера
    local order_files = find_broker_files(broker_code)
    
    if #order_files == 0 then
        log("Не найдено файлов с заявками для брокера " .. broker_code, log_levels.INFO)
    else
        log(string.format("Найдено %d файлов с заявками для брокера %s", #order_files, broker_code), log_levels.INFO)
        
        -- Обрабатываем каждый файл
        for _, file_path in ipairs(order_files) do
            process_orders_file(file_path, broker_params)
        end
    end
    
    log("Завершение работы торгового ассистента", log_levels.INFO)
end

-- Обработчик события при запуске скрипта
functionOnInit()
    log("Инициализация торгового ассистента", log_levels.INFO)
    main()
end

-- Обработчик события при получении новой сделки
function onTrade(trade)
    log(string.format("Получена новая сделка: %s, кол-во: %d, цена: %.2f", 
        trade.seccode, trade.qty, trade.price), log_levels.INFO)
    
    -- Обновляем позиции
    if not positions[trade.seccode] then
        positions[trade.seccode] = 0
    end
    
    if trade.operation == "B" then
        positions[trade.seccode] = positions[trade.seccode] + trade.qty
    else
        positions[trade.seccode] = positions[trade.seccode] - trade.qty
    end
end

-- Обработчик события при изменении стакана
function onQuote(class_code, security_code)
    -- Можем обновлять текущие цены для принятия решений
end

-- Обработчик события при изменении заявки
function onOrder(order)
    log(string.format("Изменение статуса заявки: %s, кол-во: %d, цена: %.2f, статус: %s", 
        order.seccode, order.qty, order.price, order.status), log_levels.DEBUG)
    
    -- Обновляем список активных заявок
    if order.status == "KILLED" or order.status == "FILLED" then
        -- Удаляем из списка активных заявок
        for i, active_order in ipairs(active_orders) do
            if active_order.trans_id == order.trans_id then
                table.remove(active_orders, i)
                break
            end
        end
    end
end

-- Запускаем систему
main()