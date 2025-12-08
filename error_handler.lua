-- Модуль обработки ошибок для торгового ассистента QUIK

local error_handler = {}

-- Таблица с известными ошибками QUIK и способами их обработки
local error_codes = {
    ["101"] = {message = "Недостаточно средств", action = "reduce_volume"},
    ["102"] = {message = "Заявка не соответствует формату", action = "retry_with_adjustments"},
    ["103"] = {message = "Инструмент не найден", action = "skip_order"},
    ["104"] = {message = "Цена вне лимитов", action = "adjust_price"},
    ["105"] = {message = "Объем вне лимитов", action = "reduce_volume"},
    ["106"] = {message = "Сессия закрыта", action = "wait_and_retry"},
    ["107"] = {message = "Не хватает прав", action = "skip_order"},
    ["108"] = {message = "Слишком частые запросы", action = "delay_and_retry"},
    ["109"] = {message = "Счет не найден", action = "skip_order"},
    ["110"] = {message = "Слишком большая заявка", action = "split_order"}
}

-- Функция анализа ошибки и определения действия
function error_handler.analyze_error(error_code, error_message)
    -- Сначала проверяем по коду ошибки
    if error_codes[error_code] then
        return error_codes[error_code].action, error_codes[error_code].message
    end
    
    -- Если код неизвестен, пытаемся определить по тексту сообщения
    local lower_msg = string.lower(error_message or "")
    
    if string.find(lower_msg, "недостаточно") or string.find(lower_msg, "insufficient") then
        return "reduce_volume", "Недостаточно средств или позиций"
    elseif string.find(lower_msg, "лимит") or string.find(lower_msg, "limit") then
        return "adjust_price", "Цена или объем вне лимитов"
    elseif string.find(lower_msg, "частые") or string.find(lower_msg, "frequent") then
        return "delay_and_retry", "Слишком частые запросы"
    elseif string.find(lower_msg, "формат") or string.find(lower_msg, "format") then
        return "retry_with_adjustments", "Неправильный формат заявки"
    else
        return "skip_order", "Неизвестная ошибка: " .. (error_message or "без сообщения")
    end
end

-- Функция корректировки цены заявки в случае ошибки
function error_handler.adjust_price_for_error(order, error_action, class_code, security_code)
    local adjusted_order = {
        name = order.name,
        operation = order.operation,
        code = order.code,
        quantity = order.quantity,
        price = order.price
    }
    
    if error_action == "adjust_price" then
        local price_step = getParamEx(class_code, security_code, "SEC_PRICE_STEP")
        if price_step and price_step.param_value then
            price_step = tonumber(price_step.param_value)
        else
            price_step = 0.01 -- значение по умолчанию
        end
        
        -- Получаем минимальную/максимальную цену
        local min_price_data = getParamEx(class_code, security_code, "MINPRICE")
        local max_price_data = getParamEx(class_code, security_code, "MAXPRICE")
        
        local min_price = min_price_data and tonumber(min_price_data.param_value) or 0
        local max_price = max_price_data and tonumber(max_price_data.param_value) or 999999999
        
        if order.operation == "B" then
            -- Для покупки устанавливаем цену не выше максимальной
            adjusted_order.price = math.min(order.price, max_price)
            -- Корректируем по шагу цены
            adjusted_order.price = math.floor(adjusted_order.price / price_step) * price_step
        else
            -- Для продажи устанавливаем цену не ниже минимальной
            adjusted_order.price = math.max(order.price, min_price)
            -- Корректируем по шагу цены
            adjusted_order.price = math.ceil(adjusted_order.price / price_step) * price_step
        end
    end
    
    return adjusted_order
end

-- Функция уменьшения объема заявки
function error_handler.reduce_volume(order, broker_params)
    local reduced_order = {
        name = order.name,
        operation = order.operation,
        code = order.code,
        quantity = order.quantity,
        price = order.price
    }
    
    -- Уменьшаем количество на 10%
    reduced_order.quantity = math.max(1, math.floor(order.quantity * 0.9))
    
    -- Проверяем, не ниже ли минимального объема
    if reduced_order.quantity < broker_params.MinOrderVolume then
        reduced_order.quantity = broker_params.MinOrderVolume
    end
    
    -- Проверяем, не превышает ли максимальный объем после уменьшения
    if reduced_order.quantity > broker_params.MaxOrderVolume then
        reduced_order.quantity = broker_params.MaxOrderVolume
    end
    
    return reduced_order
end

-- Функция разделения большой заявки на несколько меньших
function error_handler.split_order(order, broker_params)
    local orders = {}
    
    local max_qty = broker_params.MaxOrderVolume
    local remaining_qty = order.quantity
    
    while remaining_qty > 0 do
        local qty = math.min(max_qty, remaining_qty)
        table.insert(orders, {
            name = order.name,
            operation = order.operation,
            code = order.code,
            quantity = qty,
            price = order.price
        })
        remaining_qty = remaining_qty - qty
    end
    
    return orders
end

-- Функция задержки перед повторной попыткой
function error_handler.delay_before_retry(attempt_number)
    -- Увеличиваем задержку с каждой попыткой (экспоненциальная задержка)
    local delay = math.min(30, 2 ^ attempt_number) -- Максимум 30 секунд
    os.execute("sleep " .. delay)
end

return error_handler