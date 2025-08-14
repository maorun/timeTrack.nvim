local Path = require('plenary.path')
local notify = require('notify')
local config_module = require('maorun.time.config')
local utils = require('maorun.time.utils')

local M = {}

function M.init(user_config)
    config_module.config =
        vim.tbl_deep_extend('force', vim.deepcopy(config_module.defaults), user_config or {})
    if user_config and user_config.hoursPerWeekday ~= nil then
        config_module.config.hoursPerWeekday = user_config.hoursPerWeekday
    end
    config_module.obj.path = config_module.config.path
    local p = Path:new(config_module.obj.path)
    if not p:exists() then
        p:touch({ parents = true })
    end

    local data = Path:new(config_module.obj.path):read()
    if data ~= '' then
        config_module.obj.content = vim.json.decode(data)
    else
        config_module.obj.content = {}
    end
    -- Ensure hoursPerWeekday is initialized if not present (e.g. new file)
    if config_module.obj.content['hoursPerWeekday'] == nil then
        config_module.obj.content['hoursPerWeekday'] = config_module.config.hoursPerWeekday
    end
    -- Ensure paused flag is initialized
    if config_module.obj.content['paused'] == nil then
        config_module.obj.content['paused'] = false
    end

    if config_module.obj.content['data'] == nil then
        config_module.obj.content['data'] = {}
    end

    -- Ensure the basic structure for current time (if needed for some initialization logic)
    local year_str = os.date('%Y')
    local week_str = os.date('%W')
    -- Get current weekday name
    local current_wday_numeric = os.date('*t', os.time()).wday
    local weekday_name = config_module.wdayToEngName[current_wday_numeric]

    local project_name = 'default_project'
    local file_name = 'default_file'

    -- Initialize year if not exists
    if config_module.obj.content['data'][year_str] == nil then
        config_module.obj.content['data'][year_str] = {}
    end
    -- Initialize week if not exists
    if config_module.obj.content['data'][year_str][week_str] == nil then
        config_module.obj.content['data'][year_str][week_str] = {}
    end
    -- Initialize weekday if not exists
    if config_module.obj.content['data'][year_str][week_str][weekday_name] == nil then
        config_module.obj.content['data'][year_str][week_str][weekday_name] = {}
    end
    -- Initialize project if not exists
    if config_module.obj.content['data'][year_str][week_str][weekday_name][project_name] == nil then
        config_module.obj.content['data'][year_str][week_str][weekday_name][project_name] = {}
    end
    -- Initialize file with empty items and summary (previously was weekdays = {})
    if
        config_module.obj.content['data'][year_str][week_str][weekday_name][project_name][file_name]
        == nil
    then
        config_module.obj.content['data'][year_str][week_str][weekday_name][project_name][file_name] =
            {
                items = {},
                summary = {},
            }
    end
    return config_module.obj
end

