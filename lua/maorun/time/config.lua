local os_sep = require('plenary.path').path.sep

local M = {}

M.wdayToEngName = {
    [1] = 'Sunday',
    [2] = 'Monday',
    [3] = 'Tuesday',
    [4] = 'Wednesday',
    [5] = 'Thursday',
    [6] = 'Friday',
    [7] = 'Saturday',
}

M.defaultHoursPerWeekday = {
    Monday = 8,
    Tuesday = 8,
    Wednesday = 8,
    Thursday = 8,
    Friday = 8,
    Saturday = 0,
    Sunday = 0,
}

-- Default core working hours (24-hour format)
M.defaultCoreWorkingHours = {
    Monday = { start = 9, finish = 17 }, -- 9 AM to 5 PM
    Tuesday = { start = 9, finish = 17 },
    Wednesday = { start = 9, finish = 17 },
    Thursday = { start = 9, finish = 17 },
    Friday = { start = 9, finish = 17 },
    Saturday = nil, -- No core hours on weekends
    Sunday = nil,
}

-- Predefined work model presets
M.workModelPresets = {
    standard = {
        name = 'Standard 40-hour week',
        hoursPerWeekday = {
            Monday = 8,
            Tuesday = 8,
            Wednesday = 8,
            Thursday = 8,
            Friday = 8,
            Saturday = 0,
            Sunday = 0,
        },
        coreWorkingHours = {
            Monday = { start = 9, finish = 17 },
            Tuesday = { start = 9, finish = 17 },
            Wednesday = { start = 9, finish = 17 },
            Thursday = { start = 9, finish = 17 },
            Friday = { start = 9, finish = 17 },
            Saturday = nil,
            Sunday = nil,
        },
    },
    fourDayWeek = {
        name = '4-day work week (32 hours)',
        hoursPerWeekday = {
            Monday = 8,
            Tuesday = 8,
            Wednesday = 8,
            Thursday = 8,
            Friday = 0,
            Saturday = 0,
            Sunday = 0,
        },
        coreWorkingHours = {
            Monday = { start = 9, finish = 17 },
            Tuesday = { start = 9, finish = 17 },
            Wednesday = { start = 9, finish = 17 },
            Thursday = { start = 9, finish = 17 },
            Friday = nil,
            Saturday = nil,
            Sunday = nil,
        },
    },
    partTime = {
        name = 'Part-time (20 hours)',
        hoursPerWeekday = {
            Monday = 4,
            Tuesday = 4,
            Wednesday = 4,
            Thursday = 4,
            Friday = 4,
            Saturday = 0,
            Sunday = 0,
        },
        coreWorkingHours = {
            Monday = { start = 10, finish = 14 }, -- 10 AM to 2 PM
            Tuesday = { start = 10, finish = 14 },
            Wednesday = { start = 10, finish = 14 },
            Thursday = { start = 10, finish = 14 },
            Friday = { start = 10, finish = 14 },
            Saturday = nil,
            Sunday = nil,
        },
    },
    flexibleCore = {
        name = 'Flexible with core hours (10-16)',
        hoursPerWeekday = {
            Monday = 8,
            Tuesday = 8,
            Wednesday = 8,
            Thursday = 8,
            Friday = 8,
            Saturday = 0,
            Sunday = 0,
        },
        coreWorkingHours = {
            Monday = { start = 10, finish = 16 }, -- 10 AM to 4 PM core
            Tuesday = { start = 10, finish = 16 },
            Wednesday = { start = 10, finish = 16 },
            Thursday = { start = 10, finish = 16 },
            Friday = { start = 10, finish = 16 },
            Saturday = nil,
            Sunday = nil,
        },
    },
}

M.weekdayNumberMap = {
    Sunday = 0,
    Monday = 1,
    Tuesday = 2,
    Wednesday = 3,
    Thursday = 4,
    Friday = 5,
    Saturday = 6,
}

