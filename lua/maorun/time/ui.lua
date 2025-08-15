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

---Show weekly overview in a floating window
---@param opts? { year?: string, week?: string, project?: string, file?: string, display_mode?: string }
function M.showWeeklyOverview(opts)
    opts = opts or {}
    local display_mode = opts.display_mode or 'floating'

    -- Get weekly summary data
    local summary = core.getWeeklySummary(opts)

    -- Format the content
    local content = M._formatWeeklySummaryContent(summary, opts)

    if display_mode == 'floating' then
        M._showFloatingWindow(
            content,
            'Wöchentliche Übersicht - KW ' .. summary.week .. '/' .. summary.year
        )
    elseif display_mode == 'buffer' then
        M._showInBuffer(content, 'Weekly Overview')
    elseif display_mode == 'quickfix' then
        M._showInQuickfix(content)
    else
        -- Default to floating window
        M._showFloatingWindow(
            content,
            'Wöchentliche Übersicht - KW ' .. summary.week .. '/' .. summary.year
        )
    end
end

---Format weekly summary data into displayable content
---@param summary table The weekly summary data
---@param opts table Display options
---@return table Array of content lines
function M._formatWeeklySummaryContent(summary, opts)
    local content = {}

    -- Header
    table.insert(
        content,
        string.format(
            '═══ Wöchentliche Übersicht - KW %s/%s ═══',
            summary.week,
            summary.year
        )
    )
    table.insert(content, '')

    -- Filter info if applied
    if opts.project or opts.file then
        local filter_info = 'Filter: '
        if opts.project then
            filter_info = filter_info .. 'Projekt: ' .. opts.project
        end
        if opts.file then
            if opts.project then
                filter_info = filter_info .. ', '
            end
            filter_info = filter_info .. 'Datei: ' .. opts.file
        end
        table.insert(content, filter_info)
        table.insert(content, '')
    end

    -- Daily breakdown
    table.insert(
        content,
        '┌─ Tägliche Übersicht ─────────────────────────────────────┐'
    )
    table.insert(
        content,
        '│ Tag        │ Gearbeitet │ Soll │ Überstunden │ Status   │'
    )
    table.insert(
        content,
        '├────────────┼────────────┼──────┼─────────────┼──────────┤'
    )

    local weekday_names_de = {
        Monday = 'Montag',
        Tuesday = 'Dienstag',
        Wednesday = 'Mittwoch',
        Thursday = 'Donnerstag',
        Friday = 'Freitag',
        Saturday = 'Samstag',
        Sunday = 'Sonntag',
    }

    local weekday_order =
        { 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday' }

    for _, weekday in ipairs(weekday_order) do
        local day_data = summary.weekdays[weekday]
        local day_name_de = weekday_names_de[weekday] or weekday
        local status = ''

        if day_data.workedHours == 0 then
            status = '⚪ Frei'
        elseif day_data.overtime > 0 then
            status = '🟢 Über'
        elseif day_data.overtime == 0 then
            status = '🟡 Ziel'
        else
            status = '🔴 Unter'
        end

        table.insert(
            content,
            string.format(
                '│ %-10s │ %8.2fh │ %4.0fh │ %9.2fh │ %-8s │',
                day_name_de,
                day_data.workedHours,
                day_data.expectedHours,
                day_data.overtime,
                status
            )
        )
    end

    table.insert(
        content,
        '└────────────┴────────────┴──────┴─────────────┴──────────┘'
    )
    table.insert(content, '')

    -- Weekly totals
    table.insert(
        content,
        '┌─ Wochenzusammenfassung ──────────────────────────────────┐'
    )
    table.insert(
        content,
        string.format(
            '│ Gesamtarbeitszeit: %8.2f Stunden                    │',
            summary.totals.totalHours
        )
    )
    table.insert(
        content,
        string.format(
            '│ Soll-Arbeitszeit:  %8.2f Stunden                    │',
            summary.totals.expectedHours
        )
    )

    local overtime_sign = summary.totals.totalOvertime >= 0 and '+' or ''
    table.insert(
        content,
        string.format(
            '│ Überstunden:       %s%7.2f Stunden                    │',
            overtime_sign,
            summary.totals.totalOvertime
        )
    )
    table.insert(
        content,
        '└──────────────────────────────────────────────────────────┘'
    )

    -- Project breakdown if not filtered and there are projects
    if not opts.project and not opts.file then
        local has_projects = false
        local project_summary = {}

        -- Collect project data across all days
        for _, day_data in pairs(summary.weekdays) do
            for project_name, project_info in pairs(day_data.projects) do
                if not project_summary[project_name] then
                    project_summary[project_name] = 0
                end
                project_summary[project_name] = project_summary[project_name] + project_info.hours
                has_projects = true
            end
        end

        if has_projects then
            table.insert(content, '')
            table.insert(
                content,
                '┌─ Projekte ───────────────────────────────────────────────┐'
            )

            -- Sort projects by hours worked
            local sorted_projects = {}
            for project_name, hours in pairs(project_summary) do
                table.insert(sorted_projects, { name = project_name, hours = hours })
            end
            table.sort(sorted_projects, function(a, b)
                return a.hours > b.hours
            end)

            for _, project in ipairs(sorted_projects) do
                local percentage = summary.totals.totalHours > 0
                        and (project.hours / summary.totals.totalHours * 100)
                    or 0
                table.insert(
                    content,
                    string.format(
                        '│ %-40s %8.2fh (%4.1f%%) │',
                        project.name,
                        project.hours,
                        percentage
                    )
                )
            end

            table.insert(
                content,
                '└──────────────────────────────────────────────────────────┘'
            )
        end
    end

    table.insert(content, '')
    table.insert(content, 'Drücke q zum Schließen, f für Filter-Optionen')

    return content
end

---Show content in a floating window
---@param content table Array of content lines
---@param title string Window title
function M._showFloatingWindow(content, title)
    -- Calculate window size
    local max_width = 0
    for _, line in ipairs(content) do
        max_width = math.max(max_width, vim.fn.strdisplaywidth(line))
    end

    local width = math.min(max_width + 4, vim.o.columns - 10)
    local height = math.min(#content + 2, vim.o.lines - 10)

    -- Calculate position (centered)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    -- Create buffer
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')

    -- Create window
    local win = vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        style = 'minimal',
        border = 'rounded',
        title = title,
        title_pos = 'center',
    })

    -- Set key mappings for the floating window
    local function close_window()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end

    -- Key mappings
    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '', {
        noremap = true,
        silent = true,
        callback = close_window,
    })

    vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', '', {
        noremap = true,
        silent = true,
        callback = close_window,
    })

    -- Filter options mapping
    vim.api.nvim_buf_set_keymap(buf, 'n', 'f', '', {
        noremap = true,
        silent = true,
        callback = function()
            close_window()
            M._showFilterDialog()
        end,
    })

    -- Set window options
    vim.api.nvim_win_set_option(win, 'wrap', false)
    vim.api.nvim_win_set_option(win, 'cursorline', true)