function M.calculate(opts)
    opts = vim.tbl_deep_extend('keep', opts or {}, {
        year = os.date('%Y'),
        weeknumber = os.date('%W'),
    })

    local year_str = opts.year
    local week_str = opts.weeknumber

    if
        not config_module.obj.content['data'][year_str]
        or not config_module.obj.content['data'][year_str][week_str]
    then
        return
    end

    local current_week_data = config_module.obj.content['data'][year_str][week_str]

    if current_week_data.summary == nil then
        current_week_data.summary = {}
    end

    local prevWeekOverhour = 0
    -- Previous week overhour calculation (remains unchanged)
    if config_module.obj.content['data'][year_str] then
        local prev_week_number_str = string.format('%02d', tonumber(week_str) - 1)
        if config_module.obj.content['data'][year_str][prev_week_number_str] then
            local prev_week_data = config_module.obj.content['data'][year_str][prev_week_number_str]
            if prev_week_data and prev_week_data.summary and prev_week_data.summary.overhour then
                prevWeekOverhour = prev_week_data.summary.overhour
            end
        end
    end

    current_week_data.summary.overhour = prevWeekOverhour -- Initialize with previous week's overhour

    for weekday_name, weekday_data in pairs(current_week_data) do
        if weekday_name ~= 'summary' then -- Assuming 'summary' is not a valid weekday name
            -- Initialize daily summary for the weekday
            if weekday_data.summary == nil then
                weekday_data.summary = { diffInHours = 0, overhour = 0 } -- diffInHours will accumulate
            else -- Ensure it's reset/initialized correctly for recalculation
                weekday_data.summary.diffInHours = 0
                weekday_data.summary.overhour = 0
            end

            local total_hours_for_weekday = 0

            for project_name, project_data in pairs(weekday_data) do
                if project_name ~= 'summary' then -- Check project_name
                    for file_name, file_data in pairs(project_data) do
                        if file_name ~= 'summary' then -- Check file_name
                            local time_in_file = 0
                            if file_data.items then
                                for _, item_entry in pairs(file_data.items) do
                                    if item_entry.diffInHours ~= nil then
                                        time_in_file = time_in_file + item_entry.diffInHours
                                    end
                                end
                            end

                            if file_data.summary == nil then
                                file_data.summary = {}
                            end
                            file_data.summary.diffInHours = time_in_file
                            file_data.summary.overhour = nil -- Explicitly remove/nil it

                            total_hours_for_weekday = total_hours_for_weekday + time_in_file
                        end -- end if file_name ~= 'summary'
                    end -- end for file_name
                end -- end if project_name ~= 'summary'
            end -- end for project_name

            -- Now calculate the summary for the entire weekday
            weekday_data.summary.diffInHours = total_hours_for_weekday
            local expected_hours_for_weekday = config_module.obj.content['hoursPerWeekday'][weekday_name]
                or 0
            weekday_data.summary.overhour = total_hours_for_weekday - expected_hours_for_weekday

            -- Add this weekday's overhour to the total week's overhour
            current_week_data.summary.overhour = current_week_data.summary.overhour
                + weekday_data.summary.overhour
        end
    end
end

function M.TimePause()
    M.init({
        path = config_module.obj.path,
        hoursPerWeekday = config_module.obj.content['hoursPerWeekday'],
    })
    config_module.obj.content.paused = true
    utils.save()
    notify({
        'Timetracking paused',
    }, 'info', { title = 'TimeTracking - Pause' })
end

function M.TimeResume()
    M.init({
        path = config_module.obj.path,
        hoursPerWeekday = config_module.obj.content['hoursPerWeekday'],
    })
    config_module.obj.content.paused = false
    utils.save()
    notify({
        'Timetracking resumed',
    }, 'info', { title = 'TimeTracking - Resume' })
end

function M.isPaused()
    -- Ensure data is loaded before checking pause state, especially if called early.
    -- However, frequent re-init might be inefficient.
    -- Assuming init has been called once at setup.
    -- If not, this might need to call M.init or rely on it being called.
    -- Return the paused state. If not initialized, defaults to false (not paused).
    return config_module.obj.content and config_module.obj.content.paused == true
end

