-- Модуль для взаимодействия с API QUIK
-- Использует функции из библиотеки QUIK LUA

QuikAPI = {}

-- Загрузка необходимых библиотек QUIK
local M = {}

-- Подключение к библиотекам QUIK
if pcall(require, "luautils") then
    M.utils = require "luautils"
end

-- Функция получения информации о соединении с сервером
function QuikAPI:isConnected()
    local connection = getConnectionState()
    return connection == 3  -- 3 означает подключение установлено
end

-- Функция получения списка классов
function QuikAPI:getClassesList()
    return getClassesList()
end

-- Функция получения кода класса по инструменту
function QuikAPI:getClassCode(sec_code)
    return getClassCode(sec_code)
end

-- Функция получения информации по инструменту
function QuikAPI:getSecurityInfo(class_code, sec_code)
    return getSecurityInfo(class_code, sec_code)
end

-- Функция получения таблицы котировок
function QuikAPI:getQuoteLevel2(class_code, sec_code)
    return getQuoteLevel2(class_code, sec_code)
end

-- Функция получения последней цены
function QuikAPI:getLastPrice(class_code, sec_code)
    local param = getParamEx(class_code, sec_code, "LAST")
    if param ~= nil then
        return tonumber(param.param_value)
    end
    return nil
end

-- Функция получения цены на покупку (best bid)
function QuikAPI:getBestBidPrice(class_code, sec_code)
    local param = getParamEx(class_code, sec_code, "BID")
    if param ~= nil then
        return tonumber(param.param_value)
    end
    return nil
end

-- Функция получения цены на продажу (best ask)
function QuikAPI:getBestAskPrice(class_code, sec_code)
    local param = getParamEx(class_code, sec_code, "OFFER")
    if param ~= nil then
        return tonumber(param.param_value)
    end
    return nil
end

-- Функция получения объема торгов
function QuikAPI:getTradeVolume(class_code, sec_code)
    local param = getParamEx(class_code, sec_code, "VOLUME")
    if param ~= nil then
        return tonumber(param.param_value)
    end
    return 0
end

-- Функция получения количества открытых позиций
function QuikAPI:getOpenPosition(class_code, sec_code)
    local param = getParamEx(class_code, sec_code, "OPENPOS")
    if param ~= nil then
        return tonumber(param.param_value)
    end
    return 0
end

-- Функция получения баланса по счету
function QuikAPI:getPortfolioInfo()
    local firm_id = getFirmList()
    if firm_id then
        local portfolios = {}
        for firm in string.gmatch(firm_id, "[^,]+") do
            local accounts = getAccountList(firm)
            if accounts then
                for account in string.gmatch(accounts, "[^,]+") do
                    local portfolio = getPortfolioInfo(firm, account)
                    if portfolio then
                        table.insert(portfolios, portfolio)
                    end
                end
            end
        end
        return portfolios
    end
    return {}
end

-- Функция получения информации о позициях по инструменту
function QuikAPI:getPosition(class_code, sec_code)
    local firm_id = getFirmList()
    if firm_id then
        for firm in string.gmatch(firm_id, "[^,]+") do
            local accounts = getAccountList(firm)
            if accounts then
                for account in string.gmatch(accounts, "[^,]+") do
                    local position = getPositionOfSecurity(firm, account, class_code, sec_code)
                    if position then
                        return position
                    end
                end
            end
        end
    end
    return nil
end

-- Функция выставления заявки
function QuikAPI:transmit_order(class_code, sec_code, side, quantity, price, account, client_code)
    local trans_id = getNumberOf("trans_id") + 1
    
    local order = {
        ACTION = "NEW_ORDER",
        TRANS_ID = trans_id,
        CLASSCODE = class_code,
        SECCODE = sec_code,
        ACCOUNT = account or "",
        CLIENT_CODE = client_code or "",
        QUANTITY = quantity,
        PRICE = price,
        OPERATION = side  -- 'B' для покупки, 'S' для продажи
    }
    
    local result = sendTransaction(order)
    if result == "" then
        return trans_id
    else
        return nil, result
    end
end

-- Функция отмены заявки
function QuikAPI:cancel_order(class_code, sec_code, order_id)
    local trans_id = getNumberOf("trans_id") + 1
    
    local cancel = {
        ACTION = "KILL_ORDER",
        TRANS_ID = trans_id,
        CLASSCODE = class_code,
        SECCODE = sec_code,
        ORDER_KEY = order_id
    }
    
    local result = sendTransaction(cancel)
    if result == "" then
        return true
    else
        return false, result
    end
end

-- Функция получения списка заявок
function QuikAPI:get_orders_list()
    local orders = {}
    local num = getNumberOf("orders")
    
    for i = 0, num - 1 do
        local order = getOrderInfo(i)
        if order then
            table.insert(orders, order)
        end
    end
    
    return orders
end

-- Функция получения списка сделок
function QuikAPI:get_trades_list()
    local trades = {}
    local num = getNumberOf("trades")
    
    for i = 0, num - 1 do
        local trade = getTradeInfo(i)
        if trade then
            table.insert(trades, trade)
        end
    end
    
    return trades
end

-- Функция получения всех доступных инструментов
function QuikAPI:get_all_securities()
    local securities = {}
    local classes = self:getClassesList()
    
    for class in string.gmatch(classes, "[^,]+") do
        local sec_list = getSecurityList(class)
        if sec_list then
            for sec in string.gmatch(sec_list, "[^,]+") do
                local sec_info = self:getSecurityInfo(class, sec)
                if sec_info then
                    table.insert(securities, {
                        class = class,
                        code = sec,
                        name = sec_info.name,
                        short_name = sec_info.short_name
                    })
                end
            end
        end
    end
    
    return securities
end

-- Функция получения данных для подписки на стакан
function QuikAPI:subscribe_level2_quotes(class_code, sec_code)
    return Subscribe_Level_II_Quotes(class_code, sec_code)
end

-- Функция отписки от стакана
function QuikAPI:unsubscribe_level2_quotes(class_code, sec_code)
    return Unsubscribe_Level_II_Quotes(class_code, sec_code)
end

return QuikAPI