M.engNameToWday = {
    Sunday = 1,
    Monday = 2,
    Tuesday = 3,
    Wednesday = 4,
    Thursday = 5,
    Friday = 6,
    Saturday = 7,
}

M.obj = {
    path = nil,
    content = {}, -- Initialize content as an empty table
}

M.defaults = {
    path = vim.fn.stdpath('data') .. os_sep .. 'maorun-time.json',
    hoursPerWeekday = M.defaultHoursPerWeekday,
    coreWorkingHours = M.defaultCoreWorkingHours,
    workModel = nil, -- Can be set to a preset name (e.g., 'fourDayWeek', 'partTime', etc.)
    notifications = {
        dailyGoal = {
            enabled = true,
            oncePerDay = true,
            recurringMinutes = 30,
        },
        coreHoursCompliance = {
            enabled = false, -- Disabled by default to not interfere with existing workflows
            warnOutsideCoreHours = true,
            oncePerDay = true,
        },
    },
}

-- This 'config' table will be populated by the init function later
-- For now, it can be initialized with defaults, or left empty
-- and the main init.lua or core.lua will handle merging user_config with defaults.
-- Let's initialize it with defaults for now.
M.config = vim.deepcopy(M.defaults) -- Use deepcopy to avoid modifying defaults unintentionally

---Apply a work model preset to the configuration
---@param preset_name string Name of the preset (e.g., 'fourDayWeek', 'partTime')
---@return table|nil The preset configuration or nil if not found
function M.applyWorkModelPreset(preset_name)
    local preset = M.workModelPresets[preset_name]
    if not preset then
        return nil
    end

    return {
        hoursPerWeekday = vim.deepcopy(preset.hoursPerWeekday),
        coreWorkingHours = vim.deepcopy(preset.coreWorkingHours),
        workModel = preset_name,
    }
end

---Get available work model presets
---@return table List of available preset names with descriptions
function M.getAvailableWorkModels()
    local models = {}
    for name, preset in pairs(M.workModelPresets) do
        models[name] = preset.name
    end
    return models
end

---Validate core working hours configuration
---@param coreHours table Core working hours configuration
---@return boolean, string True if valid, false with error message if invalid
function M.validateCoreWorkingHours(coreHours)
    if type(coreHours) ~= 'table' then
        return false, 'coreWorkingHours must be a table'
    end

    for weekday, hours in pairs(coreHours) do
        if hours ~= nil then
            if type(hours) ~= 'table' then
                return false, string.format('coreWorkingHours[%s] must be a table or nil', weekday)
            end

            if type(hours.start) ~= 'number' or type(hours.finish) ~= 'number' then
                return false,
                    string.format(
                        'coreWorkingHours[%s] must have numeric start and finish times',
                        weekday
                    )
            end

            if hours.start < 0 or hours.start > 24 or hours.finish < 0 or hours.finish > 24 then
                return false,
                    string.format('coreWorkingHours[%s] times must be between 0 and 24', weekday)
            end

            if hours.start >= hours.finish then
                return false,
                    string.format(
                        'coreWorkingHours[%s] start time must be before finish time',
                        weekday
                    )
            end
        end
    end

    return true, ''
end

---Check if a timestamp falls within core working hours for a given weekday
---@param timestamp number Unix timestamp
---@param weekday string Weekday name (e.g., 'Monday')
---@param coreHours table Core working hours configuration
---@return boolean True if within core hours, false otherwise
function M.isWithinCoreHours(timestamp, weekday, coreHours)
    if not coreHours or not coreHours[weekday] then
        return true -- No core hours defined, always valid
    end

    local core = coreHours[weekday]
    if not core then
        return true -- No core hours for this weekday
    end

    local time_info = os.date('*t', timestamp)
    local hour_decimal = time_info.hour + time_info.min / 60

    return hour_decimal >= core.start and hour_decimal <= core.finish
end

return M
