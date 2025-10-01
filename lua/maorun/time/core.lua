local Path = require('plenary.path')
local notify = require('notify')
local config_module = require('maorun.time.config')
local utils = require('maorun.time.utils')

local M = {}

-- State tracking for notifications to prevent spam
local notification_state = {
    dailyGoal = {
        lastNotification = {}, -- key: "YYYY-WW-Weekday", value: timestamp
        lastRecurringNotification = {}, -- key: "YYYY-WW-Weekday", value: timestamp
    },
    coreHours = {
        lastNotification = {}, -- key: "core-hours-YYYY-WW-Weekday", value: timestamp
    },
}

---Load notification state from persistent storage
local function loadNotificationState()
    if config_module.obj.content and config_module.obj.content.notificationState then
        notification_state = vim.tbl_deep_extend(
            'force',
            notification_state,
            config_module.obj.content.notificationState
        )
    end
end

---Save notification state to persistent storage
local function saveNotificationState()
    if config_module.obj.content then
        config_module.obj.content.notificationState = notification_state
        utils.save()
    end
end

---Validate configuration options to prevent issues
---@param config table The configuration to validate
function M._validateConfig(config)
    if config.notifications and config.notifications.dailyGoal then
        local dailyGoal = config.notifications.dailyGoal

        -- Validate recurringMinutes is a positive number with reasonable minimum
        if dailyGoal.recurringMinutes ~= nil then
            if type(dailyGoal.recurringMinutes) ~= 'number' or dailyGoal.recurringMinutes < 1 then
                vim.notify(
                    'Warning: recurringMinutes must be >= 1. Setting to default value of 30.',
                    vim.log.levels.WARN,
                    { title = 'TimeTracking - Config' }
                )
                dailyGoal.recurringMinutes = 30
            end
        end
    end
end

---Clean up old notification state entries to prevent memory leaks
---@param max_age_days number Maximum age in days for entries to keep (default: 30)
function M._cleanupNotificationState(max_age_days)
    max_age_days = max_age_days or 30
    local current_time = os.time()
    local max_age_seconds = max_age_days * 24 * 60 * 60

    -- Clean up daily goal notification entries
    for state_key, timestamp in pairs(notification_state.dailyGoal.lastNotification) do
        if current_time - timestamp > max_age_seconds then
            notification_state.dailyGoal.lastNotification[state_key] = nil
        end
    end

    -- Clean up daily goal recurring notification entries
    for state_key, timestamp in pairs(notification_state.dailyGoal.lastRecurringNotification) do
        if current_time - timestamp > max_age_seconds then
            notification_state.dailyGoal.lastRecurringNotification[state_key] = nil
        end
    end

    -- Clean up core hours notification entries
    for state_key, timestamp in pairs(notification_state.coreHours.lastNotification) do
        if current_time - timestamp > max_age_seconds then
            notification_state.coreHours.lastNotification[state_key] = nil
        end
    end
end

---Check if we should reset notification state when switching between modes
---@param notification_config table The current notification configuration
---@param state_key string The state key for the current day
function M._handleModeSwitch(notification_config, state_key)
    local state_modified = false

    -- If we're switching to oncePerDay mode and have recurring state, clear it
    if
        notification_config.oncePerDay
        and notification_state.dailyGoal.lastRecurringNotification[state_key]
    then
        -- Check if recurring notification was recent enough that we should respect it
        local recurring_time = notification_state.dailyGoal.lastRecurringNotification[state_key]
        local current_time = os.time()
        local time_since_last = (current_time - recurring_time) / 60

        -- If the last recurring notification was less than the configured interval ago,
        -- we should treat it as if we already notified for oncePerDay
        if time_since_last < notification_config.recurringMinutes then
            notification_state.dailyGoal.lastNotification[state_key] = recurring_time
            state_modified = true
        end

        -- Clear the recurring state since we're in oncePerDay mode now
        notification_state.dailyGoal.lastRecurringNotification[state_key] = nil
        state_modified = true
    end

    -- If we're switching to recurring mode and have oncePerDay state, use it as the base
    if
        not notification_config.oncePerDay
        and notification_state.dailyGoal.lastNotification[state_key]
    then
        -- Use the oncePerDay timestamp as the starting point for recurring notifications
        notification_state.dailyGoal.lastRecurringNotification[state_key] =
            notification_state.dailyGoal.lastNotification[state_key]

        -- Clear the oncePerDay state since we're in recurring mode now
        notification_state.dailyGoal.lastNotification[state_key] = nil
        state_modified = true
    end

    -- Save state if it was modified
    if state_modified then
        saveNotificationState()
    end
end

