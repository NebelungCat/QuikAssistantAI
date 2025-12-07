-- Пример пользовательского файла настроек для QuikAssistantAI
-- user_config.lua
-- Этот файл можно использовать для переопределения стандартных настроек

local user_config = {}

-- Основные настройки
user_config.general = {
    trade_time_start = "10:00",  -- Время начала торгов
    trade_time_end = "18:00",    -- Время окончания торгов
    log_file = "my_quik_assistant.log",  -- Файл лога
    csv_file_path = "my_trade_signals.csv",  -- Путь к файлу с торговыми сигналами
    check_interval = 2000  -- Интервал проверки (в миллисекундах)
}

-- Поддерживаемые брокеры
user_config.brokers = {
    "Финам",
    "ВТБ"
}

-- Поддерживаемые типы ценных бумаг
user_config.security_types = {
    "акции",
    "облигации"
}

-- Настройки безопасности
user_config.security = {
    max_order_value = 500000,  -- Максимальная стоимость одной заявки (в рублях)
    max_daily_volume = 5000000,  -- Максимальный дневной оборот (в рублях)
    validate_orders = true  -- Проверять заявки перед выставлением
}

-- Настройки API
user_config.api = {
    timeout = 3000,  -- Таймаут для запросов к API (в миллисекундах)
    retry_count = 2  -- Количество попыток повтора при ошибке
}

return user_config