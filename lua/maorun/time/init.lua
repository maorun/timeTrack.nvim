local Path = require('plenary.path')
local os_sep = require('plenary.path').path.sep
local notify = require('notify')

local wdayToEngName = {
    [1] = 'Sunday',
    [2] = 'Monday',
    [3] = 'Tuesday',
    [4] = 'Wednesday',
    [5] = 'Thursday',
    [6] = 'Friday',
    [7] = 'Saturday',
}

local function save(obj)
    Path:new(obj.path):write(vim.fn.json_encode(obj.content), 'w')
end

local obj = {
    path = nil,
}

local defaultHoursPerWeekday = {
    Monday = 8,
    Tuesday = 8,
    Wednesday = 8,
    Thursday = 8,
    Friday = 8,
    Saturday = 0,
    Sunday = 0,
}

local weekdayNumberMap = {
    Sunday = 0,
    Monday = 1,
    Tuesday = 2,
    Wednesday = 3,
    Thursday = 4,
    Friday = 5,
    Saturday = 6,
}

local defaults = {
    path = vim.fn.stdpath('data') .. os_sep .. 'maorun-time.json',
    hoursPerWeekday = defaultHoursPerWeekday,
}
local config = defaults

local function init(user_config)
    config = vim.tbl_deep_extend('force', defaults, user_config or {})
    if user_config.hoursPerWeekday ~= nil then
        config.hoursPerWeekday = user_config.hoursPerWeekday
    end
    obj.path = config.path
    local p = Path:new(obj.path)
    if not p:exists() then
        p:touch({ parents = true })
    end

    local data = Path:new(obj.path):read()
    if data ~= '' then
        obj.content = vim.json.decode(data)
    else
        obj.content = {}
    end
    obj.content['hoursPerWeekday'] = config.hoursPerWeekday
    local sumHoursPerWeek = 0
    for _, value in pairs(obj.content.hoursPerWeekday) do
        sumHoursPerWeek = sumHoursPerWeek + value
    end
    if obj.content['data'] == nil then
        obj.content['data'] = {}
    end
    if obj.content['data'][os.date('%Y')] == nil then
        obj.content['data'][os.date('%Y')] = {}
    end

    local years = obj.content['data'][os.date('%Y')]
    if years[os.date('%W')] == nil then
        years[os.date('%W')] = {
            summary = {
                overhour = 0,
            },
            weekdays = {},
        }
    end
    return obj
end

---@param opts {weeknumber: string|osdate, year: string|osdate}|nil
local function calculate(opts)
    opts = vim.tbl_deep_extend('keep', opts or {}, {
        year = os.date('%Y'),
        weeknumber = os.date('%W'),
    })

    local year = opts.year
    local weeknumber = opts.weeknumber

    local yearData = obj.content['data'][year]
    local week = yearData[weeknumber]
    local prevWeekOverhour = 0
    -- Ensure yearData is not nil before trying to access it for prevWeekOverhour
    if yearData and yearData[string.format('%02d', weeknumber - 1)] ~= nil then
        prevWeekOverhour = yearData[string.format('%02d', weeknumber - 1)].summary.overhour
    end

    -- Ensure week and week['weekdays'] are not nil
    local weekdays = {}
    if week and week['weekdays'] then
        weekdays = week['weekdays']
    end

    local summary = {}
    if week and week['summary'] then
        summary = week['summary']
    end

    local loggedWeekdays = 0
    local timeInWeek = 0
    summary.overhour = prevWeekOverhour

    for weekdayName, items in pairs(weekdays) do
        local timeInWeekday = 0
        for _, value in pairs(items.items) do
            if value.diffInHours ~= nil then
                timeInWeek = timeInWeek + value.diffInHours
                timeInWeekday = timeInWeekday + value.diffInHours
            end
        end

        weekdays[weekdayName].summary = {
            overhour = timeInWeekday - obj.content['hoursPerWeekday'][weekdayName],
            diffInHours = timeInWeekday,
        }
        timeInWeekday = 0
        loggedWeekdays = loggedWeekdays + 1
        summary.overhour = summary.overhour + weekdays[weekdayName].summary.overhour
    end
end

local function TimePause()
    init({ path = obj.path, hoursPerWeekday = obj.content['hoursPerWeekday'] })
    obj.content.paused = true
    save(obj)
    notify({
        'Timetracking paused',
    }, 'info', { title = 'TimeTracking - Pause' })
end

