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

return M
