-- Простая стратегия для QuikAssistantAI
-- SimpleStrategy.lua

SimpleStrategy = {}

function SimpleStrategy:new(assistant)
    local obj = {
        assistant = assistant,
        name = "Simple Moving Average Strategy"
    }
    setmetatable(obj, {__index = self})
    return obj
end

-- Функция генерации торговых сигналов на основе простой стратегии
function SimpleStrategy:generate_signals(class_code, sec_code)
    local signals = {}
    
    -- Получаем рыночные данные
    local market_data = self.assistant:get_market_data(class_code, sec_code)
    
    if market_data and market_data.last_price then
        -- Простая стратегия: если цена ниже 250, покупаем, если выше 260, продаем
        if market_data.last_price < 250 then
            table.insert(signals, {
                action = "buy",
                class_code = class_code,
                sec_code = sec_code,
                quantity = 10,
                price = market_data.last_price,
                order_type = "limit"
            })
        elseif market_data.last_price > 260 then
            table.insert(signals, {
                action = "sell",
                class_code = class_code,
                sec_code = sec_code,
                quantity = 5,
                price = market_data.last_price,
                order_type = "limit"
            })
        end
    end
    
    return signals
end

-- Функция проверки условий для торговли
function SimpleStrategy:check_trading_conditions(class_code, sec_code)
    -- Здесь можно реализовать проверку различных условий
    -- Например, объем торгов, волатильность и т.д.
    
    return true  -- Пока возвращаем true для всех инструментов
end

return SimpleStrategy