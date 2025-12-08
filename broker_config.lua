-- Конфигурационный файл с параметрами брокеров для торгового ассистента QUIK

local broker_config = {
    FINAM = {
        Broker = "Финам",
        ClientCode = "12345", -- Заменить на реальный код клиента
        AccountCode = "NL0011111111", -- Заменить на реальный счет
        AccountCodeSpb = "SPB0011111111", -- Заменить на реальный счет СПБ
        FirmId = "SPBFUT1", -- Заменить на реальный FirmId
        MaxOrderVolume = 1000000,
        MinOrderVolume = 1,
        MinYield = 0.01, -- Минимальная допустимая доходность
        MaxBondNominal = 10000000, -- Максимальный номинал облигаций
        Commission = 0.0005, -- Комиссия брокера
        SupportedClasses = {"TQBR", "TQDE", "SPBFUT", "SPBOPT"}, -- Поддерживаемые классы инструментов
        TimeRestrictions = { -- Ограничения по времени
            StartHour = 10, -- Начало торгов (час)
            EndHour = 18,   -- Конец торгов (час)
            StartMinute = 0, -- Начало торгов (минуты)
            EndMinute = 45   -- Конец торгов (минуты)
        }
    },
    VTB = {
        Broker = "ВТБ",
        ClientCode = "67890", -- Заменить на реальный код клиента
        AccountCode = "VTB0011111111", -- Заменить на реальный счет
        AccountCodeSpb = "VTB0022222222", -- Заменить на реальный счет СПБ
        FirmId = "VTB", -- Заменить на реальный FirmId
        MaxOrderVolume = 500000,
        MinOrderVolume = 1,
        MinYield = 0.005,
        MaxBondNominal = 5000000,
        Commission = 0.0003,
        SupportedClasses = {"TQBR", "TQDE", "SPBFUT"},
        TimeRestrictions = {
            StartHour = 9,
            EndHour = 19,
            StartMinute = 30,
            EndMinute = 30
        }
    },
    PSB = {
        Broker = "Промсвязьбанк",
        ClientCode = "54321", -- Заменить на реальный код клиента
        AccountCode = "PSB0011111111", -- Заменить на реальный счет
        AccountCodeSpb = "PSB0022222222", -- Заменить на реальный счет СПБ
        FirmId = "PSB", -- Заменить на реальный FirmId
        MaxOrderVolume = 2000000,
        MinOrderVolume = 1,
        MinYield = 0.015,
        MaxBondNominal = 15000000,
        Commission = 0.0004,
        SupportedClasses = {"TQBR", "TQDE", "SPBFUT", "SPBOPT"},
        TimeRestrictions = {
            StartHour = 10,
            EndHour = 18,
            StartMinute = 0,
            EndMinute = 30
        }
    },
    RSHB = {
        Broker = "Россельхозбанк",
        ClientCode = "98765", -- Заменить на реальный код клиента
        AccountCode = "RSHB0011111111", -- Заменить на реальный счет
        AccountCodeSpb = "RSHB0022222222", -- Заменить на реальный счет СПБ
        FirmId = "RSHB", -- Заменить на реальный FirmId
        MaxOrderVolume = 800000,
        MinOrderVolume = 1,
        MinYield = 0.012,
        MaxBondNominal = 8000000,
        Commission = 0.0006,
        SupportedClasses = {"TQBR", "TQDE", "SPBFUT"},
        TimeRestrictions = {
            StartHour = 9,
            EndHour = 18,
            StartMinute = 0,
            EndMinute = 0
        }
    }
}

-- Функция получения параметров конкретного брокера
local function get_broker_params(broker_code)
    return broker_config[broker_code]
end

-- Функция проверки, поддерживает ли брокер данный класс инструмента
local function supports_class(broker_code, class_code)
    local broker = broker_config[broker_code]
    if not broker then return false end
    
    for _, supported_class in ipairs(broker.SupportedClasses) do
        if supported_class == class_code then
            return true
        end
    end
    return false
end

-- Функция проверки, находится ли текущее время в разрешенном диапазоне для брокера
local function is_time_allowed(broker_code)
    local broker = broker_config[broker_code]
    if not broker then return false end
    
    local current_time = os.date("*t")
    local current_hour = current_time.hour
    local current_minute = current_time.min
    
    local start_time = broker.TimeRestrictions.StartHour * 60 + broker.TimeRestrictions.StartMinute
    local end_time = broker.TimeRestrictions.EndHour * 60 + broker.TimeRestrictions.EndMinute
    local current_total_minutes = current_hour * 60 + current_minute
    
    return current_total_minutes >= start_time and current_total_minutes <= end_time
end

return {
    brokers = broker_config,
    get_broker_params = get_broker_params,
    supports_class = supports_class,
    is_time_allowed = is_time_allowed
}