local function TimeResume()
    init({ path = obj.path, hoursPerWeekday = obj.content['hoursPerWeekday'] })
    obj.content.paused = false
    save(obj)
    notify({
        'Timetracking resumed',
    }, 'info', { title = 'TimeTracking - Resume' })
end
local function isPaused()
    init({ path = obj.path, hoursPerWeekday = obj.content['hoursPerWeekday'] })
    return obj.content.paused
end

local function TimeStart(weekday, time)
    init({ path = obj.path, hoursPerWeekday = obj.content['hoursPerWeekday'] })
    if isPaused() then
        return
    end

    if weekday == nil then
        local current_wday_numeric = os.date('*t', os.time()).wday
        weekday = wdayToEngName[current_wday_numeric]
    end
    if time == nil then
        time = os.time()
    end
    local years = obj.content['data'][os.date('%Y')]
    if years[os.date('%W')]['weekdays'][weekday] == nil then
        years[os.date('%W')]['weekdays'][weekday] = {
            summary = {},
            items = {},
        }
    end
    local dayItem = years[os.date('%W')]['weekdays'][weekday]
    local canStart = true
    for _, item in pairs(dayItem.items) do
        canStart = canStart and (item.startTime ~= nil and item.endTime ~= nil)
    end
    if canStart then
        local timeReadable = os.date('*t', time)
        table.insert(dayItem.items, {
            startTime = time,
            startReadable = string.format('%02d:%02d', timeReadable.hour, timeReadable.min),
        })
    end
    save(obj)
end

local function TimeStop(weekday, time)
    init({ path = obj.path, hoursPerWeekday = obj.content['hoursPerWeekday'] })
    if isPaused() then
        return
    end

    if weekday == nil then
        local current_wday_numeric = os.date('*t', os.time()).wday
        weekday = wdayToEngName[current_wday_numeric]
    end
    if time == nil then
        time = os.time()
    end
    local years = obj.content['data'][os.date('%Y')]
    local dayItem = years[os.date('%W')]['weekdays'][weekday]
    for _, item in pairs(dayItem.items) do
        if item.endTime == nil then
            item.endTime = time
            local timeReadable = os.date('*t', time)
            item.endReadable = string.format('%02d:%02d', timeReadable.hour, timeReadable.min)
            item.diffInHours = os.difftime(item.endTime, item.startTime) / 60 / 60
        end
    end
    calculate()
    save(obj)
    notify({
        'Heute: ' .. string.format('%.2f', dayItem.summary.overhour) .. ' Stunden',
        'Gesamt: ' .. string.format('%.2f', years[os.date('%W')].summary.overhour) .. ' Stunden',
    }, 'info', { title = 'TimeTracking - Stop' })
end

-- calculate an average over the hoursPerWeekday
local function calculateAverage()
    local sum = 0
    local count = 0
    for _, value in pairs(config.hoursPerWeekday) do
        sum = sum + value
        count = count + 1
    end
    return sum / count
end

local function saveTime(startTime, endTime, weekday, clearDay)
    local years = obj.content['data'][os.date('%Y')]
    if clearDay == nil and obj.content['data'][os.date('%Y')][os.date('%W')][weekday] == nil then
        obj.content['data'][os.date('%Y')][os.date('%W')]['weekdays'][weekday] = {
            summary = {},
            items = {},
        }
    end
    if years[os.date('%W')]['weekdays'][weekday] == nil then
        years[os.date('%W')]['weekdays'][weekday] = {
            summary = {},
            items = {},
        }
    end
    local dayItem = obj.content['data'][os.date('%Y')][os.date('%W')]['weekdays'][weekday]
    local timeReadableStart = os.date('*t', startTime)
    local item = {
        startTime = startTime,
        startReadable = string.format('%02d:%02d', timeReadableStart.hour, timeReadableStart.min),
        endTime = endTime,
    }
    local timeReadableEnd = os.date('*t', endTime)
    item.endReadable = string.format('%02d:%02d', timeReadableEnd.hour, timeReadableEnd.min)

    item.diffInHours = os.difftime(item.endTime, item.startTime) / 60 / 60

    table.insert(dayItem.items, item)
    calculate()
    save(obj)

    notify({
        'Heute: ' .. string.format('%.2f', dayItem.summary.overhour) .. ' Stunden',
        'Gesamt: ' .. string.format('%.2f', years[os.date('%W')].summary.overhour) .. ' Stunden',
    }, 'info', { title = 'TimeTracking - Stop' })
end

