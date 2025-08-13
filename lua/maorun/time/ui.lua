local core = require('maorun.time.core')
local config_module = require('maorun.time.config') -- For weekdayNumberMap

local M = {}

local function notify(msg, level, opts)
    vim.notify(msg, level, opts)
end

local function select_hours_internal(opts, callback, current_selection_state)
    if opts.hours then
        vim.ui.input({ prompt = 'How many hours? ' }, function(input)
            local n = tonumber(input)
            if n == nil or input == nil or input == '' then
                notify('Invalid number of hours provided.', 'warn', { title = 'TimeTracking' })
                return
            end
            callback(
                n,
                current_selection_state.weekday,
                current_selection_state.project,
                current_selection_state.file
            )
        end)
    else
        callback(
            0,
            current_selection_state.weekday,
            current_selection_state.project,
            current_selection_state.file
        )
    end
end

local function get_weekday_selection_internal(
    opts,
    callback,
    current_selection_state,
    selections_list
)
    if opts.weekday then
        if pcall(require, 'telescope') and require('maorun.time.weekday_select') then
            local telescopeSelect = require('maorun.time.weekday_select')
            telescopeSelect({
                prompt_title = 'Which day?',
                list = selections_list,
                action = function(selected_weekday)
                    if selected_weekday then
                        current_selection_state.weekday = selected_weekday
                        select_hours_internal(opts, callback, current_selection_state)
                    else
                        notify('No weekday selected.', 'info', { title = 'TimeTracking' })
                    end
                end,
            })
        else
            vim.ui.select(selections_list, { prompt = 'Which day? ' }, function(selected_weekday)
                if selected_weekday then
                    current_selection_state.weekday = selected_weekday
                    select_hours_internal(opts, callback, current_selection_state)
                else
                    notify('No weekday selected.', 'info', { title = 'TimeTracking' })
                end
            end)
        end
    else
        current_selection_state.weekday = nil
        if opts.hours then
            notify(
                "Weekday selection was skipped, but it's required for this operation.",
                'warn',
                { title = 'TimeTracking' }
            )
            return
        else
            callback(0, nil, current_selection_state.project, current_selection_state.file)
        end
    end
end

local function get_file_input_internal(opts, callback, current_selection_state, selections_list)
    if opts.file then
        vim.ui.input({ prompt = 'File name? (default: default_file) ' }, function(input)
            current_selection_state.file = (input and input ~= '') and input or 'default_file'
            get_weekday_selection_internal(opts, callback, current_selection_state, selections_list)
        end)
    else
        current_selection_state.file = 'default_file'
        get_weekday_selection_internal(opts, callback, current_selection_state, selections_list)
    end
end

local function get_project_input_internal(opts, callback, current_selection_state, selections_list)
    if opts.project then
        vim.ui.input({ prompt = 'Project name? (default: default_project) ' }, function(input)
            current_selection_state.project = (input and input ~= '') and input or 'default_project'
            get_file_input_internal(opts, callback, current_selection_state, selections_list)
        end)
    else
        current_selection_state.project = 'default_project'
        get_file_input_internal(opts, callback, current_selection_state, selections_list)
    end
end