---Apply work model configuration from user config
---@param user_config table User configuration
function M._applyWorkModelConfiguration(user_config)
    -- Handle work model presets
    if user_config.workModel then
        local preset_config = config_module.applyWorkModelPreset(user_config.workModel)
        if preset_config then
            -- Apply preset values as defaults, but allow user overrides
            if not user_config.hoursPerWeekday then
                config_module.config.hoursPerWeekday = preset_config.hoursPerWeekday
            end
            if not user_config.coreWorkingHours then
                config_module.config.coreWorkingHours = preset_config.coreWorkingHours
            end
            config_module.config.workModel = preset_config.workModel
        else
            vim.notify(
                string.format(
                    'Warning: Unknown work model preset "%s". Using default configuration.',
                    user_config.workModel
                ),
                vim.log.levels.WARN,
                { title = 'TimeTracking - Config' }
            )
        end
    end

    -- Manual hoursPerWeekday override (merge with preset if exists, otherwise replace completely)
    if user_config.hoursPerWeekday ~= nil then
        if user_config.workModel then
            -- When using a work model, merge the manual override with the preset
            config_module.config.hoursPerWeekday = vim.tbl_deep_extend(
                'force',
                config_module.config.hoursPerWeekday or config_module.defaultHoursPerWeekday,
                user_config.hoursPerWeekday
            )
        else
            -- When not using a work model, use the original behavior (complete replacement)
            config_module.config.hoursPerWeekday = user_config.hoursPerWeekday
        end
    end

    -- Manual coreWorkingHours override (merge with preset if exists, otherwise replace completely)
    if user_config.coreWorkingHours ~= nil then
        local valid, error_msg =
            config_module.validateCoreWorkingHours(user_config.coreWorkingHours)
        if valid then
            if user_config.workModel then
                -- When using a work model, merge the manual override with the preset
                config_module.config.coreWorkingHours = vim.tbl_deep_extend(
                    'force',
                    config_module.config.coreWorkingHours or config_module.defaultCoreWorkingHours,
                    user_config.coreWorkingHours
                )
            else
                -- When not using a work model, use complete replacement
                config_module.config.coreWorkingHours = user_config.coreWorkingHours
            end
        else
            vim.notify(
                string.format(
                    'Warning: Invalid coreWorkingHours configuration: %s. Using defaults.',
                    error_msg
                ),
                vim.log.levels.WARN,
                { title = 'TimeTracking - Config' }
            )
        end
    end
end

function M.init(user_config)
    config_module.config =
        vim.tbl_deep_extend('force', vim.deepcopy(config_module.defaults), user_config or {})

    -- Apply work model configuration using extracted function
    if user_config then
        M._applyWorkModelConfiguration(user_config)
    end

    -- Validate notification configuration
    M._validateConfig(config_module.config)

    -- Clean up old notification state entries to prevent memory leaks
    M._cleanupNotificationState()
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

    -- Load notification state from persistent storage
    loadNotificationState()
    -- Ensure hoursPerWeekday is initialized if not present (e.g. new file)
    if config_module.obj.content['hoursPerWeekday'] == nil then
        config_module.obj.content['hoursPerWeekday'] = config_module.config.hoursPerWeekday
    end
    -- Ensure coreWorkingHours is initialized if not present
    if config_module.obj.content['coreWorkingHours'] == nil then
        config_module.obj.content['coreWorkingHours'] = config_module.config.coreWorkingHours
    end
    -- Ensure workModel is initialized if not present
    if config_module.obj.content['workModel'] == nil then
        config_module.obj.content['workModel'] = config_module.config.workModel
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

---@param year_str string The year to search in
---@param current_week_str string The current week number as string
---@return number The overhour value from the last week with data, or 0 if none found
function M._findLastWeekWithOvertime(year_str, current_week_str)
    local current_week_num = tonumber(current_week_str)
    if not current_week_num or not config_module.obj.content['data'][year_str] then
        return 0
    end

    -- Search backwards through weeks (limit search to avoid infinite loops)
    for week_offset = 1, 53 do -- Maximum 53 weeks in a year
        local check_week_num = current_week_num - week_offset
        if check_week_num < 1 then
            break -- Don't search into previous year for now
        end

        local check_week_str = string.format('%02d', check_week_num)
        local week_data = config_module.obj.content['data'][year_str][check_week_str]

        if week_data and week_data.summary and week_data.summary.overhour ~= nil then
            return week_data.summary.overhour
        end
    end

    return 0
end

function M.calculate(opts)
    opts = vim.tbl_deep_extend('keep', opts or {}, {
        year = os.date('%Y'),
        weeknumber = os.date('%W'),
    })

    local year_str = tostring(opts.year)
    local week_str = tostring(opts.weeknumber)

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

    local prevWeekOverhour = M._findLastWeekWithOvertime(year_str, week_str)

    current_week_data.summary.overhour = prevWeekOverhour -- Initialize with last week's overhour

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

            -- Check if daily goal notification should be shown
            M.checkDailyGoalNotification(
                year_str,
                week_str,
                weekday_name,
                total_hours_for_weekday,
                expected_hours_for_weekday
            )

            -- Add this weekday's overhour to the total week's overhour
            current_week_data.summary.overhour = current_week_data.summary.overhour
                + weekday_data.summary.overhour
        end
    end
