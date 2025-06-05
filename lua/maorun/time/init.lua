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
    -- Ensure hoursPerWeekday is initialized if not present (e.g. new file)
    if obj.content['hoursPerWeekday'] == nil then
        obj.content['hoursPerWeekday'] = config.hoursPerWeekday
    end

    if obj.content['data'] == nil then
        obj.content['data'] = {}
    end

    local year_str = os.date('%Y')
    local week_str = os.date('%W')
    local project_name = 'default_project' -- Hardcoded for now
    local file_name = 'default_file' -- Hardcoded for now

    if obj.content['data'][year_str] == nil then
        obj.content['data'][year_str] = {}
    end
    if obj.content['data'][year_str][week_str] == nil then
        obj.content['data'][year_str][week_str] = {}
    end
    if obj.content['data'][year_str][week_str][project_name] == nil then
        obj.content['data'][year_str][week_str][project_name] = {}
    end
    if obj.content['data'][year_str][week_str][project_name][file_name] == nil then
        obj.content['data'][year_str][week_str][project_name][file_name] = {
            weekdays = {}, -- Will store weekday -> {summary={}, items={...}}
            -- The weekly summary (overhour) is not initialized here,
            -- it will be handled by the calculate function.
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

    local year_str = opts.year
    local week_str = opts.weeknumber

    if not obj.content['data'][year_str] or not obj.content['data'][year_str][week_str] then
        -- No data for this year/week, nothing to calculate
        return
    end

    local current_week_data = obj.content['data'][year_str][week_str]

    -- Initialize week summary if it doesn't exist under current_week_data.summary
    if current_week_data.summary == nil then
        current_week_data.summary = {}
    end

    local prevWeekOverhour = 0
    -- Ensure year_str data exists before trying to access previous week
    if obj.content['data'][year_str] then
        local prev_week_number_str = string.format('%02d', tonumber(week_str) - 1)
        if obj.content['data'][year_str][prev_week_number_str] then
            local prev_week_data = obj.content['data'][year_str][prev_week_number_str]
            if prev_week_data and prev_week_data.summary and prev_week_data.summary.overhour then
                prevWeekOverhour = prev_week_data.summary.overhour
            end
        end
    end

    current_week_data.summary.overhour = prevWeekOverhour -- Initialize with previous week's carry-over
    -- local total_time_in_week = 0 -- Can be used if we want to store total logged time for the week explicitly

    -- Iterate over projects in the current week
    for project_name, project_data in pairs(current_week_data) do
        if project_name ~= 'summary' then -- Skip the summary table itself
            -- Iterate over files in the current project
            for file_name, file_data in pairs(project_data) do
                if file_data.weekdays then
                    -- Iterate over weekdays in the current file
                    for weekday_name, day_data in pairs(file_data.weekdays) do
                        local time_in_weekday = 0
                        if day_data.items then
                            for _, item_entry in pairs(day_data.items) do
                                if item_entry.diffInHours ~= nil then
                                    time_in_weekday = time_in_weekday + item_entry.diffInHours
                                end
                            end
                        end

                        -- Update summary for this specific day under project -> file -> weekday
                        if day_data.summary == nil then
                            day_data.summary = {}
                        end
                        day_data.summary.diffInHours = time_in_weekday

                        local expected_hours = obj.content['hoursPerWeekday'][weekday_name] or 0
                        day_data.summary.overhour = time_in_weekday - expected_hours

                        -- Accumulate this day's overhour to the overall week summary
                        current_week_data.summary.overhour = current_week_data.summary.overhour
                            + day_data.summary.overhour
                        -- total_time_in_week = total_time_in_week + time_in_weekday -- Accumulate total logged time
                    end
                end
            end
        end
    end
    -- If you want to store the total logged time for the week in the summary:
    -- current_week_data.summary.totalLoggedTime = total_time_in_week
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

---@param opts? { weekday?: string|osdate, time?: number, project?: string, file?: string }
local function TimeStart(opts)
    opts = opts or {}
    init({ path = obj.path, hoursPerWeekday = obj.content['hoursPerWeekday'] })
    if isPaused() then
        return
    end

    local weekday = opts.weekday
    local time = opts.time
    local project = opts.project or 'default_project'
    local file = opts.file or 'default_file'

    if weekday == nil then
        local current_wday_numeric = os.date('*t', os.time()).wday
        weekday = wdayToEngName[current_wday_numeric]
    end
    if time == nil then
        time = os.time()
    end

    local year_str = os.date('%Y', time) -- Use time for year_str for consistency if time is provided
    local week_str = os.date('%W', time) -- Use time for week_str for consistency

    -- Ensure path exists (init might have only created for current os.date)
    if obj.content['data'][year_str] == nil then
        obj.content['data'][year_str] = {}
    end
    if obj.content['data'][year_str][week_str] == nil then
        obj.content['data'][year_str][week_str] = {}
    end
    if obj.content['data'][year_str][week_str][project] == nil then
        obj.content['data'][year_str][week_str][project] = {}
    end
    if obj.content['data'][year_str][week_str][project][file] == nil then
        obj.content['data'][year_str][week_str][project][file] = { weekdays = {} }
    end
    if obj.content['data'][year_str][week_str][project][file]['weekdays'][weekday] == nil then
        obj.content['data'][year_str][week_str][project][file]['weekdays'][weekday] = {
            summary = {},
            items = {},
        }
    end

    local dayItem = obj.content['data'][year_str][week_str][project][file]['weekdays'][weekday]
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

---@param opts? { weekday?: string|osdate, time?: number, project?: string, file?: string }
local function TimeStop(opts)
    opts = opts or {}
    init({ path = obj.path, hoursPerWeekday = obj.content['hoursPerWeekday'] })
    if isPaused() then
        return
    end

    local weekday = opts.weekday
    local time = opts.time
    local project = opts.project or 'default_project'
    local file = opts.file or 'default_file'

    if weekday == nil then
        local current_wday_numeric = os.date('*t', os.time()).wday
        weekday = wdayToEngName[current_wday_numeric]
    end
    if time == nil then
        time = os.time()
    end

    local year_str = os.date('%Y', time)
    local week_str = os.date('%W', time)

    -- Check if the path to the day's items exists in the new structure
    local dayItem_path_exists = obj.content['data'][year_str]
        and obj.content['data'][year_str][week_str]
        and obj.content['data'][year_str][week_str][project]
        and obj.content['data'][year_str][week_str][project][file]
        and obj.content['data'][year_str][week_str][project][file]['weekdays']
        and obj.content['data'][year_str][week_str][project][file]['weekdays'][weekday]
        and obj.content['data'][year_str][week_str][project][file]['weekdays'][weekday].items

    if dayItem_path_exists then
        local dayItem = obj.content['data'][year_str][week_str][project][file]['weekdays'][weekday]
        for _, item in pairs(dayItem.items) do
            if item.endTime == nil then
                item.endTime = time
                local timeReadable = os.date('*t', time)
                item.endReadable = string.format('%02d:%02d', timeReadable.hour, timeReadable.min)
                item.diffInHours = os.difftime(item.endTime, item.startTime) / 60 / 60
            end
        end
    end

    calculate({ year = year_str, weeknumber = week_str }) -- Calculate regardless of whether items were stopped, to update summaries.
    save(obj)

    local heute_text = 'N/A'
    if dayItem_path_exists then
        -- Accessing dayItem here is safe because dayItem_path_exists is true
        local dayItem = obj.content['data'][year_str][week_str][project][file]['weekdays'][weekday]
        if dayItem.summary and dayItem.summary.overhour then
            heute_text = string.format('%.2f', dayItem.summary.overhour)
        end
    end

    local gesamt_text = 'N/A'
    -- Check path for overall week summary - this might be inaccurate until 'calculate' is updated
    if
        obj.content['data'][year_str]
        and obj.content['data'][year_str][week_str]
        and obj.content['data'][year_str][week_str].summary -- This summary is at week level
        and obj.content['data'][year_str][week_str].summary.overhour
    then
        gesamt_text =
            string.format('%.2f', obj.content['data'][year_str][week_str].summary.overhour)
    end

    notify({
        'Heute: ' .. heute_text .. ' Stunden',
        'Gesamt: ' .. gesamt_text .. ' Stunden',
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

local function saveTime(startTime, endTime, weekday, clearDay, project, file, isSubtraction)
    project = project or 'default_project'
    file = file or 'default_file'
    isSubtraction = isSubtraction or false -- Default to false if not provided
    local year_str = os.date('%Y', startTime) -- Use startTime to determine year/week
    local week_str = os.date('%W', startTime)

    -- Ensure path exists
    if obj.content['data'][year_str] == nil then
        obj.content['data'][year_str] = {}
    end
    if obj.content['data'][year_str][week_str] == nil then
        obj.content['data'][year_str][week_str] = {}
    end
    if obj.content['data'][year_str][week_str][project] == nil then
        obj.content['data'][year_str][week_str][project] = {}
    end
    if obj.content['data'][year_str][week_str][project][file] == nil then
        obj.content['data'][year_str][week_str][project][file] = { weekdays = {} }
    end
    if obj.content['data'][year_str][week_str][project][file]['weekdays'][weekday] == nil then
        obj.content['data'][year_str][week_str][project][file]['weekdays'][weekday] = {
            summary = {},
            items = {},
        }
    end

    -- Handle clearDay logic - if true, existing items for the day are cleared.
    -- The original saveTime had a complex `clearDay` check in the first 'if'.
    -- Assuming if clearDay is passed as non-nil (and not 'nope'), it means we should clear.
    -- The addTime function passes clearDay as 'yes' or nil. 'nope' was for subtractTime.
    -- For simplicity here, if clearDay is true (boolean), we clear.
    -- The addTime/setTime logic will need to ensure clearDay is passed appropriately.
    -- The original logic for clearDay was: `if clearDay == nil and ... == nil then init day`.
    -- This seems more about init than clearing. The actual clearing is done by `clearDay()` func.
    -- Let's stick to the new structure path first. The `clearDay` param in `saveTime` might be redundant
    -- if `clearDay()` function is used before `addTime` in `setTime`.
    -- For now, `clearDay` in `saveTime` doesn't actively clear, it's more for path init.

    local dayItem = obj.content['data'][year_str][week_str][project][file]['weekdays'][weekday]
    local timeReadableStart = os.date('*t', startTime)
    local item = {
        startTime = startTime,
        startReadable = string.format('%02d:%02d', timeReadableStart.hour, timeReadableStart.min),
        endTime = endTime,
    }
    local timeReadableEnd = os.date('*t', endTime)
    item.endReadable = string.format('%02d:%02d', timeReadableEnd.hour, timeReadableEnd.min)

    item.diffInHours = os.difftime(item.endTime, item.startTime) / 60 / 60
    if isSubtraction then
        item.diffInHours = -item.diffInHours
    end

    table.insert(dayItem.items, item)
    calculate({ year = year_str, weeknumber = week_str })
    save(obj)

    notify({
        'Heute: ' .. string.format('%.2f', dayItem.summary.overhour) .. ' Stunden',
        'Gesamt: '
            .. string.format('%.2f', obj.content['data'][year_str][week_str].summary.overhour)
            .. ' Stunden',
    }, 'info', { title = 'TimeTracking - SaveTime' }) -- Changed title for clarity
end

-- adds time into the current week
---@param opts { time: number, weekday: string|osdate, clearDay?: string, project?: string, file?: string }
local function addTime(opts)
    local time = opts.time
    local weekday = opts.weekday
    local clearDay = opts.clearDay -- This is 'yes' or nil from setTime/setIllDay, or 'nope'
    local project = opts.project or 'default_project'
    local file = opts.file or 'default_file'

    -- The original clearDay logic: if nil, it's 'nope'; if 'yes', it's nil for saveTime's old check.
    -- This is confusing. Let's simplify: `clearDay` in `addTime` means "should the day be cleared before adding".
    -- `setTime` calls `clearDay()` then `addTime()`. So `addTime` itself doesn't need to handle clearing.
    -- The `clearDay` parameter passed to `saveTime` from here will be the original `opts.clearDay` value.
    -- saveTime's responsibility is just to save, path creation is fine.

    init({ path = obj.path, hoursPerWeekday = obj.content['hoursPerWeekday'] })

    local current_mocked_ts = os.time() -- This will be GMT if tests mock os.time correctly
    local current_mocked_t_info = os.date('*t', current_mocked_ts) -- GMT components

    -- Calculate GMT midnight for the current mocked day
    local current_day_gmt_midnight_ts = current_mocked_ts
        - (
            current_mocked_t_info.hour * 3600
            + current_mocked_t_info.min * 60
            + current_mocked_t_info.sec
        )

    local targetWeekdayName = opts.weekday
    if targetWeekdayName == nil then
        targetWeekdayName = wdayToEngName[current_mocked_t_info.wday]
    end

    -- Determine Target Weekday and its GMT Midnight
    -- Note: os.date('*t').wday is 1 for Sunday, ..., 7 for Saturday
    local weekday_name_to_num_1_7 = {
        Sunday = 1,
        Monday = 2,
        Tuesday = 3,
        Wednesday = 4,
        Thursday = 5,
        Friday = 6,
        Saturday = 7,
    }
    local current_wday_numeric_1_7 = current_mocked_t_info.wday
    local target_wday_numeric_1_7 = weekday_name_to_num_1_7[targetWeekdayName]

    if target_wday_numeric_1_7 == nil then
        -- Fallback for unrecognized weekday string, though ideally should not happen
        -- if opts.weekday is validated or comes from wdayToEngName
        notify(
            "Warning: Unrecognized weekday '"
                .. tostring(targetWeekdayName)
                .. "' in addTime. Defaulting to current day.",
            'warn'
        )
        target_wday_numeric_1_7 = current_wday_numeric_1_7
    end

    local day_offset = target_wday_numeric_1_7 - current_wday_numeric_1_7
    local target_day_gmt_midnight_ts = current_day_gmt_midnight_ts + (day_offset * 24 * 3600)

    -- Calculate duration in total seconds
    local total_seconds_duration = math.floor(opts.time * 3600)

    -- Calculate startTime_ts and endTime_ts using GMT arithmetic
    local add_endTime_ts = target_day_gmt_midnight_ts + (23 * 3600) -- 23:00:00 GMT on target day
    local add_startTime_ts = add_endTime_ts - total_seconds_duration

    local startTime = add_startTime_ts
    local endTime = add_endTime_ts

    local paused = isPaused()
    if paused then
        TimeResume()
    end

    -- Pass project and file to saveTime
    saveTime(startTime, endTime, targetWeekdayName, clearDay, project, file, false)

    if paused then
        TimePause()
    end
    return obj
end

-- subtracts time from the current week
---@param opts { time: number, weekday: string|osdate, project?: string, file?: string }
local function subtractTime(opts)
    local time = opts.time
    local weekday = opts.weekday
    local project = opts.project or 'default_project'
    local file = opts.file or 'default_file'

    init({ path = obj.path, hoursPerWeekday = obj.content['hoursPerWeekday'] })

    local current_mocked_ts = os.time() -- This will be GMT if tests mock os.time correctly
    local current_mocked_t_info = os.date('*t', current_mocked_ts) -- GMT components

    -- Calculate GMT midnight for the current mocked day
    local current_day_gmt_midnight_ts = current_mocked_ts
        - (
            current_mocked_t_info.hour * 3600
            + current_mocked_t_info.min * 60
            + current_mocked_t_info.sec
        )

    local targetWeekdayName = opts.weekday
    if targetWeekdayName == nil then
        targetWeekdayName = wdayToEngName[current_mocked_t_info.wday]
    end

    -- Determine Target Weekday and its GMT Midnight
    -- Note: os.date('*t').wday is 1 for Sunday, ..., 7 for Saturday
    local weekday_name_to_num_1_7 = {
        Sunday = 1,
        Monday = 2,
        Tuesday = 3,
        Wednesday = 4,
        Thursday = 5,
        Friday = 6,
        Saturday = 7,
    }
    local current_wday_numeric_1_7 = current_mocked_t_info.wday
    local target_wday_numeric_1_7 = weekday_name_to_num_1_7[targetWeekdayName]

    if target_wday_numeric_1_7 == nil then
        -- Fallback for unrecognized weekday string
        notify(
            "Warning: Unrecognized weekday '"
                .. tostring(targetWeekdayName)
                .. "' in subtractTime. Defaulting to current day.",
            'warn'
        )
        target_wday_numeric_1_7 = current_wday_numeric_1_7
    end

    local day_offset = target_wday_numeric_1_7 - current_wday_numeric_1_7
    local target_day_gmt_midnight_ts = current_day_gmt_midnight_ts + (day_offset * 24 * 3600)

    -- Calculate duration in total seconds
    local total_seconds_duration = math.floor(opts.time * 3600)

    -- Calculate startTime_to_save and endTime_to_save using GMT arithmetic
    local sub_day_end_reference_ts = target_day_gmt_midnight_ts + (23 * 3600) -- 23:00:00 GMT on target day
    local sub_startTime_to_save = sub_day_end_reference_ts - total_seconds_duration
    local sub_endTime_to_save = sub_day_end_reference_ts

    local startTime = sub_startTime_to_save
    local endTime = sub_endTime_to_save

    local paused = isPaused()
    if paused then
        TimeResume()
    end

    -- Pass project, file. 'nope' for clearDay indicates not to clear.
    saveTime(startTime, endTime, targetWeekdayName, 'nope', project, file, true)

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

local function clearDay(weekday, project, file)
    project = project or 'default_project'
    file = file or 'default_file'
    local year_str = os.date('%Y')
    local week_str = os.date('%W')

    if
        obj.content['data'][year_str]
        and obj.content['data'][year_str][week_str]
        and obj.content['data'][year_str][week_str][project]
        and obj.content['data'][year_str][week_str][project][file]
        and obj.content['data'][year_str][week_str][project][file]['weekdays']
        and obj.content['data'][year_str][week_str][project][file]['weekdays'][weekday]
    then
        local dayItems =
            obj.content['data'][year_str][week_str][project][file]['weekdays'][weekday].items
        if dayItems then
            for key, _ in pairs(dayItems) do
                dayItems[key] = nil
            end
        end
    end
    calculate({ year = year_str, weeknumber = week_str }) -- Recalculate for the current/affected week
    save(obj)
end

---@param opts { time: number, weekday: string|osdate, project?: string, file?: string }
local function setTime(opts)
    opts = opts or {}
    local project = opts.project or 'default_project'
    local file = opts.file or 'default_file'

    clearDay(opts.weekday, project, file) -- Pass project and file to clearDay
    addTime({
        time = opts.time,
        weekday = opts.weekday,
        clearDay = 'yes', -- 'yes' indicates to saveTime that items might have been cleared
        project = project,
        file = file,
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

---@param opts { hours?: boolean, weekday?: boolean, project?: boolean, file?: boolean }
---@param callback fun(hours:number, weekday: string, project:string, file:string) the function to call
local function select(opts, callback)
    opts = vim.tbl_deep_extend('force', { -- Use 'force' to ensure defaults are applied
        hours = true,
        weekday = true,
        project = true,
        file = true,
    }, opts or {})

    local selected_project = 'default_project'
    local selected_file = 'default_file'

    local function get_file_input()
        if opts.file then
            vim.ui.input({ prompt = 'File name? (default: default_file) ' }, function(input)
                selected_file = (input and input ~= '') and input or 'default_file'
                get_weekday_selection() -- Proceed to weekday selection
            end)
        else
            get_weekday_selection() -- Skip file input
        end
    end

    local function get_project_input()
        if opts.project then
            vim.ui.input({ prompt = 'Project name? (default: default_project) ' }, function(input)
                selected_project = (input and input ~= '') and input or 'default_project'
                get_file_input() -- Proceed to file input
            end)
        else
            get_file_input() -- Skip project input
        end
    end

    local selections = {}
    local selectionNumbers = {}
    for _, value in pairs(weekdayNumberMap) do
        if not selectionNumbers[value] then
            selectionNumbers[value] = 1
            selections[#selections + 1] = _
        end
    end

    ---@param weekday string
    local function selectHours(weekday_param)
        if opts.hours then
            vim.ui.input({
                prompt = 'How many hours? ',
            }, function(input)
                local n = tonumber(input)
                if n == nil or input == nil or input == '' then
                    return
                end
                callback(n, weekday_param, selected_project, selected_file)
            end)
        else
            -- If hours are not required, pass a default or handle appropriately
            callback(0, weekday_param, selected_project, selected_file) -- Assuming 0 hours if not prompted
        end
    end

    local function get_weekday_selection()
        if opts.weekday then
            if pcall(require, 'telescope') then
                local telescopeSelect = require('maorun.time.weekday_select')
                telescopeSelect({
                    prompt_title = 'Which day?',
                    list = selections,
                    action = function(selected_weekday)
                        selectHours(selected_weekday)
                    end,
                })
            else
                vim.ui.select(selections, {
                    prompt = 'Which day? ',
                }, function(selected_weekday)
                    selectHours(selected_weekday)
                end)
            end
        else
            -- If weekday is not required, pass a default or handle appropriately
            -- This case might need clarification: what weekday to use if not selected?
            -- For now, assuming it means no time entry if weekday selection is skipped.
            -- Or, pass a default like current day, but callback expects a weekday.
            -- Let's assume callback is only made if weekday is selected.
            -- If opts.weekday is false, the chain stops or uses a predefined weekday.
            -- For now, if weekday is false, we directly call callback with defaults (e.g. for project/file only ops)
            -- callback(0, nil, selected_project, selected_file) -- This line is problematic if weekday is essential
            -- Safest is to ensure weekday selection happens if callback needs it.
            -- The current design implies `select` is primarily for operations that involve weekday and hours.
            -- If only project/file are needed for some future op, `select` might need more changes.
            -- Given the context of addTime, substractTime, setTime, weekday and hours are essential.
        end
    end

    -- Start the chain of inputs
    get_project_input()
end

Time = {
    add = function()
        select(
            {},
            function(hours, weekday, project, file) -- Add project and file to callback params
                addTime({ time = hours, weekday = weekday, project = project, file = file })
            end
        )
    end,
    addTime = addTime,
    subtract = function()
        select({}, function(hours, weekday, project, file) -- Add project and file
            subtractTime({ time = hours, weekday = weekday, project = project, file = file })
        end)
    end,
    subtractTime = subtractTime,
    clearDay = clearDay, -- clearDay now takes project and file, but this public Time.clearDay would need them.
    -- This might require another vim.ui.select or direct args. For now, it's an issue.
    -- TODO: Adjust public Time.clearDay or make it internal / part of setTime only.
    TimePause = TimePause,
    TimeResume = TimeResume,
    TimeStop = TimeStop,
    set = function()
        select({}, function(hours, weekday, project, file) -- Add project and file
            setTime({ time = hours, weekday = weekday, project = project, file = file })
        end)
    end,
    setTime = setTime,
    setIllDay = setIllDay,
    setHoliday = setIllDay,
    calculate = function(opts) -- Accept opts
        init({ path = obj.path, hoursPerWeekday = obj.content['hoursPerWeekday'] })
        calculate(opts)
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
        calculate(opts)
        save(obj)
        return obj
    end,

    weekdays = weekdayNumberMap,
}