-- adds time into the current week
---@param opts { time: number, weekday: string|osdate, clearDay?: string }
local function addTime(opts)
    local time = opts.time
    local weekday = opts.weekday
    local clearDay = opts.clearDay

    if clearDay == nil then
        clearDay = 'nope'
    else
        clearDay = nil
    end
    init({ path = obj.path, hoursPerWeekday = obj.content['hoursPerWeekday'] })
    local years = obj.content['data'][os.date('%Y')]
    if weekday == nil then
        local current_wday_numeric = os.date('*t', os.time()).wday
        weekday = wdayToEngName[current_wday_numeric]
    end

    local week = years[os.date('%W')]
    local currentWeekdayNumeric = os.date('*t').wday - 1 -- Sunday=0, Monday=1, etc.
    local targetWeekdayNumeric = weekdayNumberMap[weekday]

    -- If targetWeekdayNumeric is nil, treat as a custom/new weekday
    if targetWeekdayNumeric == nil then
        targetWeekdayNumeric = currentWeekdayNumeric
    end

    local diffDays = currentWeekdayNumeric - (targetWeekdayNumeric or currentWeekdayNumeric)
    if diffDays < 0 then
        diffDays = diffDays + 7
    end

    if week['weekdays'][weekday] == nil then
        week['weekdays'][weekday] = {
            items = {},
        }
    end

    -- Get current timestamp
    local current_ts = os.time()

    -- Subtract "diffDays" days from the current timestamp
    local target_day_ref_ts = current_ts - (diffDays * 24 * 3600)
    local target_day_t_info = os.date('*t', target_day_ref_ts)

    -- Extract hours/min/sec from "time"
    local minutes_float = (time - math.floor(time)) * 60
    local seconds_float = (minutes_float - math.floor(minutes_float)) * 60
    local hours_to_subtract = math.floor(time)
    local minutes_to_subtract = math.floor(minutes_float)
    local seconds_to_subtract = math.floor(seconds_float)

    -- Build a new osdateparam table with only supported fields
    local endTime_date_table = {
        year = target_day_t_info.year,
        month = target_day_t_info.month,
        day = target_day_t_info.day,
        hour = 23,
        min = 0,
        sec = 0,
        isdst = target_day_t_info.isdst,
    }

    local endTime_ts = os.time(endTime_date_table)

    -- Calculate startTime by subtracting the duration from endTime_ts
    local startTime_ts = endTime_ts
        - (hours_to_subtract * 3600 + minutes_to_subtract * 60 + seconds_to_subtract)

    local startTime = startTime_ts
    local endTime = endTime_ts

    local paused = isPaused()
    if paused then
        TimeResume()
    end

    saveTime(startTime, endTime, weekday, clearDay)

    if paused then
        TimePause()
    end
    return obj
end

-- subtracts time from the current week
local function subtractTime(time, weekday)
    init({ path = obj.path, hoursPerWeekday = obj.content['hoursPerWeekday'] })
    local years = obj.content['data'][os.date('%Y')]
    if weekday == nil then
        local current_wday_numeric = os.date('*t', os.time()).wday
        weekday = wdayToEngName[current_wday_numeric]
    end

    local week = years[os.date('%W')]
    local currentWeekdayNumeric = os.date('*t').wday - 1 -- Sunday=0, Monday=1, etc.
    local targetWeekdayNumeric = weekdayNumberMap[weekday]

    if targetWeekdayNumeric == nil then
        -- Use notify if available, or print an error. Let's assume notify is available as it's used elsewhere.
        if notify then
            notify(
                "Error: Weekday '"
                .. tostring(weekday)
                .. "' is not recognized in weekdayNumberMap.",
                'error',
                { title = 'TimeTracking Error' }
            )
        else
            print(
                "Error: Weekday '"
                .. tostring(weekday)
                .. "' is not recognized in weekdayNumberMap."
            )
        end
        return -- Stop execution if weekday is invalid
    end

    local diffDays = currentWeekdayNumeric - targetWeekdayNumeric
    if diffDays < 0 then
        diffDays = diffDays + 7
    end

    if week['weekdays'][weekday] == nil then
        week['weekdays'][weekday] = {
            items = {},
        }
    end

    local current_ts = os.time()

    local target_day_ref_ts = current_ts - (diffDays * 24 * 3600)
    local target_day_t_info = os.date('*t', target_day_ref_ts)

    local minutes_float = (time - math.floor(time)) * 60
    local seconds_float = (minutes_float - math.floor(minutes_float)) * 60
    local hours_to_subtract = math.floor(time)
    local minutes_to_subtract = math.floor(minutes_float)
    local seconds_to_subtract = math.floor(seconds_float)

    local endTime_date_table = {
        year = target_day_t_info.year,
        month = target_day_t_info.month,
        day = target_day_t_info.day,
        hour = 23,
        min = 0,
        sec = 0,
        isdst = target_day_t_info.isdst,
    }

    local startTime_ts = os.time(endTime_date_table)
    local endTime_ts = startTime_ts
        - (hours_to_subtract * 3600 + minutes_to_subtract * 60 + seconds_to_subtract)

    local startTime = startTime_ts
    local endTime = endTime_ts

    local paused = isPaused()
    if paused then
        TimeResume()
    end

    saveTime(startTime, endTime, weekday, 'nope')

    if paused then
        TimePause()
    end

    return obj
