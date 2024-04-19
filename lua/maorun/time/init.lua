local Path = require('plenary.path')
local os_sep = require('plenary.path').path.sep
local notify = require('notify')

local function save(obj)
    Path:new(obj.path):write(vim.fn.json_encode(obj.content), 'w')
end

local obj = {
    path = nil,
}

local defaultHoursPerWeekday = {
    Montag = 8,
    Dienstag = 8,
    Mittwoch = 8,
    Donnerstag = 8,
    Freitag = 8,

    Monday = 8,
    Tuesday = 8,
    Wednesday = 8,
    Thursday = 8,
    Friday = 8,
}

local function getWeekDay(time)
    return {
        [os.date('%A', os.time() + time)] = os.date('*t', os.time() + time).wday - 1,
    }
end
local weekdayNumberMap = vim.tbl_deep_extend(
    'force',
    getWeekDay(0),
    getWeekDay(60 * 60 * 24),
    getWeekDay(2 * 60 * 60 * 24),
    getWeekDay(3 * 60 * 60 * 24),
    getWeekDay(4 * 60 * 60 * 24),
    getWeekDay(5 * 60 * 60 * 24),
    getWeekDay(6 * 60 * 60 * 24)
)

local defaults = {
    path = vim.fn.stdpath('data') .. os_sep .. 'maorun-time.json',
    hoursPerWeekday = defaultHoursPerWeekday,
}
local config = defaults

local function init(user_config)
    config = vim.tbl_deep_extend('force', defaults, user_config or {})
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

local function calculate()
    local weeknumber = os.date('%W')
    local year = obj.content['data'][os.date('%Y')]
    local week = year[weeknumber]
    local prevWeekOverhour = 0
    if year[string.format('%02d', weeknumber - 1)] ~= nil then
        prevWeekOverhour = year[string.format('%02d', weeknumber - 1)].summary.overhour
    end

    local weekdays = week['weekdays']
    local summary = week['summary']
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
    init({ path = obj.path })
    obj.content.paused = true
    save(obj)
    notify({
        'Timetracking paused',
    }, 'info', { title = 'TimeTracking - Pause' })
end

local function TimeResume()
    init({ path = obj.path })
    obj.content.paused = false
    save(obj)
    notify({
        'Timetracking resumed',
    }, 'info', { title = 'TimeTracking - Resume' })
end
local function isPaused()
    init({ path = obj.path })
    return obj.content.paused
end

local function TimeStart(weekday, time)
    init({ path = obj.path })
    if isPaused() then
        return
    end

    if weekday == nil then
        weekday = os.date('%A')
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
    init({ path = obj.path })
    if isPaused() then
        return
    end

    if weekday == nil then
        weekday = os.date('%A')
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
    return sum / count / 2
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
local function addTime(time, weekday, clearDay)
    if clearDay == nil then
        clearDay = 'nope'
    else
        clearDay = nil
    end
    init({ path = obj.path })
    local years = obj.content['data'][os.date('%Y')]
    if weekday == nil then
        weekday = os.date('%A')
    end

    local week = years[os.date('%W')]
    local diffDays = weekdayNumberMap[os.date('%A')] - weekdayNumberMap[weekday]
    if diffDays < 0 then
        diffDays = diffDays + 7
    end

    if week['weekdays'][weekday] == nil then
        week['weekdays'][weekday] = {
            items = {},
        }
    end
    ---@diagnostic disable-next-line: missing-fields
    local endTime = os.time({
        year = string.format('%s', os.date('%Y')),
        month = string.format('%s', os.date('%m')),
        day = os.date('%d') - diffDays,
        hour = 23,
    })
    local minutes = ((time - math.floor(time)) * 60)
    local seconds = (minutes - math.floor(minutes)) * 60
    ---@diagnostic disable-next-line: missing-fields
    local startTime = os.time({
        year = string.format('%s', os.date('%Y')),
        month = string.format('%s', os.date('%m')),
        day = os.date('%d') - diffDays,
        hour = 22 - math.floor(time),
        min = 59 - math.floor(minutes),
        sec = 60 - math.floor(seconds),
    })
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
    init({ path = obj.path })
    local years = obj.content['data'][os.date('%Y')]
    if weekday == nil then
        weekday = os.date('%A')
    end

    local week = years[os.date('%W')]
    local diffDays = weekdayNumberMap[os.date('%A')] - weekdayNumberMap[weekday]
    if diffDays < 0 then
        diffDays = diffDays + 7
    end

    if week['weekdays'][weekday] == nil then
        week['weekdays'][weekday] = {
            items = {},
        }
    end
    ---@diagnostic disable-next-line: missing-fields
    local startTime = os.time({
        year = string.format('%s', os.date('%Y')),
        month = string.format('%s', os.date('%m')),
        day = os.date('%d') - diffDays,
        hour = 23,
        min = 0,
        sec = 0,
    })
    local minutes = ((time - math.floor(time)) * 60)
    local seconds = (minutes - math.floor(minutes)) * 60
    ---@diagnostic disable-next-line: missing-fields
    local endTime = os.time({
        year = string.format('%s', os.date('%Y')),
        month = string.format('%s', os.date('%m')),
        day = os.date('%d') - diffDays,
        hour = 22 - math.floor(time),
        min = 59 - math.floor(minutes),
        sec = 60 - math.floor(seconds),
    })

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
    addTime(calculateAverage(), weekday, 'yes')
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
    addTime(time, weekday, 'yes')
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
---@param callback fun(hours:number | nil, weekday: string) the function to call
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
            if (n == nil or input == nil or input == '') then
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
    add =function ()
        select({} ,function(hours, weekday)
            addTime(hours, weekday)
        end)
    end,
    addTime = addTime,
    subtractTime = subtractTime,
    clearDay = clearDay,
    TimePause = TimePause,
    TimeResume = TimeResume,
    TimeStop = TimeStop,
    setTime = setTime,
    setIllDay = setIllDay,
    setHoliday = setIllDay,
    calculate = function()
        init({ path = obj.path })
        calculate()
        save(obj)
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
    calculate = function()
        init({ path = obj.path })
        calculate()
        save(obj)
    end,

    weekdays = weekdayNumberMap,
}
