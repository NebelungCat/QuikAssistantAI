-- Файл инициализации для QUIK
-- init.lua

-- Импортируем основной скрипт ассистента
if pcall(dofile, "QuikAssistantAI_script.lua") then
    print("QuikAssistantAI успешно загружен")
else
    print("Ошибка загрузки QuikAssistantAI")
end