end

---Check if daily goal notification should be shown and display it if needed
---@param year_str string
---@param week_str string
---@param weekday_name string
---@param total_hours number
---@param expected_hours number
function M.checkDailyGoalNotification(year_str, week_str, weekday_name, total_hours, expected_hours)
    -- Check if notifications are enabled
    if
        not config_module.config.notifications
        or not config_module.config.notifications.dailyGoal
        or not config_module.config.notifications.dailyGoal.enabled
    then
        return
    end

    -- Only notify for days with expected hours > 0 (working days)
    if expected_hours <= 0 then
        return
    end

    -- Check if goal is reached or exceeded
    if total_hours < expected_hours then
        return
    end

    local notification_config = config_module.config.notifications.dailyGoal
    local state_key = year_str .. '-' .. week_str .. '-' .. weekday_name
    local current_time = os.time()

    -- Handle mode switching to prevent unexpected notification behavior
    M._handleModeSwitch(notification_config, state_key)

    -- Determine if we should notify
    local should_notify = false
    local notification_type = 'reached'

    if total_hours >= expected_hours then
        if total_hours > expected_hours then
            notification_type = 'exceeded'
        end

        if notification_config.oncePerDay then
            -- Check if we haven't notified for this day yet
            if not notification_state.dailyGoal.lastNotification[state_key] then
                should_notify = true
                notification_state.dailyGoal.lastNotification[state_key] = current_time
                saveNotificationState()
            end
        else
            -- Recurring notifications - check if enough time has passed
            local last_notification = notification_state.dailyGoal.lastRecurringNotification[state_key]
                or 0
            local minutes_passed = (current_time - last_notification) / 60

            if minutes_passed >= notification_config.recurringMinutes then
                should_notify = true
                notification_state.dailyGoal.lastRecurringNotification[state_key] = current_time
                saveNotificationState()
            end
        end
    end

    if should_notify then
        local message
        local overhour = total_hours - expected_hours

        if notification_type == 'exceeded' then
            message = string.format(
                'Daily goal exceeded! %s: %.1fh worked (%.1fh goal, +%.1fh over)',
                weekday_name,
                total_hours,
                expected_hours,
                overhour
            )
        else
            message = string.format(
                'Daily goal reached! %s: %.1fh worked (%.1fh goal)',
                weekday_name,
                total_hours,
                expected_hours
            )
        end

        -- Use vim.notify instead for easier testing
        vim.notify(message, vim.log.levels.INFO, { title = 'TimeTracking - Daily Goal' })
    end
end

---Check core hours compliance for a time entry and show notification if needed
---@param start_time number Start timestamp
---@param end_time number End timestamp
---@param weekday_name string
function M.checkCoreHoursCompliance(start_time, end_time, weekday_name)
    -- Check if core hours compliance notifications are enabled
    if
        not config_module.config.notifications
        or not config_module.config.notifications.coreHoursCompliance
        or not config_module.config.notifications.coreHoursCompliance.enabled
        or not config_module.config.notifications.coreHoursCompliance.warnOutsideCoreHours
    then
        return
    end

    local core_hours = config_module.config.coreWorkingHours
        or config_module.obj.content.coreWorkingHours
    if not core_hours or not core_hours[weekday_name] then
        return -- No core hours defined for this weekday
    end

    -- Only notify if core hours were explicitly configured (not just defaults)
    -- Check if the current core hours are different from defaults, indicating explicit configuration
    local is_explicitly_configured = false
    if config_module.obj.content.coreWorkingHours then
        -- Core hours were saved to file, indicating user configuration
        is_explicitly_configured = true
    elseif config_module.config.workModel then
        -- A work model preset was applied
        is_explicitly_configured = true
    else
        -- Check if config differs from defaults
        local default_core_hours = config_module.defaultCoreWorkingHours
        if not default_core_hours or not default_core_hours[weekday_name] then
            is_explicitly_configured = true
        else
            local current_core = core_hours[weekday_name]
            local default_core = default_core_hours[weekday_name]
            if
                not current_core
                or not default_core
                or current_core.start ~= default_core.start
                or current_core.finish ~= default_core.finish
            then
                is_explicitly_configured = true
            end
        end
    end

    if not is_explicitly_configured then
        return -- Don't notify for default core hours
    end

    local core = core_hours[weekday_name]
    if not core then
        return -- No core hours for this weekday
    end

    -- Check if work time overlaps with core hours
    local start_within_core = config_module.isWithinCoreHours(start_time, weekday_name, core_hours)
    local end_within_core = config_module.isWithinCoreHours(end_time, weekday_name, core_hours)

    -- Notification state tracking
    local year_str = os.date('%Y', start_time)
    local week_str = os.date('%W', start_time)
    local state_key = 'core-hours-' .. year_str .. '-' .. week_str .. '-' .. weekday_name
    local current_time = os.time()

    local notification_config = config_module.config.notifications.coreHoursCompliance

    -- Check if we should notify (only once per day if configured)
    local should_notify = true
    if notification_config.oncePerDay then
        if notification_state.coreHours.lastNotification[state_key] then
            should_notify = false
        else
            notification_state.coreHours.lastNotification[state_key] = current_time
            saveNotificationState()
        end
    end

    if should_notify and (not start_within_core or not end_within_core) then
        local start_time_str = os.date('%H:%M', start_time)
        local end_time_str = os.date('%H:%M', end_time)
        local core_start_str = string.format('%02d:%02d', core.start, (core.start % 1) * 60)
        local core_end_str = string.format('%02d:%02d', core.finish, (core.finish % 1) * 60)

        local message = string.format(
            'Work time outside core hours! %s %s-%s (core: %s-%s)',
            weekday_name,
            start_time_str,
            end_time_str,
            core_start_str,
            core_end_str
        )

        vim.notify(message, vim.log.levels.WARN, { title = 'TimeTracking - Core Hours' })
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

    -- Check core hours compliance for this time entry (only for actual work, not subtractions)
    if not isSubtraction then
        M.checkCoreHoursCompliance(startTime, endTime, weekday)
    end

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

    local year_str = tostring(opts.year or os.date('%Y'))
    local week_str = tostring(opts.weeknumber or os.date('%W'))
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