end

---Show content in a new buffer
---@param content table Array of content lines
---@param title string Buffer title
function M._showInBuffer(content, title)
    -- Create new buffer
    vim.cmd('new')
    local buf = vim.api.nvim_get_current_buf()

    -- Set buffer content and options
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
    vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(buf, 'swapfile', false)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    vim.api.nvim_buf_set_name(buf, title)
end

---Show content in quickfix window
---@param content table Array of content lines
function M._showInQuickfix(content)
    local qf_list = {}
    for i, line in ipairs(content) do
        table.insert(qf_list, {
            text = line,
            lnum = i,
            col = 1,
        })
    end

    vim.fn.setqflist(qf_list)
    vim.cmd('copen')
end

---Show dialog for filtering options
function M._showFilterDialog()
    local options = {
        'Alle Projekte anzeigen',
        'Nach Projekt filtern',
        'Nach Datei filtern',
        'Nach Projekt und Datei filtern',
        'Andere Woche anzeigen',
    }

    vim.ui.select(options, {
        prompt = 'Filter-Optionen: ',
    }, function(choice)
        if not choice then
            return
        end

        if choice == 'Alle Projekte anzeigen' then
            M.showWeeklyOverview({})
        elseif choice == 'Nach Projekt filtern' then
            vim.ui.input({ prompt = 'Projektname: ' }, function(project)
                if project and project ~= '' then
                    M.showWeeklyOverview({ project = project })
                end
            end)
        elseif choice == 'Nach Datei filtern' then
            vim.ui.input({ prompt = 'Dateiname: ' }, function(file)
                if file and file ~= '' then
                    M.showWeeklyOverview({ file = file })
                end
            end)
        elseif choice == 'Nach Projekt und Datei filtern' then
            vim.ui.input({ prompt = 'Projektname: ' }, function(project)
                if project and project ~= '' then
                    vim.ui.input({ prompt = 'Dateiname: ' }, function(file)
                        if file and file ~= '' then
                            M.showWeeklyOverview({ project = project, file = file })
                        end
                    end)
                end
            end)
        elseif choice == 'Andere Woche anzeigen' then
            vim.ui.input({ prompt = 'Jahr (YYYY): ' }, function(year)
                if year and year ~= '' then
                    vim.ui.input({ prompt = 'Woche (1-52): ' }, function(week)
                        if week and week ~= '' then
                            M.showWeeklyOverview({
                                year = year,
                                week = string.format('%02d', tonumber(week) or 1),
                            })
                        end
                    end)
                end
            end)
        end
    end)
end

return M
