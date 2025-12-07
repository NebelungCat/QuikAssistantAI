-- Скрипт для запуска QuikAssistantAI в QUIK
-- QuikAssistantAI_script.lua

-- Подключаем основные модули
local QuikAssistantAI = require("QuikAssistantAI")
local EventHandler = require("EventHandler")

-- Создаем экземпляр ассистента
local assistant = QuikAssistantAI:new()
local event_handler = EventHandler:new(assistant)

-- Функция OnInit - вызывается при запуске скрипта
function OnInit()
    print("Инициализация QuikAssistantAI...")
    return 0
end

-- Функция OnStop - вызывается при остановке скрипта
function OnStop()
    print("Остановка QuikAssistantAI...")
    if assistant then
        assistant:disconnect()
    end
end

-- Основная функция запуска ассистента
function main()
    print("Запуск торгового ассистента...")
    
    if assistant:start() then
        print("Торговый ассистент успешно запущен")
    else
        print("Ошибка запуска торгового ассистента")
    end
end

-- Функция обработки изменения стакана
function OnQuote(class_code, sec_code)
    event_handler:OnQuote(class_code, sec_code)
end

-- Функция обработки сделки
function OnTrade(trade)
    event_handler:OnTrade(trade)
end

-- Функция обработки заявки
function OnOrder(order)
    event_handler:OnOrder(order)
end

-- Функция обработки изменения параметров
function OnParam(class_code, sec_code)
    event_handler:OnParam(class_code, sec_code)
end

-- Функция обработки подключения к серверу
function OnConnected(status)
    event_handler:OnConnected(status)
end

-- Функция обработки разрыва соединения
function OnConnectionBroken()
    event_handler:OnConnectionBroken()
end

-- Функция обработки восстановления соединения
function OnConnectionRestored()
    event_handler:OnConnectionRestored()
end