---@param opts? { weekday?: string|osdate, time?: number, project?: string, file?: string }
function M.TimeStart(opts)
    opts = opts or {}
    -- Similar to isPaused, ensure init has run.
    -- M.init({ path = config_module.obj.path, hoursPerWeekday = config_module.obj.content['hoursPerWeekday'] })
    if M.isPaused() then
        return
    end

    local weekday = opts.weekday
    local time = opts.time
    local project = opts.project or 'default_project'
    local file = opts.file or 'default_file'

    if weekday == nil then
        local current_wday_numeric = os.date('*t', os.time()).wday
        weekday = config_module.wdayToEngName[current_wday_numeric]
    end
    if time == nil then
        time = os.time()
    end

    local year_str = os.date('%Y', time)
    local week_str = os.date('%W', time)

    if config_module.obj.content['data'][year_str] == nil then
        config_module.obj.content['data'][year_str] = {}
    end
    if config_module.obj.content['data'][year_str][week_str] == nil then
        config_module.obj.content['data'][year_str][week_str] = {}
    end
    -- New structure: year -> week -> weekday -> project -> file
    if config_module.obj.content['data'][year_str][week_str][weekday] == nil then
        config_module.obj.content['data'][year_str][week_str][weekday] = {}
    end
    if config_module.obj.content['data'][year_str][week_str][weekday][project] == nil then
        config_module.obj.content['data'][year_str][week_str][weekday][project] = {}
    end
    if config_module.obj.content['data'][year_str][week_str][weekday][project][file] == nil then
        config_module.obj.content['data'][year_str][week_str][weekday][project][file] = {
            summary = {},
            items = {},
        }
    end

    local file_data_for_day =
        config_module.obj.content['data'][year_str][week_str][weekday][project][file]
    local canStart = true
    for _, item in pairs(file_data_for_day.items) do
        canStart = canStart and (item.startTime ~= nil and item.endTime ~= nil)
    end
    if canStart then
        local timeReadable = os.date('*t', time)
        table.insert(file_data_for_day.items, {
            startTime = time,
            startReadable = string.format('%02d:%02d', timeReadable.hour, timeReadable.min),
        })
    end
    utils.save()
end

---@param opts? { weekday?: string|osdate, time?: number, project?: string, file?: string }
function M.TimeStop(opts)
    opts = opts or {}
    -- M.init({ path = config_module.obj.path, hoursPerWeekday = config_module.obj.content['hoursPerWeekday'] })
    if M.isPaused() then
        return
    end

    local weekday = opts.weekday
    local time = opts.time
    local project = opts.project or 'default_project'
    local file = opts.file or 'default_file'

    if weekday == nil then
        local current_wday_numeric = os.date('*t', os.time()).wday
        weekday = config_module.wdayToEngName[current_wday_numeric]
    end
    if time == nil then
        time = os.time()
    end

    local year_str = os.date('%Y', time)
    local week_str = os.date('%W', time)

    -- New structure: year -> week -> weekday -> project -> file
    local file_data_path_exists = config_module.obj.content['data'][year_str]
        and config_module.obj.content['data'][year_str][week_str]
        and config_module.obj.content['data'][year_str][week_str][weekday]
        and config_module.obj.content['data'][year_str][week_str][weekday][project]
        and config_module.obj.content['data'][year_str][week_str][weekday][project][file]
        and config_module.obj.content['data'][year_str][week_str][weekday][project][file].items

    if file_data_path_exists then
        local file_data_for_day =
            config_module.obj.content['data'][year_str][week_str][weekday][project][file]
        for _, item in pairs(file_data_for_day.items) do
            if item.endTime == nil then
                item.endTime = time
                local timeReadable = os.date('*t', time)
                item.endReadable = string.format('%02d:%02d', timeReadable.hour, timeReadable.min)
                item.diffInHours = os.difftime(item.endTime, item.startTime) / 60 / 60
            end
        end
    end

    M.calculate({ year = year_str, weeknumber = week_str })
    utils.save()
end

---@param startTime number Unix timestamp for start time
---@param endTime number Unix timestamp for end time
---@param weekday string Weekday name (e.g., 'Monday')
---@param clearDay boolean|nil Whether to clear day data (deprecated, not used)
---@param project string Project name
---@param file string File name
---@param isSubtraction boolean Whether this is a time subtraction operation
function M.saveTime(startTime, endTime, weekday, clearDay, project, file, isSubtraction)
    project = project or 'default_project'
    file = file or 'default_file'
    isSubtraction = isSubtraction or false
    local year_str = os.date('%Y', startTime)
    local week_str = os.date('%W', startTime)

    if config_module.obj.content['data'][year_str] == nil then
        config_module.obj.content['data'][year_str] = {}
    end
    if config_module.obj.content['data'][year_str][week_str] == nil then
        config_module.obj.content['data'][year_str][week_str] = {}
    end
    -- New structure: year -> week -> weekday -> project -> file
    if config_module.obj.content['data'][year_str][week_str][weekday] == nil then
        config_module.obj.content['data'][year_str][week_str][weekday] = {}
    end
    if config_module.obj.content['data'][year_str][week_str][weekday][project] == nil then
        config_module.obj.content['data'][year_str][week_str][weekday][project] = {}
    end
    if config_module.obj.content['data'][year_str][week_str][weekday][project][file] == nil then
        config_module.obj.content['data'][year_str][week_str][weekday][project][file] = {
            summary = {},
            items = {},
        }
    end

    local file_data_for_day =
        config_module.obj.content['data'][year_str][week_str][weekday][project][file]
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

    table.insert(file_data_for_day.items, item)
    M.calculate({ year = year_str, weeknumber = week_str })
    utils.save()
