-- Main init.lua for maorun.time

-- Require the new modules
local config_module = require('maorun.time.config')
local core = require('maorun.time.core')
local utils = require('maorun.time.utils') -- Though utils might be mostly used by core
local autocmds = require('maorun.time.autocmds')
local ui = require('maorun.time.ui')

-- The main module table that will be returned
local M = {}

-- Setup function to initialize the plugin
---@param user_config table|nil User configuration to override defaults
function M.setup(user_config)
    -- Initialize core components (loads data, sets up config_module.obj and config_module.config)
    local config_obj = core.init(user_config) -- Store the returned object
    -- Setup autocommands
    autocmds.setup_autocmds()
    -- The global Time table is not strictly necessary if all interactions happen via returned module,
    -- but keeping it for compatibility if it was used globally before.
    -- Otherwise, commands should be set up to call M.add(), M.subtract(), etc.
    Time = {
        add = function()
            ui.select(
                {}, -- Default opts: ask for hours, weekday, project, file
                function(hours, weekday, project, file)
                    core.addTime({ time = hours, weekday = weekday, project = project, file = file })
                end
            )
        end,
        addTime = core.addTime,
        subtract = function()
            ui.select(
                {}, -- Default opts
                function(hours, weekday, project, file)
                    core.subtractTime({
                        time = hours,
                        weekday = weekday,
                        project = project,
                        file = file,
                    })
                end
            )
        end,
        subtractTime = core.subtractTime,
        clearDay = function(weekday, project, file) -- Requires explicit params now
            -- This public clearDay needs a way to get weekday, project, file.
            -- Option 1: Use ui.select, asking only for what's needed.
            -- Option 2: Require user to pass them directly.
            -- For now, assume direct pass or user handles getting them.
            -- If called from command, command needs to parse args.
            if not weekday then
                -- TODO: Maybe prompt for weekday if not provided, or use current day?
                -- For now, let's make it clear it needs parameters.
                print('Error: Time.clearDay requires weekday.')
                -- Example of how to prompt if desired:
                -- ui.select({hours=false}, function(_, wd, pr, fl) core.clearDay(wd, pr, fl) end)
                return
            end
            core.clearDay(weekday)
        end,
        TimePause = core.TimePause,
        TimeResume = core.TimeResume,
        TimeStop = function()
            core.TimeStop()

            local notify = require('notify')

            local startTime = os.time()
            local year_str = os.date('%Y', startTime)
            local week_str = os.date('%W', startTime)

            notify({
                'Gesamt: '
                    .. string.format(
                        '%.2f',
                        config_module.obj.content['data'][year_str][week_str].summary.overhour
                    )
                    .. ' Stunden',
            }, 'info', { title = 'TimeTracking - Stop' })
        end,
        set = function()
            ui.select(
                {}, -- Default opts
                function(hours, weekday, project, file)
                    core.setTime({ time = hours, weekday = weekday, project = project, file = file })
                end
            )
        end,
        setTime = core.setTime,
        setIllDay = function(weekday) -- Matching core.setIllDay signature change
            if not weekday then
                ui.select({ hours = false, project = false, file = false }, function(_, wd)
                    core.setIllDay(wd)
                end)
            else
                core.setIllDay(weekday) -- Pass through if provided
            end
        end,
        setHoliday = function(weekday) -- Alias for setIllDay
            if not weekday then
                ui.select({ hours = false, project = false, file = false }, function(_, wd)
                    core.setIllDay(wd)
                end)
            else
                core.setIllDay(weekday) -- Pass through if provided
            end
        end,
        edit = function()
            ui.editTimeEntryDialog(function() end)
        end,
        addManual = function()
            ui.addManualTimeEntryDialog(function() end)
        end,
        listEntries = function(opts)
            return core.listTimeEntries(opts or {})
        end,
        calculate = function(opts)
            -- The core.calculate function doesn't save automatically.
            -- The original init.lua's calculate did save.
            -- Decide if this public calculate should also save.
            -- For consistency with original, let's add init and save.
            core.init({
                path = config_module.obj.path,
                hoursPerWeekday = config_module.obj.content['hoursPerWeekday'],
            })
            core.calculate(opts)
            utils.save() -- Assuming utils.save uses the shared config_module.obj
            return config_module.obj -- Return the data object
        end,
        export = function(opts)
            return core.exportTimeData(opts or {})
        end,
    }
    return config_obj -- Return the config_obj obtained from core.init
end

-- Functions returned by the module for direct use (e.g., by other plugins or specific keymaps)
M.TimeStart = core.TimeStart
M.TimeStop = core.TimeStop
M.TimePause = core.TimePause
M.TimeResume = core.TimeResume
M.setIllDay = core.setIllDay
M.setHoliday = core.setIllDay -- Alias
M.addTime = core.addTime
M.subtractTime = core.subtractTime
M.setTime = core.setTime
M.clearDay = core.clearDay
M.isPaused = core.isPaused
M.listTimeEntries = core.listTimeEntries
M.editTimeEntry = core.editTimeEntry
M.deleteTimeEntry = core.deleteTimeEntry
M.addManualTimeEntry = core.addManualTimeEntry
M.editTimeEntryDialog = function()
    ui.editTimeEntryDialog(function() end)
end
M.addManualTimeEntryDialog = function()
    ui.addManualTimeEntryDialog(function() end)
end
M.calculate = function(opts) -- Match the public Time.calculate behavior
    -- core.init({
    --     path = config_module.obj.path,
    --     hoursPerWeekday = config_module.obj.content['hoursPerWeekday'],
    -- }) -- THIS CALL IS REMOVED/COMMENTED OUT
    core.calculate(opts)
    utils.save()
    return config_module.obj
end
M.exportTimeData = core.exportTimeData -- Expose the export function
M.weekdays = config_module.weekdayNumberMap -- Expose weekday map
M.get_config = core.get_config -- Expose the get_config function

return M
