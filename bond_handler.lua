-- Модуль обработки облигаций для торгового ассистента QUIK

local bond_handler = {}

-- Функция проверки, является ли инструмент облигацией
function bond_handler.is_bond(security_code)
    -- Проверяем, является ли инструмент облигацией по коду
    -- Обычно облигации начинаются с SU (для ОФЗ) или имеют определенные признаки в коде
    if string.match(security_code, "^SU%d+") then  -- ОФЗ
        return true
    end
    
    -- Другие возможные признаки облигаций
    local bond_indicators = {
        "OFZ", "ОФЗ", "BOND", "BND", "облиг"
    }
    
    local sec_lower = string.lower(security_code)
    for _, indicator in ipairs(bond_indicators) do
        if string.find(sec_lower, string.lower(indicator)) then
            return true
        end
    end
    
    return false
end

-- Функция получения номинала облигации
function bond_handler.get_bond_nominal(class_code, security_code)
    -- В QUIK можно получить номинал облигации через getParamEx
    local nominal_data = getParamEx(class_code, security_code, "NOMINAL")
    if nominal_data and nominal_data.param_value then
        return tonumber(nominal_data.param_value)
    end
    
    -- Если не удалось получить номинал, возвращаем 1000 по умолчанию
    return 1000
end

-- Функция проверки лимита номинала облигации
function bond_handler.check_bond_nominal_limit(security_code, quantity, price, broker_params)
    if not bond_handler.is_bond(security_code) then
        -- Если это не облигация, проверка не нужна
        return true
    end
    
    local nominal = bond_handler.get_bond_nominal("TQDE", security_code) -- Обычно облигации в TQDE
    local total_nominal = quantity * price * nominal / 100  -- Переводим в рубли
    
    if total_nominal > broker_params.MaxBondNominal then
        return false, string.format("Превышение лимита номинала: %.2f > %.2f", total_nominal, broker_params.MaxBondNominal)
    end
    
    return true, "Лимит номинала в пределах допустимого"
end

-- Функция получения информации о доходности облигации
function bond_handler.get_bond_yield(class_code, security_code)
    -- В QUIK можно получить доходность облигации
    local yield_data = getParamEx(class_code, security_code, "YIELD")
    if yield_data and yield_data.param_value then
        return tonumber(yield_data.param_value)
    end
    
    return nil
end

-- Функция проверки минимальной доходности облигации
function bond_handler.check_min_yield(security_code, broker_params)
    if not bond_handler.is_bond(security_code) then
        -- Если это не облигация, проверка не нужна
        return true
    end
    
    local yield = bond_handler.get_bond_yield("TQDE", security_code)
    if yield and yield < broker_params.MinYield then
        return false, string.format("Доходность облигации %.2f%% ниже минимальной %.2f%%", yield, broker_params.MinYield)
    end
    
    return true, "Доходность облигации в пределах допустимого"
end

return bond_handler