end

---@param opts { time: number, weekday: string|osdate, clearDay?: string, project?: string, file?: string }
function M.addTime(opts)
    local clearDay_param = opts.clearDay -- Store original clearDay for potential future use, though saveTime ignores it now
    local project = opts.project or 'default_project'
    local file = opts.file or 'default_file'

    -- M.init({ path = config_module.obj.path, hoursPerWeekday = config_module.obj.content['hoursPerWeekday'] })

    local current_mocked_ts = os.time()
    local current_mocked_t_info = os.date('*t', current_mocked_ts)

    local current_day_gmt_midnight_ts = current_mocked_ts
        - (
            current_mocked_t_info.hour * 3600
            + current_mocked_t_info.min * 60
            + current_mocked_t_info.sec
        )

    local targetWeekdayName = opts.weekday
    if targetWeekdayName == nil then
        targetWeekdayName = config_module.wdayToEngName[current_mocked_t_info.wday]
    end

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
        notify(
            "Warning: Unrecognized weekday '"
                .. tostring(targetWeekdayName)
                .. "' in addTime. Defaulting to current day.",
            'warn'
        )
        target_wday_numeric_1_7 = current_wday_numeric_1_7
        targetWeekdayName = config_module.wdayToEngName[current_wday_numeric_1_7] -- Correct targetWeekdayName
    end

    local day_offset = target_wday_numeric_1_7 - current_wday_numeric_1_7
    local target_day_gmt_midnight_ts = current_day_gmt_midnight_ts + (day_offset * 24 * 3600)

    local total_seconds_duration = math.floor(opts.time * 3600)
    local add_endTime_ts = target_day_gmt_midnight_ts + (23 * 3600)
    local add_startTime_ts = add_endTime_ts - total_seconds_duration

    local paused_state = M.isPaused()
    if paused_state then
        M.TimeResume()
    end

    M.saveTime(
        add_startTime_ts,
        add_endTime_ts,
        targetWeekdayName,
        clearDay_param,
        project,
        file,
        false
    )

    if paused_state then
        M.TimePause()
    end
    return config_module.obj
end

---@param opts { time: number, weekday: string|osdate, project?: string, file?: string }
function M.subtractTime(opts)
    local project = opts.project or 'default_project'
    local file = opts.file or 'default_file'

    -- M.init({ path = config_module.obj.path, hoursPerWeekday = config_module.obj.content['hoursPerWeekday'] })

    local current_mocked_ts = os.time()
    local current_mocked_t_info = os.date('*t', current_mocked_ts)

    local current_day_gmt_midnight_ts = current_mocked_ts
        - (
            current_mocked_t_info.hour * 3600
            + current_mocked_t_info.min * 60
            + current_mocked_t_info.sec
        )

    local targetWeekdayName = opts.weekday
    if targetWeekdayName == nil then
        targetWeekdayName = config_module.wdayToEngName[current_mocked_t_info.wday]
    end

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
        notify(
            "Warning: Unrecognized weekday '"
                .. tostring(targetWeekdayName)
                .. "' in subtractTime. Defaulting to current day.",
            'warn'
        )
        target_wday_numeric_1_7 = current_wday_numeric_1_7
        targetWeekdayName = config_module.wdayToEngName[current_wday_numeric_1_7] -- Correct targetWeekdayName
    end

    local day_offset = target_wday_numeric_1_7 - current_wday_numeric_1_7
    local target_day_gmt_midnight_ts = current_day_gmt_midnight_ts + (day_offset * 24 * 3600)

    local total_seconds_duration = math.floor(opts.time * 3600)
    local sub_day_end_reference_ts = target_day_gmt_midnight_ts + (23 * 3600)
    local sub_startTime_to_save = sub_day_end_reference_ts - total_seconds_duration
    local sub_endTime_to_save = sub_day_end_reference_ts

    local paused_state = M.isPaused()
    if paused_state then
        M.TimeResume()
    end

    M.saveTime(
        sub_startTime_to_save,
        sub_endTime_to_save,
        targetWeekdayName,
        'nope',
        project,
        file,
        true
    )

    if paused_state then
        M.TimePause()
    end
    return config_module.obj