---@param opts { hours?: boolean, weekday?: boolean, project?: boolean, file?: boolean }
---@param callback fun(hours:number, weekday: string, project:string, file:string) the function to call
function M.select(opts, callback)
    local current_selection_state = {}

    opts = vim.tbl_deep_extend('force', {
        hours = true,
        weekday = true,
        project = true,
        file = true,
    }, opts or {})

    local selections = {}
    local selectionNumbers = {}
    -- Sort weekdayNumberMap by value to ensure consistent order for vim.ui.select
    local sorted_weekdays = {}
    for day, num in pairs(config_module.weekdayNumberMap) do
        table.insert(sorted_weekdays, { name = day, value = num })
    end
    table.sort(sorted_weekdays, function(a, b)
        return a.value < b.value
    end)

    for _, day_info in ipairs(sorted_weekdays) do
        if not selectionNumbers[day_info.value] then -- This check might be redundant if weekdayNumberMap has unique values
            selectionNumbers[day_info.value] = 1
            selections[#selections + 1] = day_info.name
        end
    end

    get_project_input_internal(opts, callback, current_selection_state, selections)
end

---@param opts { year?: string, weeknumber?: string, weekday?: string, project?: string, file?: string }
---@param callback fun(entry_info: table|nil) Called with selected entry info or nil if cancelled
function M.selectTimeEntry(opts, callback)
    opts = opts or {}

    -- First get the list of time entries
    local entries = core.listTimeEntries(opts)

    if #entries == 0 then
        notify(
            'No time entries found for the specified criteria.',
            'info',
            { title = 'TimeTracking' }
        )
        callback(nil)
        return
    end

    -- Format entries for display
    local display_items = {}
    for i, entry_info in ipairs(entries) do
        local entry = entry_info.entry
        local start_readable = entry.startReadable or 'N/A'
        local end_readable = entry.endReadable or 'N/A'
        local hours = string.format('%.2f', entry.diffInHours or 0)

        local display_text = string.format(
            '%s %s/%s: %s-%s (%sh)',
            entry_info.weekday,
            entry_info.project,
            entry_info.file,
            start_readable,
            end_readable,
            hours
        )

        table.insert(display_items, {
            text = display_text,
            entry_info = entry_info,
        })
    end

    -- Use vim.ui.select to let user choose an entry
    vim.ui.select(display_items, {
        prompt = 'Select time entry: ',
        format_item = function(item)
            return item.text
        end,
    }, function(selected_item)
        if selected_item then
            callback(selected_item.entry_info)
        else
            callback(nil)
        end
    end)
end

---@param callback fun() Called when editing is complete
function M.editTimeEntryDialog(callback)
    -- First, get selection criteria (weekday, project, file)
    M.select({
        hours = false, -- We don't need hours for selection
    }, function(_, weekday, project, file)
        if not weekday then
            notify('Weekday selection is required for editing.', 'warn', { title = 'TimeTracking' })
            callback()
            return
        end

        -- Now select a specific time entry
        M.selectTimeEntry({
            weekday = weekday,
            project = project,
            file = file,
        }, function(entry_info)
            if not entry_info then
                callback()
                return
            end

            -- Show edit dialog
            M._showEditEntryDialog(entry_info, callback)
        end)
    end)
end

---@param entry_info table The entry information to edit
---@param callback fun() Called when editing is complete
function M._showEditEntryDialog(entry_info, callback)
    local entry = entry_info.entry
    local current_start = entry.startReadable or 'N/A'
    local current_end = entry.endReadable or 'N/A'
    local current_hours = string.format('%.2f', entry.diffInHours or 0)

    local prompt_text = string.format(
        'Edit entry for %s %s/%s\nCurrent: %s-%s (%sh)\n\nWhat would you like to edit?',
        entry_info.weekday,
        entry_info.project,
        entry_info.file,
        current_start,
        current_end,
        current_hours
    )

    local edit_options = {
        'Start time (HH:MM)',
        'End time (HH:MM)',
        'Duration (hours)',
        'Delete this entry',
        'Cancel',
    }

    vim.ui.select(edit_options, {
        prompt = prompt_text,
    }, function(choice)
        if not choice or choice == 'Cancel' then
            callback()
            return
        end

        if choice == 'Delete this entry' then
            core.deleteTimeEntry({
                year = entry_info.year,
                week = entry_info.week,
                weekday = entry_info.weekday,
                project = entry_info.project,
                file = entry_info.file,
                index = entry_info.index,
            })
            notify('Time entry deleted.', 'info', { title = 'TimeTracking' })
            callback()
            return
        end

        M._handleEditChoice(choice, entry_info, callback)
    end)
end

---@param choice string The edit choice made by user
---@param entry_info table The entry information to edit
---@param callback fun() Called when editing is complete
function M._handleEditChoice(choice, entry_info, callback)
    if choice == 'Start time (HH:MM)' then
        vim.ui.input({
            prompt = 'Enter start time (HH:MM): ',
            default = entry_info.entry.startReadable or '',
        }, function(input)
            if input and input:match('^%d%d?:%d%d$') then
                local hour, min = input:match('(%d%d?):(%d%d)')
                hour, min = tonumber(hour), tonumber(min)

                if hour >= 0 and hour <= 23 and min >= 0 and min <= 59 then
                    -- Create timestamp for today with specified time
                    local date_info = os.date('*t', entry_info.entry.startTime)
                    date_info.hour = hour
                    date_info.min = min
                    date_info.sec = 0
                    local new_start_time = os.time(date_info)

                    core.editTimeEntry({
                        year = entry_info.year,
                        week = entry_info.week,
                        weekday = entry_info.weekday,
                        project = entry_info.project,
                        file = entry_info.file,
                        index = entry_info.index,
                        startTime = new_start_time,
                    })
                    notify('Start time updated.', 'info', { title = 'TimeTracking' })
                else
                    notify(
                        'Invalid time format. Use HH:MM (24-hour format).',
                        'warn',
                        { title = 'TimeTracking' }
                    )
                end
            elseif input then
                notify('Invalid time format. Use HH:MM.', 'warn', { title = 'TimeTracking' })
            end
            callback()
        end)
    elseif choice == 'End time (HH:MM)' then
        vim.ui.input({
            prompt = 'Enter end time (HH:MM): ',
            default = entry_info.entry.endReadable or '',
        }, function(input)
            if input and input:match('^%d%d?:%d%d$') then
                local hour, min = input:match('(%d%d?):(%d%d)')
                hour, min = tonumber(hour), tonumber(min)

                if hour >= 0 and hour <= 23 and min >= 0 and min <= 59 then
                    -- Create timestamp for today with specified time
                    local date_info =
                        os.date('*t', entry_info.entry.endTime or entry_info.entry.startTime)
                    date_info.hour = hour
                    date_info.min = min
                    date_info.sec = 0
                    local new_end_time = os.time(date_info)

                    core.editTimeEntry({
                        year = entry_info.year,
                        week = entry_info.week,
                        weekday = entry_info.weekday,
                        project = entry_info.project,
                        file = entry_info.file,
                        index = entry_info.index,
                        endTime = new_end_time,
                    })
                    notify('End time updated.', 'info', { title = 'TimeTracking' })
                else
                    notify(
                        'Invalid time format. Use HH:MM (24-hour format).',
                        'warn',
                        { title = 'TimeTracking' }
                    )
                end
            elseif input then
                notify('Invalid time format. Use HH:MM.', 'warn', { title = 'TimeTracking' })
            end
            callback()
        end)
    elseif choice == 'Duration (hours)' then
        vim.ui.input({
            prompt = 'Enter duration in hours: ',
            default = string.format('%.2f', entry_info.entry.diffInHours or 0),
        }, function(input)
            local hours = tonumber(input)
            if hours and hours > 0 and hours <= 24 then
                core.editTimeEntry({
                    year = entry_info.year,
                    week = entry_info.week,
                    weekday = entry_info.weekday,
                    project = entry_info.project,
                    file = entry_info.file,
                    index = entry_info.index,
                    diffInHours = hours,
                })
                notify('Duration updated.', 'info', { title = 'TimeTracking' })
            elseif input then
                notify(
                    'Invalid duration. Please enter a number between 0 and 24.',
                    'warn',
                    { title = 'TimeTracking' }
                )
            end
            callback()
        end)
    else
        callback()
    end
end

---@param callback fun() Called when manual entry is complete
function M.addManualTimeEntryDialog(callback)
    -- First, get selection criteria (weekday, project, file)
    M.select({
        hours = false, -- We don't need hours for this selection
    }, function(_, weekday, project, file)
        if not weekday then
            notify('Weekday selection is required.', 'warn', { title = 'TimeTracking' })
            callback()
            return
        end

        -- Get start time
        vim.ui.input({
            prompt = 'Enter start time (HH:MM): ',
        }, function(start_input)
            if not start_input or not start_input:match('^%d%d?:%d%d$') then
                notify('Invalid start time format. Use HH:MM.', 'warn', { title = 'TimeTracking' })
                callback()
                return
            end

            -- Get end time
            vim.ui.input({
                prompt = 'Enter end time (HH:MM): ',
            }, function(end_input)
                if not end_input or not end_input:match('^%d%d?:%d%d$') then
                    notify(
                        'Invalid end time format. Use HH:MM.',
                        'warn',
                        { title = 'TimeTracking' }
                    )
                    callback()
                    return
                end

                -- Parse times and create timestamps
                local start_hour, start_min = start_input:match('(%d%d?):(%d%d)')
                local end_hour, end_min = end_input:match('(%d%d?):(%d%d)')

                start_hour, start_min = tonumber(start_hour), tonumber(start_min)
                end_hour, end_min = tonumber(end_hour), tonumber(end_min)

                if
                    start_hour < 0
                    or start_hour > 23
                    or start_min < 0
                    or start_min > 59
                    or end_hour < 0
                    or end_hour > 23
                    or end_min < 0
                    or end_min > 59
                then
                    notify(
                        'Invalid time values. Use 24-hour format.',
                        'warn',
                        { title = 'TimeTracking' }
                    )
                    callback()
                    return
                end

                -- Create timestamps for today (or appropriate day based on weekday)
                local now = os.time()
                local date_info = os.date('*t', now)

                -- Adjust to the selected weekday if needed
                local current_wday = date_info.wday
                local target_wday = config_module.engNameToWday[weekday]
                if target_wday then
                    local day_diff = target_wday - current_wday
                    date_info = os.date('*t', now + (day_diff * 24 * 60 * 60))
                end

                date_info.hour = start_hour
                date_info.min = start_min
                date_info.sec = 0
                local start_time = os.time(date_info)

                date_info.hour = end_hour
                date_info.min = end_min
                local end_time = os.time(date_info)

                if start_time >= end_time then
                    notify(
                        'Start time must be before end time.',
                        'warn',
                        { title = 'TimeTracking' }
                    )
                    callback()
                    return
                end

                -- Add the manual time entry
                core.addManualTimeEntry({
                    startTime = start_time,
                    endTime = end_time,
                    weekday = weekday,
                    project = project,
                    file = file,
                })

                local duration = (end_time - start_time) / 3600
                notify(
                    string.format('Manual time entry added: %.2f hours', duration),
                    'info',
                    { title = 'TimeTracking' }
                )
                callback()
            end)
        end)
    end)
end

return M
