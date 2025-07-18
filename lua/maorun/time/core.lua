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
    local current_wday_numeric = os.date('*t', os.time()).wday -- No longer needed here
    local weekday_name = config_module.wdayToEngName[current_wday_numeric] -- No longer needed here

    local project_name = 'default_project' -- No longer needed here
    local file_name = 'default_file' -- No longer needed here

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

function M.saveTime(startTime, endTime, weekday, _clearDay, project, file, isSubtraction) -- _clearDay param might be unused now
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

function M.get_config()
    return config_module.obj
end

return M
