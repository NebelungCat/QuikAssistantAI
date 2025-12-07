-- Модуль обработки событий QUIK
-- EventHandler

EventHandler = {}

function EventHandler:new(assistant)
    local obj = {
        assistant = assistant
    }
    setmetatable(obj, {__index = self})
    return obj
end

-- Обработчик изменения стакана котировок
function EventHandler:OnQuote(class_code, sec_code)
    -- В этой функции можно реализовать реакцию на изменение котировок
    -- Например, обновление позиций, пересчет прибыли/убытка и т.д.
    print("Изменение котировок: " .. class_code .. ":" .. sec_code)
    
    -- Здесь можно добавить логику реакции на изменение котировок
    -- Например, проверка триггеров для выставления заявок
end

-- Обработчик сделки
function EventHandler:OnTrade(trade)
    -- Обработка совершенной сделки
    print("Совершена сделка: " .. trade.sec_code .. " в количестве " .. trade.qty .. " по цене " .. trade.price)
    
    -- Логирование сделки
    if self.assistant then
        self.assistant:log("Совершена сделка: " .. trade.sec_code .. " (" .. trade.class_code .. ") " .. 
                          trade.operation .. " " .. trade.qty .. " шт. по цене " .. trade.price)
    end
    
    -- Здесь можно добавить логику обновления позиций и т.д.
end

-- Обработчик заявки
function EventHandler:OnOrder(order)
    -- Обработка изменения статуса заявки
    local status_text = ""
    if order.flags then
        -- Флаги заявки: 1 - новая, 2 - частично исполнена, 4 - исполнена, 8 - отменена, 16 - отклонена
        if bit32 and bit32.band(order.flags, 4) == 4 then
            status_text = "исполнена"
        elseif bit32 and bit32.band(order.flags, 2) == 2 then
            status_text = "частично исполнена"
        elseif bit32 and bit32.band(order.flags, 8) == 8 then
            status_text = "отменена"
        elseif bit32 and bit32.band(order.flags, 16) == 16 then
            status_text = "отклонена"
        else
            status_text = "новая"
        end
    end
    
    print("Изменение статуса заявки: #" .. order.order_num .. " " .. order.sec_code .. " - " .. status_text)
    
    -- Обновляем статус заявки в списке
    if self.assistant then
        for _, ord in ipairs(self.assistant.orders) do
            if ord.id == order.order_num then
                ord.status = status_text
                break
            end
        end
        
        self.assistant:log("Заявка #" .. order.order_num .. " " .. order.sec_code .. " - " .. status_text)
    end
end

-- Обработчик изменения параметров
function EventHandler:OnParam(class_code, sec_code)
    -- Обработка изменения параметров инструмента
    print("Изменение параметров: " .. class_code .. ":" .. sec_code)
end

-- Обработчик подключения к серверу
function EventHandler:OnConnected(status)
    print("Изменение статуса подключения к серверу: " .. status)
    
    if self.assistant then
        if status == 3 then  -- Подключено
            self.assistant.is_connected = true
            self.assistant:log("Подключение к серверу установлено")
        else
            self.assistant.is_connected = false
            self.assistant:log("Подключение к серверу потеряно")
        end
    end
end

-- Обработчик изменения статуса соединения
function EventHandler:OnConnectionBroken()
    print("Соединение с сервером разорвано")
    
    if self.assistant then
        self.assistant.is_connected = false
        self.assistant:log("Соединение с сервером разорвано")
    end
end

-- Обработчик восстановления соединения
function EventHandler:OnConnectionRestored()
    print("Соединение с сервером восстановлено")
    
    if self.assistant then
        self.assistant.is_connected = true
        self.assistant:log("Соединение с сервером восстановлено")
    end
end

return EventHandler