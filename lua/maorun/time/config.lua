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

M.weekdayNumberMap = {
    Sunday = 0,
    Monday = 1,
    Tuesday = 2,
    Wednesday = 3,
    Thursday = 4,
    Friday = 5,
    Saturday = 6,
}

M.obj = {
    path = nil,
    content = {}, -- Initialize content as an empty table
}

M.defaults = {
    path = vim.fn.stdpath('data') .. os_sep .. 'maorun-time.json',
    hoursPerWeekday = M.defaultHoursPerWeekday,
}

-- This 'config' table will be populated by the init function later
-- For now, it can be initialized with defaults, or left empty
-- and the main init.lua or core.lua will handle merging user_config with defaults.
-- Let's initialize it with defaults for now.
M.config = vim.deepcopy(M.defaults) -- Use deepcopy to avoid modifying defaults unintentionally

return M