end

function M.setIllDay(weekday_param)
    M.clearDay(weekday_param)
    M.addTime({
        time = utils.calculateAverage(),
        weekday = weekday_param,
    })
    return config_module.obj
end

function M.clearDay(weekday_param)
    local project = 'default_project'
    local file = 'default_file'
    local year_str = os.date('%Y')
    local week_str = os.date('%W')

    local file_data_for_day = config_module.obj.content['data'][year_str][week_str]
    file_data_for_day[weekday_param] = {}
    file_data_for_day[weekday_param][project] = {}
    file_data_for_day[weekday_param][project][file] = {}
    file_data_for_day[weekday_param][project][file].items = {} -- Clear items by assigning an empty table
    M.calculate({ year = year_str, weeknumber = week_str })
    utils.save()
end

---@param opts { time: number, weekday: string|osdate, project?: string, file?: string }
function M.setTime(opts)
    opts = opts or {}
    local project = opts.project or 'default_project'
    local file = opts.file or 'default_file'

    M.clearDay(opts.weekday)
    M.addTime({
        time = opts.time,
        weekday = opts.weekday,
        clearDay = 'yes',
        project = project,
        file = file,
    })
end

---@param opts { year?: string, weeknumber?: string, weekday?: string, project?: string, file?: string }
---@return table List of time entries with their indices and metadata
function M.listTimeEntries(opts)
    opts = opts or {}

    local year_str = opts.year or os.date('%Y')
    local week_str = opts.weeknumber or os.date('%W')
    local weekday = opts.weekday
    local project = opts.project or 'default_project'
    local file = opts.file or 'default_file'

    local entries = {}

    -- If no specific weekday provided, get all entries for the week
    if weekday then
        local weekdays_to_check = { weekday }
        for _, wd in ipairs(weekdays_to_check) do
            local entries_for_day = M._getEntriesForDay(year_str, week_str, wd, project, file)
            for i, entry in ipairs(entries_for_day) do
                table.insert(entries, {
                    index = i,
                    year = year_str,
                    week = week_str,
                    weekday = wd,
                    project = project,
                    file = file,
                    entry = entry,
                })
            end
        end
    else
        -- Get all entries for all weekdays in the week
        local weekdays =
            { 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday' }
        for _, wd in ipairs(weekdays) do
            local entries_for_day = M._getEntriesForDay(year_str, week_str, wd, project, file)
            for i, entry in ipairs(entries_for_day) do
                table.insert(entries, {
                    index = i,
                    year = year_str,
                    week = week_str,
                    weekday = wd,
                    project = project,
                    file = file,
                    entry = entry,
                })
            end
        end
    end

    return entries
end

---@param year_str string
---@param week_str string
---@param weekday string
---@param project string
---@param file string
---@return table List of time entries for the specified day/project/file
function M._getEntriesForDay(year_str, week_str, weekday, project, file)
    if
        not config_module.obj.content['data']
        or not config_module.obj.content['data'][year_str]
        or not config_module.obj.content['data'][year_str][week_str]
        or not config_module.obj.content['data'][year_str][week_str][weekday]
        or not config_module.obj.content['data'][year_str][week_str][weekday][project]
        or not config_module.obj.content['data'][year_str][week_str][weekday][project][file]
    then
        return {}
    end

    local file_data = config_module.obj.content['data'][year_str][week_str][weekday][project][file]
    return file_data.items or {}
end

---@param opts { year: string, week: string, weekday: string, project: string, file: string, index: number, startTime?: number, endTime?: number, diffInHours?: number }
function M.editTimeEntry(opts)
    if
        not opts.year
        or not opts.week
        or not opts.weekday
        or not opts.project
        or not opts.file
        or not opts.index
    then
        error('editTimeEntry requires year, week, weekday, project, file, and index parameters')
    end

    -- Access the data directly to modify it
    if
        not config_module.obj.content['data']
        or not config_module.obj.content['data'][opts.year]
        or not config_module.obj.content['data'][opts.year][opts.week]
        or not config_module.obj.content['data'][opts.year][opts.week][opts.weekday]
        or not config_module.obj.content['data'][opts.year][opts.week][opts.weekday][opts.project]
        or not config_module.obj.content['data'][opts.year][opts.week][opts.weekday][opts.project][opts.file]
    then
        error('No entries found for the specified day/project/file')
    end

    local file_data =
        config_module.obj.content['data'][opts.year][opts.week][opts.weekday][opts.project][opts.file]
    if not file_data.items or opts.index < 1 or opts.index > #file_data.items then
        error('Invalid entry index: ' .. opts.index)
    end

    local entry = file_data.items[opts.index]

    -- Update startTime if provided
    if opts.startTime then
        entry.startTime = opts.startTime
        local timeReadableStart = os.date('*t', opts.startTime)
        entry.startReadable =
            string.format('%02d:%02d', timeReadableStart.hour, timeReadableStart.min)
    end

    -- Update endTime if provided
    if opts.endTime then
        entry.endTime = opts.endTime
        local timeReadableEnd = os.date('*t', opts.endTime)
        entry.endReadable = string.format('%02d:%02d', timeReadableEnd.hour, timeReadableEnd.min)
    end

    -- Recalculate diffInHours if we have both start and end times, unless diffInHours was explicitly provided
    if opts.diffInHours then
        -- Allow manual setting of diffInHours (useful for corrections)
        entry.diffInHours = opts.diffInHours
    elseif entry.startTime and entry.endTime then
        entry.diffInHours = os.difftime(entry.endTime, entry.startTime) / 60 / 60
    end

    -- Recalculate summaries and save
    M.calculate({ year = opts.year, weeknumber = opts.week })
    utils.save()
end

---@param opts { year: string, week: string, weekday: string, project: string, file: string, index: number }
function M.deleteTimeEntry(opts)
    if
        not opts.year
        or not opts.week
        or not opts.weekday
        or not opts.project
        or not opts.file
        or not opts.index
    then
        error('deleteTimeEntry requires year, week, weekday, project, file, and index parameters')
    end

    if
        not config_module.obj.content['data']
        or not config_module.obj.content['data'][opts.year]
        or not config_module.obj.content['data'][opts.year][opts.week]
        or not config_module.obj.content['data'][opts.year][opts.week][opts.weekday]
        or not config_module.obj.content['data'][opts.year][opts.week][opts.weekday][opts.project]
        or not config_module.obj.content['data'][opts.year][opts.week][opts.weekday][opts.project][opts.file]
    then
        error('No entries found for the specified day/project/file')
    end

    local file_data =
        config_module.obj.content['data'][opts.year][opts.week][opts.weekday][opts.project][opts.file]
    if not file_data.items or opts.index < 1 or opts.index > #file_data.items then
        error('Invalid entry index: ' .. opts.index)
    end

    -- Remove the entry at the specified index
    table.remove(file_data.items, opts.index)

    -- Recalculate summaries and save
    M.calculate({ year = opts.year, weeknumber = opts.week })
    utils.save()
end

---@param opts { startTime: number, endTime: number, weekday?: string, project?: string, file?: string }
function M.addManualTimeEntry(opts)
    if not opts.startTime or not opts.endTime then
        error('addManualTimeEntry requires startTime and endTime parameters')
    end

    if opts.startTime >= opts.endTime then
        error('startTime must be before endTime')
    end

    local weekday = opts.weekday
    local project = opts.project or 'default_project'
    local file = opts.file or 'default_file'

    if weekday == nil then
        local current_wday_numeric = os.date('*t', opts.startTime).wday
        weekday = config_module.wdayToEngName[current_wday_numeric]
    end

    -- Call saveTime with explicit parameters for manual entries
    -- clearDay parameter is not needed for manual entries, so we pass false instead of nil
    M.saveTime(opts.startTime, opts.endTime, weekday, false, project, file, false)
end

function M.get_config()
    return config_module.obj
end

-- Export time tracking data in CSV or Markdown format
function M.exportTimeData(opts)
    opts = vim.tbl_deep_extend('keep', opts or {}, {
        format = 'csv', -- 'csv' or 'markdown'
        range = 'week', -- 'week' or 'month'
        year = os.date('%Y'),
        week = os.date('%W'), -- For week range
        month = os.date('%m'), -- For month range (1-12)
    })

    local format = string.lower(opts.format)
    local range = string.lower(opts.range)

    if format ~= 'csv' and format ~= 'markdown' then
        error('Invalid format. Supported formats: csv, markdown')
    end

    if range ~= 'week' and range ~= 'month' then
        error('Invalid range. Supported ranges: week, month')
    end

    local year_str = tostring(opts.year)
    local data = config_module.obj.content.data

    if not data or not data[year_str] then
        return format == 'csv'
                and 'Date,Weekday,Project,File,Start Time,End Time,Duration (Hours)\n'
            or '# No Data Available\n\nNo time tracking data found for the specified period.\n'
    end

    local entries = {}

    if range == 'week' then
        local week_str = string.format('%02d', tonumber(opts.week))
        if data[year_str][week_str] then
            local week_data = data[year_str][week_str]
            for weekday, weekday_data in pairs(week_data) do
                if weekday ~= 'summary' then
                    M._extractEntriesFromWeekday(entries, weekday_data, weekday, year_str, week_str)
                end
            end
        end
    else -- month
        local month_num = tonumber(opts.month)
        for week_str, week_data in pairs(data[year_str]) do
            if tonumber(week_str) then -- Skip non-numeric keys like summary
                for weekday, weekday_data in pairs(week_data) do
                    if weekday ~= 'summary' then
                        -- Extract entries for this weekday but filter by month
                        M._extractEntriesFromWeekdayByMonth(
                            entries,
                            weekday_data,
                            weekday,
                            year_str,
                            week_str,
                            month_num
                        )
                    end
                end
            end
        end
    end

    -- Sort entries by date/time
    table.sort(entries, function(a, b)
        return a.startTime < b.startTime
    end)

    if format == 'csv' then
        return M._formatAsCSV(entries)
    else
        return M._formatAsMarkdown(entries, opts)
    end
end

-- Helper function to extract entries from a weekday's data
function M._extractEntriesFromWeekday(entries, weekday_data, weekday, year_str, week_str)
    for project, project_data in pairs(weekday_data) do
        if type(project_data) == 'table' then
            for file, file_data in pairs(project_data) do
                if type(file_data) == 'table' and file_data.items then
                    for _, item in ipairs(file_data.items) do
                        table.insert(entries, {
                            date = item.startTime and os.date('%Y-%m-%d', item.startTime) or 'N/A',
                            weekday = weekday,
                            project = project,
                            file = file,
                            startTime = item.startTime or 0,
                            startReadable = item.startReadable or 'N/A',
                            endReadable = item.endReadable or 'N/A',
                            diffInHours = item.diffInHours or 0,
                        })
                    end
                end
            end
        end
    end
end

-- Helper function to extract entries from a weekday's data filtered by month
function M._extractEntriesFromWeekdayByMonth(
    entries,
    weekday_data,
    weekday,
    year_str,
    week_str,
    target_month
)
    for project, project_data in pairs(weekday_data) do
        if type(project_data) == 'table' then
            for file, file_data in pairs(project_data) do
                if type(file_data) == 'table' and file_data.items then
                    for _, item in ipairs(file_data.items) do
                        if item.startTime then
                            local item_month = tonumber(os.date('%m', item.startTime))
                            if item_month == target_month then
                                table.insert(entries, {
                                    date = item.startTime and os.date('%Y-%m-%d', item.startTime)
                                        or 'N/A',
                                    weekday = weekday,
                                    project = project,
                                    file = file,
                                    startTime = item.startTime or 0,
                                    startReadable = item.startReadable or 'N/A',
                                    endReadable = item.endReadable or 'N/A',
                                    diffInHours = item.diffInHours or 0,
                                })
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Escape a field for CSV format
local function escapeCSVField(field)
    -- Convert to string if not already
    local str = tostring(field)

    -- Check if the field contains comma, quote, or newline
    if str:find('[,"\n\r]') then
        -- Escape internal quotes by doubling them
        str = str:gsub('"', '""')
        -- Wrap the field in quotes
        return '"' .. str .. '"'
    end

    return str
end

-- Format entries as CSV
function M._formatAsCSV(entries)
    local lines = { 'Date,Weekday,Project,File,Start Time,End Time,Duration (Hours)' }

    for _, entry in ipairs(entries) do
        local line = string.format(
            '%s,%s,%s,%s,%s,%s,%s',
            escapeCSVField(entry.date),
            escapeCSVField(entry.weekday),
            escapeCSVField(entry.project),
            escapeCSVField(entry.file),
            escapeCSVField(entry.startReadable),
            escapeCSVField(entry.endReadable),
            escapeCSVField(string.format('%.2f', entry.diffInHours))
        )
        table.insert(lines, line)
    end

    return table.concat(lines, '\n') .. '\n'
end

-- Format entries as Markdown
function M._formatAsMarkdown(entries, opts)
    local lines = {}

    -- Title
    local title = string.format(
        '# Time Tracking Export - %s %s',
        opts.range == 'week' and 'Week' or 'Month',
        opts.range == 'week' and opts.week or opts.month
    )
    table.insert(lines, title)
    table.insert(lines, '')

    if #entries == 0 then
        table.insert(lines, 'No time tracking data found for the specified period.')
        return table.concat(lines, '\n') .. '\n'
    end

    -- Summary statistics
    local total_hours = 0
    local projects = {}
    for _, entry in ipairs(entries) do
        total_hours = total_hours + entry.diffInHours
        projects[entry.project] = (projects[entry.project] or 0) + entry.diffInHours
    end

    table.insert(lines, '## Summary')
    table.insert(lines, '')
    table.insert(lines, string.format('**Total Time:** %.2f hours', total_hours))
    table.insert(lines, '')
    table.insert(lines, '**Time by Project:**')
    for project, hours in pairs(projects) do
        table.insert(lines, string.format('- %s: %.2f hours', project, hours))
    end
    table.insert(lines, '')

    -- Detailed entries table
    table.insert(lines, '## Detailed Entries')
    table.insert(lines, '')
    table.insert(lines, '| Date | Weekday | Project | File | Start | End | Duration |')
    table.insert(lines, '|------|---------|---------|------|-------|-----|----------|')

    for _, entry in ipairs(entries) do
        local row = string.format(
            '| %s | %s | %s | %s | %s | %s | %.2f h |',
            entry.date,
            entry.weekday,
            entry.project,
            entry.file,
            entry.startReadable,
            entry.endReadable,
            entry.diffInHours
        )
        table.insert(lines, row)
    end

    return table.concat(lines, '\n') .. '\n'
end

return M
