-- Файл настроек для QuikAssistantAI
-- config.lua

local config = {}

-- Основные настройки
config.general = {
    trade_time_start = "09:50",  -- Время начала торгов
    trade_time_end = "18:40",    -- Время окончания торгов
    log_file = "quik_assistant.log",  -- Файл лога
    csv_file_path = "trade_signals.csv",  -- Путь к файлу с торговыми сигналами
    check_interval = 1000  -- Интервал проверки (в миллисекундах)
}

-- Поддерживаемые брокеры
config.brokers = {
    "Финам",
    "ВТБ",
    "Промсвязьбанк",
    "Россельхозбанк"
}

-- Поддерживаемые типы ценных бумаг
config.security_types = {
    "акции",
    "облигации",
    "иностранные_бумаги"
}

-- Настройки безопасности
config.security = {
    max_order_value = 1000000,  -- Максимальная стоимость одной заявки (в рублях)
    max_daily_volume = 10000000,  -- Максимальный дневной оборот (в рублях)
    validate_orders = true  -- Проверять заявки перед выставлением
}

-- Настройки API
config.api = {
    timeout = 5000,  -- Таймаут для запросов к API (в миллисекундах)
    retry_count = 3  -- Количество попыток повтора при ошибке
}

return config