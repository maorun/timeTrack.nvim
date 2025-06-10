local core = require('maorun.time.core')
local config_module = require('maorun.time.config') -- For weekdayNumberMap

local M = {}

---@param opts { hours?: boolean, weekday?: boolean, project?: boolean, file?: boolean }
---@param callback fun(hours:number, weekday: string, project:string, file:string) the function to call
function M.select(opts, callback)
    opts = vim.tbl_deep_extend('force', {
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
                get_weekday_selection()
            end)
        else
            get_weekday_selection()
        end
    end

    local function get_project_input()
        if opts.project then
            vim.ui.input({ prompt = 'Project name? (default: default_project) ' }, function(input)
                selected_project = (input and input ~= '') and input or 'default_project'
                get_file_input()
            end)
        else
            get_file_input()
        end
    end

    local selections = {}
    local selectionNumbers = {}
    -- Sort weekdayNumberMap by value to ensure consistent order for vim.ui.select
    local sorted_weekdays = {}
    for day, num in pairs(config_module.weekdayNumberMap) do
        table.insert(sorted_weekdays, { name = day, value = num })
    end
    table.sort(sorted_weekdays, function(a, b) return a.value < b.value end)

    for _, day_info in ipairs(sorted_weekdays) do
        if not selectionNumbers[day_info.value] then -- This check might be redundant if weekdayNumberMap has unique values
            selectionNumbers[day_info.value] = 1
            selections[#selections + 1] = day_info.name
        end
    end


    ---@param weekday_param string
    local function selectHours(weekday_param)
        if opts.hours then
            vim.ui.input({
                prompt = 'How many hours? ',
            }, function(input)
                local n = tonumber(input)
                if n == nil or input == nil or input == '' then
                    notify("Invalid number of hours provided.", "warn", {title = "TimeTracking"})
                    return
                end
                callback(n, weekday_param, selected_project, selected_file)
            end)
        else
            callback(0, weekday_param, selected_project, selected_file) -- Assuming 0 hours if not prompted
        end
    end

    local function get_weekday_selection()
        if opts.weekday then
            if pcall(require, 'telescope') and require('maorun.time.weekday_select') then
                local telescopeSelect = require('maorun.time.weekday_select')
                telescopeSelect({
                    prompt_title = 'Which day?',
                    list = selections, -- Use the sorted selections
                    action = function(selected_weekday)
                        if selected_weekday then -- Ensure a selection was made
                           selectHours(selected_weekday)
                        else
                           notify("No weekday selected.", "info", {title = "TimeTracking"})
                        end
                    end,
                })
            else
                vim.ui.select(selections, { -- Use the sorted selections
                    prompt = 'Which day? ',
                }, function(selected_weekday)
                    if selected_weekday then -- Ensure a selection was made
                        selectHours(selected_weekday)
                    else
                        notify("No weekday selected.", "info", {title = "TimeTracking"})
                    end
                end)
            end
        else
            -- This case needs careful handling. If weekday is false, what should happen?
            -- The original code didn't seem to have a clear path if opts.weekday was false
            -- and callback requires a weekday.
            -- For now, let's assume if opts.weekday is false, the operation is not time-specific
            -- and we call back with a nil weekday, or a sensible default.
            -- However, the callback signature expects a weekday string.
            -- Option 1: Error or notify that weekday is required.
            -- Option 2: Use a default (e.g., current day).
            -- Option 3: Modify callback or have different select functions.
            -- Given current callback, let's notify and not proceed if weekday is essential but skipped.
            if opts.hours then -- If hours are also expected, it's likely a time entry operation.
                 notify("Weekday selection was skipped, but it's required for this operation.", "warn", {title = "TimeTracking"})
                 return
            else
                -- If only project/file are relevant and weekday/hours are not.
                -- This path is not used by current Time.add/subtract/set.
                callback(0, nil, selected_project, selected_file)
            end
        end
    end

    get_project_input()
end

return M
