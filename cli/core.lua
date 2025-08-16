-- CLI-compatible core module for timeTrack.nvim
-- This module adapts the core functionality for CLI usage

-- Set up CLI compatibility layer before requiring any modules
local compat = require('cli.compat')

-- Override global vim table for CLI compatibility
vim = compat.vim

-- Override global require to handle plenary.path for CLI
local original_require = require
function require(modname)
    if modname == 'plenary.path' then
        -- Return a CLI-compatible path implementation
        return {
            new = function(path_str)
                local path_obj = {
                    _path = path_str,
                    filename = function(self)
                        return self._path:match('([^/\\]+)$') or ''
                    end,
                    parent = function(self)
                        local parent_path = self._path:match('(.+)[/\\][^/\\]*$') or '/'
                        return require('plenary.path').new(parent_path)
                    end,
                    absolute = function(self)
                        return self._path
                    end,
                    exists = function(self)
                        local file = io.open(self._path, 'r')
                        if file then
                            file:close()
                            return true
                        end
                        return false
                    end,
                    read = function(self)
                        local file = io.open(self._path, 'r')
                        if not file then
                            return ''
                        end
                        local content = file:read('*all')
                        file:close()
                        return content or ''
                    end,
                    write = function(self, content, mode)
                        mode = mode or 'w'
                        local file = io.open(self._path, mode)
                        if not file then
                            error('Failed to open file for writing: ' .. self._path)
                        end
                        file:write(content)
                        file:close()
                    end,
                    touch = function(self, opts)
                        opts = opts or {}
                        if opts.parents then
                            -- Create parent directories if needed
                            local parent_path = self._path:match('(.+)[/\\][^/\\]*$')
                            if parent_path then
                                os.execute('mkdir -p ' .. parent_path)
                            end
                        end
                        local file = io.open(self._path, 'a')
                        if file then
                            file:close()
                        end
                    end,
                    rm = function(self)
                        os.remove(self._path)
                    end,
                }
                return path_obj
            end,
            path = {
                sep = package.config:sub(1, 1),
            },
        }
    elseif modname == 'notify' then
        -- Return CLI-compatible notify
        return compat.notify
    else
        return original_require(modname)
    end
end

-- Now we can safely require the timeTrack modules
-- Add proper path for lua modules
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua'

local config_module = original_require('lua.maorun.time.config')
local core = original_require('lua.maorun.time.core')
local utils = original_require('lua.maorun.time.utils')

-- CLI module
local M = {}

-- Initialize the time tracking system for CLI
function M.init(config_override)
    local default_config = {
        path = compat.path.join(compat.path.get_data_dir(), 'maorun-time.json'),
        hoursPerWeekday = config_module.defaultHoursPerWeekday,
    }

    local config = compat.tbl.deep_extend('force', default_config, config_override or {})
    return core.init(config)
end

-- Get current week's summary
function M.get_weekly_summary(opts)
    opts = opts or {}
    M.init()

    local year = opts.year or os.date('%Y')
    local week = opts.week or os.date('%W')

    -- Get summary data using core functionality
    local summary_data = {}

    if
        config_module.obj.content.data
        and config_module.obj.content.data[tostring(year)]
        and config_module.obj.content.data[tostring(year)][tostring(week)]
    then
        local week_data = config_module.obj.content.data[tostring(year)][tostring(week)]

        for weekday, weekday_data in pairs(week_data) do
            if weekday ~= 'summary' then
                summary_data[weekday] = {
                    projects = {},
                    total_hours = 0,
                }

                for project, project_data in pairs(weekday_data) do
                    if project ~= 'summary' then
                        summary_data[weekday].projects[project] = {}
                        local project_hours = 0

                        for file, file_data in pairs(project_data) do
                            if file ~= 'summary' and file_data.summary then
                                local file_hours = file_data.summary.diffInHours or 0
                                summary_data[weekday].projects[project][file] = file_hours
                                project_hours = project_hours + file_hours
                            end
                        end

                        summary_data[weekday].total_hours = summary_data[weekday].total_hours
                            + project_hours
                    end
                end
            end
        end
    end

    return summary_data
end

-- Add a manual time entry
function M.add_time_entry(opts)
    if not opts.project or not opts.file or not opts.hours then
        error('project, file, and hours are required')
    end

    M.init()

    local weekday = opts.weekday or os.date('%A')

    -- Use the core addTime functionality
    core.addTime({
        time = opts.hours,
        weekday = weekday,
        project = opts.project,
        file = opts.file,
    })

    utils.save()
    return true
end

-- Validate time data
function M.validate_data(opts)
    opts = opts or {}
    M.init()

    return core.validateTimeData(opts)
end

-- Export data
function M.export_data(opts)
    opts = opts or {}
    M.init()

    return core.exportTimeData(opts)
end

-- List time entries
function M.list_entries(opts)
    opts = opts or {}
    M.init()

    return core.listTimeEntries(opts)
end

-- Get status/summary information
function M.get_status()
    M.init()

    local current_year = os.date('%Y')
    local current_week = os.date('%W')
    local current_weekday = os.date('%A')

    local status = {
        data_file = config_module.obj.path,
        current_year = current_year,
        current_week = current_week,
        current_weekday = current_weekday,
        paused = config_module.obj.content.paused or false,
        hours_per_weekday = config_module.obj.content.hoursPerWeekday
            or config_module.defaultHoursPerWeekday,
    }

    -- Get current week summary
    status.current_week_summary = M.get_weekly_summary({
        year = current_year,
        week = current_week,
    })

    return status
end

return M