---Get weekly summary data with optional filtering
---@param opts? { year?: string, week?: string, project?: string, file?: string }
---@return table Weekly summary data with daily breakdowns and totals
function M.getWeeklySummary(opts)
    opts = opts or {}

    -- Get current week if not specified
    local current_time = os.time()
    local year_str = tostring(opts.year or os.date('%Y', current_time))
    local week_str = tostring(opts.week or os.date('%W', current_time))

    -- Initialize summary structure
    local summary = {
        year = year_str,
        week = week_str,
        weekdays = {},
        totals = {
            totalHours = 0,
            totalOvertime = 0,
            expectedHours = 0,
        },
    }

    -- Define weekday order for consistent display
    local weekday_order =
        { 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday' }

    -- Check if data exists for this week
    local week_data = utils.getWeekData(year_str, week_str)
    if not week_data then
        -- Return empty summary with configured expected hours
        for _, weekday in ipairs(weekday_order) do
            local expected = config_module.obj.content.hoursPerWeekday[weekday] or 0
            summary.weekdays[weekday] = {
                workedHours = 0,
                expectedHours = expected,
                overtime = -expected,
                projects = {},
                pauseTime = 0,
            }
            summary.totals.expectedHours = summary.totals.expectedHours + expected
            summary.totals.totalOvertime = summary.totals.totalOvertime - expected
        end
        return summary
    end

    -- Process each weekday
    for _, weekday in ipairs(weekday_order) do
        local expected_hours = config_module.obj.content.hoursPerWeekday[weekday] or 0
        local weekday_info = {
            workedHours = 0,
            expectedHours = expected_hours,
            overtime = 0,
            projects = {},
            pauseTime = 0,
        }

        -- Add to total expected hours
        summary.totals.expectedHours = summary.totals.expectedHours + expected_hours

        if week_data[weekday] then
            -- Calculate worked hours and collect project data
            local weekday_data = week_data[weekday]
            if weekday_data.summary then
                weekday_info.workedHours = weekday_data.summary.diffInHours or 0
                weekday_info.overtime = weekday_data.summary.overhour
                    or (weekday_info.workedHours - expected_hours)
            else
                -- If weekday data exists but no summary, calculate manually
                local total_hours = 0
                for project_name, project_data in pairs(weekday_data) do
                    if project_name ~= 'summary' and type(project_data) == 'table' then
                        for file_name, file_data in pairs(project_data) do
                            if type(file_data) == 'table' and file_data.items then
                                for _, item in ipairs(file_data.items) do
                                    total_hours = total_hours + (item.diffInHours or 0)
                                end
                            end
                        end
                    end
                end
                weekday_info.workedHours = total_hours
                weekday_info.overtime = total_hours - expected_hours
            end

            -- Calculate pause time for this day
            weekday_info.pauseTime = M._calculatePauseTime(year_str, week_str, weekday)

            -- Collect project/file data if filtering is needed or for detailed view
            for project_name, project_data in pairs(weekday_data) do
                if project_name ~= 'summary' and type(project_data) == 'table' then
                    -- Apply project filter if specified
                    if not opts.project or project_name == opts.project then
                        local project_hours = 0
                        local files = {}

                        for file_name, file_data in pairs(project_data) do
                            if type(file_data) == 'table' and file_data.summary then
                                -- Apply file filter if specified
                                if not opts.file or file_name == opts.file then
                                    local file_hours = file_data.summary.diffInHours or 0
                                    project_hours = project_hours + file_hours
                                    files[file_name] = file_hours
                                end
                            end
                        end

                        if project_hours > 0 then
                            weekday_info.projects[project_name] = {
                                hours = project_hours,
                                files = files,
                            }
                        end
                    end
                end
            end

            -- If filtering is applied, recalculate worked hours from filtered data
            if opts.project or opts.file then
                local filtered_hours = 0
                for _, project_info in pairs(weekday_info.projects) do
                    filtered_hours = filtered_hours + project_info.hours
                end
                weekday_info.workedHours = filtered_hours
                weekday_info.overtime = filtered_hours - expected_hours
            end
        else
            -- No data for this weekday
            weekday_info.overtime = -expected_hours
        end

        summary.weekdays[weekday] = weekday_info
        summary.totals.totalHours = summary.totals.totalHours + weekday_info.workedHours
        summary.totals.totalOvertime = summary.totals.totalOvertime + weekday_info.overtime
    end

    return summary
end

---Calculate pause time for a specific day
---Pause time is the duration between earliest start and latest end minus actual tracked time
---@param year_str string
---@param week_str string
---@param weekday string
---@return number Pause time in hours, 0 if no data or only one entry
function M._calculatePauseTime(year_str, week_str, weekday)
    -- Use helper function for safe data access
    local weekday_data = utils.getWeekdayData(year_str, week_str, weekday)
    if not weekday_data then
        return 0
    end

    local start_times = {}
    local end_times = {}
    local total_tracked_time = 0

    -- Collect all time entries for the day across all projects and files
    for project_name, project_data in pairs(weekday_data) do
        if project_name ~= 'summary' and type(project_data) == 'table' then
            for file_name, file_data in pairs(project_data) do
                if file_name ~= 'summary' and type(file_data) == 'table' and file_data.items then
                    for _, entry in ipairs(file_data.items) do
                        if entry.startTime and entry.endTime then
                            table.insert(start_times, entry.startTime)
                            table.insert(end_times, entry.endTime)
                            total_tracked_time = total_tracked_time + (entry.diffInHours or 0)
                        end
                    end
                end
            end
        end
    end

    -- Need at least 2 entries to calculate pause time
    if #start_times < 2 then
        return 0
    end

    -- Find earliest start time and latest end time using math.min/max for better performance
    local earliest_start = math.min(unpack(start_times))
    local latest_end = math.max(unpack(end_times))

    -- Calculate total time span and pause time
    if earliest_start and latest_end and latest_end > earliest_start then
        local total_span_hours = (latest_end - earliest_start) / 3600
        local pause_time = total_span_hours - total_tracked_time
        return math.max(0, pause_time) -- Ensure non-negative
    end

    return 0
end

---Get detailed daily summary data
---@param opts { year?: string, week?: string, weekday: string }
---@return table Daily summary with projects, files, time periods, and goal status
function M.getDailySummary(opts)
    opts = opts or {}

    -- Get current week if not specified
    local current_time = os.time()
    local year_str = tostring(opts.year or os.date('%Y', current_time))
    local week_str = tostring(opts.week or os.date('%W', current_time))
    local weekday = opts.weekday

    if not weekday then
        error('weekday parameter is required')
    end

    -- Initialize daily summary structure
    local summary = {
        year = year_str,
        week = week_str,
        weekday = weekday,
        workedHours = 0,
        expectedHours = config_module.obj.content.hoursPerWeekday[weekday] or 0,
        overtime = 0,
        goalAchieved = false,
        pauseTime = 0,
        workPeriods = {},
        projects = {},
        earliestStart = nil,
        latestEnd = nil,
    }

    -- Calculate overtime
    summary.overtime = summary.workedHours - summary.expectedHours
    summary.goalAchieved = summary.workedHours >= summary.expectedHours

    -- Get weekday data
    local weekday_data = utils.getWeekdayData(year_str, week_str, weekday)
    if not weekday_data then
        return summary
    end

    -- Collect all time entries and calculate totals
    local all_entries = {}

    for project_name, project_data in pairs(weekday_data) do
        if project_name ~= 'summary' and type(project_data) == 'table' then
            summary.projects[project_name] = {
                totalHours = 0,
                files = {},
            }

            for file_name, file_data in pairs(project_data) do
                if file_name ~= 'summary' and type(file_data) == 'table' then
                    local file_hours = 0
                    local file_entries = {}

                    if file_data.items then
                        for _, entry in ipairs(file_data.items) do
                            if entry.startTime and entry.endTime and entry.diffInHours then
                                table.insert(all_entries, {
                                    startTime = entry.startTime,
                                    endTime = entry.endTime,
                                    startReadable = entry.startReadable,
                                    endReadable = entry.endReadable,
                                    diffInHours = entry.diffInHours,
                                    project = project_name,
                                    file = file_name,
                                })

                                table.insert(file_entries, {
                                    startTime = entry.startTime,
                                    endTime = entry.endTime,
                                    startReadable = entry.startReadable,
                                    endReadable = entry.endReadable,
                                    diffInHours = entry.diffInHours,
                                })

                                file_hours = file_hours + entry.diffInHours
                                summary.workedHours = summary.workedHours + entry.diffInHours
                            end
                        end
                    end

                    if file_hours > 0 then
                        summary.projects[project_name].files[file_name] = {
                            hours = file_hours,
                            entries = file_entries,
                        }
                        summary.projects[project_name].totalHours = summary.projects[project_name].totalHours
                            + file_hours
                    end
                end
            end

            -- Remove projects with no worked hours
            if summary.projects[project_name].totalHours == 0 then
                summary.projects[project_name] = nil
            end
        end
    end

    -- Update calculations with actual worked hours
    summary.overtime = summary.workedHours - summary.expectedHours
    summary.goalAchieved = summary.workedHours >= summary.expectedHours

    -- Calculate pause time and work periods
    if #all_entries > 0 then
        -- Sort entries by start time
        table.sort(all_entries, function(a, b)
            return a.startTime < b.startTime
        end)

        summary.earliestStart = all_entries[1].startTime
        summary.latestEnd = all_entries[#all_entries].endTime

        -- Find latest end time (might not be the last entry if they overlap)
        for _, entry in ipairs(all_entries) do
            if not summary.latestEnd or entry.endTime > summary.latestEnd then
                summary.latestEnd = entry.endTime
            end
        end

        -- Calculate pause time using existing function
        summary.pauseTime = M._calculatePauseTime(year_str, week_str, weekday)

        -- Create work periods by detecting gaps in work
        summary.workPeriods = M._calculateWorkPeriods(all_entries)
    end

    return summary
end

---Calculate work periods based on time entries, detecting breaks between work sessions
---@param entries table Array of time entries sorted by start time
---@return table Array of work periods with start/end times
function M._calculateWorkPeriods(entries)
    if #entries == 0 then
        return {}
    end

    local work_periods = {}
    local current_period = {
        start = entries[1].startTime,
        startReadable = entries[1].startReadable,
        end_time = entries[1].endTime,
        endReadable = entries[1].endReadable,
    }

    -- Minimum gap in minutes to consider a break (30 minutes)
    local min_break_gap = 30 * 60

    for i = 2, #entries do
        local curr_entry = entries[i]

        -- Calculate gap between current period end and current entry start
        local gap = curr_entry.startTime - current_period.end_time

        if gap >= min_break_gap then
            -- Found a significant break, end current period and start new one
            table.insert(work_periods, current_period)
            current_period = {
                start = curr_entry.startTime,
                startReadable = curr_entry.startReadable,
                end_time = curr_entry.endTime,
                endReadable = curr_entry.endReadable,
            }
        else
            -- Continue current period, extend end time
            current_period.end_time = curr_entry.endTime
            current_period.endReadable = curr_entry.endReadable
        end
    end

    -- Don't forget to add the last period
    table.insert(work_periods, current_period)

    return work_periods
end

-- Zeit-Validierung & Korrekturmodus (Time Validation & Correction Mode)

---Detect overlapping time entries within the same day/project/file
---@param year_str string
---@param week_str string
---@param weekday string
---@param project string
---@param file string
---@return table List of overlapping entry pairs
function M._detectOverlappingEntriesForDayProjectFile(year_str, week_str, weekday, project, file)
    local entries = M._getEntriesForDay(year_str, week_str, weekday, project, file)
    local overlaps = {}

    for i = 1, #entries do
        for j = i + 1, #entries do
            local entry1 = entries[i]
            local entry2 = entries[j]

            -- Check if entries overlap (one starts before the other ends)
            if entry1.startTime and entry1.endTime and entry2.startTime and entry2.endTime then
                -- Check for overlap, but exclude exact duplicates (they are handled separately)
                local is_duplicate = (
                    entry1.startTime == entry2.startTime and entry1.endTime == entry2.endTime
                )
                local overlapping = (
                    entry1.startTime < entry2.endTime and entry2.startTime < entry1.endTime
                )
                if overlapping and not is_duplicate then
                    table.insert(overlaps, {
                        entry1 = { index = i, data = entry1 },
                        entry2 = { index = j, data = entry2 },
                        year = year_str,
                        week = week_str,
                        weekday = weekday,
                        project = project,
                        file = file,
                        type = 'overlap',
                    })
                end
            end
        end
    end

    return overlaps
end

---Detect duplicate time entries (same start/end times)
---@param year_str string
---@param week_str string
---@param weekday string
---@param project string
---@param file string
---@return table List of duplicate entry pairs
function M._detectDuplicateEntriesForDayProjectFile(year_str, week_str, weekday, project, file)
    local entries = M._getEntriesForDay(year_str, week_str, weekday, project, file)
    local duplicates = {}

    for i = 1, #entries do
        for j = i + 1, #entries do
            local entry1 = entries[i]
            local entry2 = entries[j]

            -- Check if entries are duplicates (same start and end times)
            if entry1.startTime and entry1.endTime and entry2.startTime and entry2.endTime then
                local is_duplicate = (
                    entry1.startTime == entry2.startTime and entry1.endTime == entry2.endTime
                )
                if is_duplicate then
                    table.insert(duplicates, {
                        entry1 = { index = i, data = entry1 },
                        entry2 = { index = j, data = entry2 },
                        year = year_str,
                        week = week_str,
                        weekday = weekday,
                        project = project,
                        file = file,
                        type = 'duplicate',
                    })
                end
            end
        end
    end

    return duplicates
end

---Detect erroneous time entries (invalid durations, timestamps, etc.)
---@param year_str string
---@param week_str string
---@param weekday string
---@param project string
---@param file string
---@return table List of erroneous entries
function M._detectErroneousEntriesForDayProjectFile(year_str, week_str, weekday, project, file)
    local entries = M._getEntriesForDay(year_str, week_str, weekday, project, file)
    local errors = {}

    for i, entry in ipairs(entries) do
        local issues = {}

        -- Check for missing timestamps
        if not entry.startTime or not entry.endTime then
            table.insert(issues, 'Fehlende Zeitstempel (Missing timestamps)')
        else
            -- Check for invalid time order
            if entry.startTime >= entry.endTime then
                table.insert(issues, 'Startzeit nach Endzeit (Start time after end time)')
            end

            -- Check for unrealistic durations (more than 24 hours)
            local duration_hours = (entry.endTime - entry.startTime) / 3600
            if duration_hours > 24 then
                table.insert(
                    issues,
                    string.format(
                        'Unrealistische Dauer: %.1f Stunden (Unrealistic duration: %.1f hours)',
                        duration_hours,
                        duration_hours
                    )
                )
            end

            -- Check for negative durations
            if duration_hours < 0 then
                table.insert(issues, 'Negative Dauer (Negative duration)')
            end
        end

        -- Check for missing or invalid diffInHours
        if entry.diffInHours then
            if entry.diffInHours < 0 then
                table.insert(issues, 'Negative diffInHours')
            elseif entry.diffInHours > 24 then
                table.insert(
                    issues,
                    string.format('Unrealistische diffInHours: %.2f', entry.diffInHours)
                )
            end

            -- Check consistency between timestamps and diffInHours
            if entry.startTime and entry.endTime then
                local calculated_hours = (entry.endTime - entry.startTime) / 3600
                local diff_threshold = 0.1 -- 6 minutes tolerance
                if math.abs(calculated_hours - entry.diffInHours) > diff_threshold then
                    table.insert(
                        issues,
                        string.format(
                            'Inkonsistente Zeitberechnung: %.2fh vs %.2fh (Inconsistent time calculation)',
                            calculated_hours,
                            entry.diffInHours
                        )
                    )
                end
            end
        end

        -- If any issues found, add to errors list
        if #issues > 0 then
            table.insert(errors, {
                index = i,
                data = entry,
                year = year_str,
                week = week_str,
                weekday = weekday,
                project = project,
                file = file,
                type = 'error',
                issues = issues,
            })
        end
    end

    return errors
end

---Validate time data for a specific time range
---@param opts { year?: string, week?: string, weekday?: string, project?: string, file?: string }
---@return table Validation results with overlaps, duplicates, and errors
function M.validateTimeData(opts)
    opts = opts or {}
    local year_str = tostring(opts.year or os.date('%Y'))
    local week_str = tostring(opts.week or os.date('%W'))

    local validation_results = {
        overlaps = {},
        duplicates = {},
        errors = {},
        summary = {
            total_overlaps = 0,
            total_duplicates = 0,
            total_errors = 0,
            scanned_entries = 0,
        },
    }

    -- If no data exists, return empty results
    local week_data = utils.getWeekData(year_str, week_str)
    if not week_data then
        return validation_results
    end

    -- Determine which weekdays to check
    local weekdays_to_check = {}
    if opts.weekday then
        table.insert(weekdays_to_check, opts.weekday)
    else
        weekdays_to_check =
            { 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday' }
    end

    -- Iterate through weekdays
    for _, weekday in ipairs(weekdays_to_check) do
        if week_data[weekday] and type(week_data[weekday]) == 'table' then
            -- Determine which projects to check
            local projects_to_check = {}
            if opts.project then
                table.insert(projects_to_check, opts.project)
            else
                for project, _ in pairs(week_data[weekday]) do
                    if project ~= 'summary' then
                        table.insert(projects_to_check, project)
                    end
                end
            end

            -- Iterate through projects
            for _, project in ipairs(projects_to_check) do
                if week_data[weekday][project] and type(week_data[weekday][project]) == 'table' then
                    -- Determine which files to check
                    local files_to_check = {}
                    if opts.file then
                        table.insert(files_to_check, opts.file)
                    else
                        for file, _ in pairs(week_data[weekday][project]) do
                            table.insert(files_to_check, file)
                        end
                    end

                    -- Iterate through files
                    for _, file in ipairs(files_to_check) do
                        if
                            week_data[weekday][project][file]
                            and week_data[weekday][project][file].items
                        then
                            local entries = week_data[weekday][project][file].items
                            validation_results.summary.scanned_entries = validation_results.summary.scanned_entries
                                + #entries

                            -- Check for overlaps
                            local overlaps = M._detectOverlappingEntriesForDayProjectFile(
                                year_str,
                                week_str,
                                weekday,
                                project,
                                file
                            )
                            for _, overlap in ipairs(overlaps) do
                                table.insert(validation_results.overlaps, overlap)
                                validation_results.summary.total_overlaps = validation_results.summary.total_overlaps
                                    + 1
                            end

                            -- Check for duplicates
                            local duplicates = M._detectDuplicateEntriesForDayProjectFile(
                                year_str,
                                week_str,
                                weekday,
                                project,
                                file
                            )
                            for _, duplicate in ipairs(duplicates) do
                                table.insert(validation_results.duplicates, duplicate)
                                validation_results.summary.total_duplicates = validation_results.summary.total_duplicates
                                    + 1
                            end

                            -- Check for errors
                            local errors = M._detectErroneousEntriesForDayProjectFile(
                                year_str,
                                week_str,
                                weekday,
                                project,
                                file
                            )
                            for _, error in ipairs(errors) do
                                table.insert(validation_results.errors, error)
                                validation_results.summary.total_errors = validation_results.summary.total_errors
                                    + 1
                            end
                        end
                    end
                end
            end
        end
    end

    return validation_results
end

---Get available work model presets
---@return table List of available preset names with descriptions
function M.getAvailableWorkModels()
    return config_module.getAvailableWorkModels()
end

---Apply a work model preset to current configuration
---@param preset_name string Name of the preset (e.g., 'fourDayWeek', 'partTime')
---@return boolean Success status
function M.applyWorkModelPreset(preset_name)
    local preset_config = config_module.applyWorkModelPreset(preset_name)
    if not preset_config then
        vim.notify(
            string.format('Work model preset "%s" not found', preset_name),
            vim.log.levels.ERROR,
            { title = 'TimeTracking - Work Model' }
        )
        return false
    end

    -- Ensure we have a valid path before saving
    if not config_module.obj.path then
        vim.notify(
            'Error: Configuration path not initialized. Call setup() first.',
            vim.log.levels.ERROR,
            { title = 'TimeTracking - Work Model' }
        )
        return false
    end

    -- Update current configuration
    config_module.config.hoursPerWeekday = preset_config.hoursPerWeekday
    config_module.config.coreWorkingHours = preset_config.coreWorkingHours
    config_module.config.workModel = preset_config.workModel

    -- Update stored content
    config_module.obj.content.hoursPerWeekday = preset_config.hoursPerWeekday
    config_module.obj.content.coreWorkingHours = preset_config.coreWorkingHours
    config_module.obj.content.workModel = preset_config.workModel

    utils.save()

    vim.notify(
        string.format('Applied work model: %s', config_module.workModelPresets[preset_name].name),
        vim.log.levels.INFO,
        { title = 'TimeTracking - Work Model' }
    )

    return true
end

---Get current work model configuration
---@return table Current work model settings
function M.getCurrentWorkModel()
    return {
        workModel = config_module.obj.content.workModel or config_module.config.workModel,
        hoursPerWeekday = config_module.obj.content.hoursPerWeekday
            or config_module.config.hoursPerWeekday,
        coreWorkingHours = config_module.obj.content.coreWorkingHours
            or config_module.config.coreWorkingHours,
    }
end

---Check if a timestamp is within core working hours for a weekday
---@param timestamp number Unix timestamp
---@param weekday string Weekday name (e.g., 'Monday')
---@return boolean True if within core hours, false otherwise
function M.isWithinCoreHours(timestamp, weekday)
    local core_hours = config_module.obj.content.coreWorkingHours
        or config_module.config.coreWorkingHours
    return config_module.isWithinCoreHours(timestamp, weekday, core_hours)
end

return M