end

local function setIllDay(weekday)
    addTime({
        time = calculateAverage(),
        weekday = weekday,
        clearDay = 'yes',
    })
    return obj
end

local function clearDay(weekday)
    local years = obj.content['data'][os.date('%Y')]
    local week = years[os.date('%W')]
    local items = week['weekdays'][weekday].items
    for key, _ in pairs(items) do
        items[key] = nil
    end
    calculate()
    save(obj)
end

local function setTime(time, weekday)
    clearDay(weekday)
    addTime({
        time = time,
        weekday = weekday,
        clearDay = 'yes',
    })
end

local timeGroup = vim.api.nvim_create_augroup('Maorun-Time', {})
vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter', 'VimEnter' }, {
    group = timeGroup,
    desc = 'Start Timetracking on VimEnter or BufEnter (if second vim was leaved)',
    callback = function()
        TimeStart()
    end,
})
vim.api.nvim_create_autocmd('VimLeave', {
    group = timeGroup,
    desc = 'End Timetracking on VimLeave',
    callback = function()
        TimeStop()
    end,
})

---@param opts { hours: boolean, weekday: boolean }
---@param callback fun(hours:number, weekday: string) the function to call
local function select(opts, callback)
    opts = vim.tbl_deep_extend('keep', opts or {}, {
        hours = true,
        weekday = true,
    })

    local selections = {}
    local selectionNumbers = {}
    for _, value in pairs(weekdayNumberMap) do
        if not selectionNumbers[value] then
            selectionNumbers[value] = 1
            selections[#selections + 1] = _
        end
    end

    ---@param weekday string
    local function selectHours(weekday)
        vim.ui.input({
            prompt = 'How many hours? ',
        }, function(input)
            local n = tonumber(input)
            if n == nil or input == nil or input == '' then
                return
            end
            callback(n, weekday)
        end)
    end

    if pcall(require, 'telescope') then
        local telescopeSelect = require('maorun.time.weekday_select')
        telescopeSelect({
            prompt_title = 'Which day?',
            list = selections,
            action = function(weekday)
                selectHours(weekday)
            end,
        })
    else
        vim.ui.select(selections, {
            prompt = 'Which day? ',
        }, function(weekday)
            selectHours(weekday)
        end)
    end
end

Time = {
    add = function()
        select({}, function(hours, weekday)
            addTime({ time = hours, weekday = weekday })
        end)
    end,
    addTime = addTime,
    subtract = function()
        select({}, function(hours, weekday)
            subtractTime(hours, weekday)
        end)
    end,
    subtractTime = subtractTime,
    clearDay = clearDay,
    TimePause = TimePause,
    TimeResume = TimeResume,
    TimeStop = TimeStop,
    set = function()
        select({}, function(hours, weekday)
            setTime(hours, weekday)
        end)
    end,
    setTime = setTime,
    setIllDay = setIllDay,
    setHoliday = setIllDay,
    calculate = function(opts) -- Accept opts
        init({ path = obj.path, hoursPerWeekday = obj.content['hoursPerWeekday'] })
        calculate(opts)        -- Pass opts to local calculate
        save(obj)
        return obj
    end,
}

return {
    setup = init,
    TimeStart = TimeStart,
    TimeStop = TimeStop,
    TimePause = TimePause,
    TimeResume = TimeResume,
    setIllDay = setIllDay,
    setHoliday = setIllDay,
    addTime = addTime,
    subtractTime = subtractTime,
    setTime = setTime,
    clearDay = clearDay,
    isPaused = isPaused,
    calculate = function(opts) -- Accept opts
        init({ path = obj.path, hoursPerWeekday = obj.content['hoursPerWeekday'] })
        calculate(opts)        -- Pass opts to local calculate
        save(obj)
        return obj
    end,

    weekdays = weekdayNumberMap,
}
