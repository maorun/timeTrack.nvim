-- Define global configuration variables with defaults if not already set
vim.g.timetrack_inactivity_detection_enabled = vim.g.timetrack_inactivity_detection_enabled == nil and false or vim.g.timetrack_inactivity_detection_enabled
vim.g.timetrack_inactivity_timeout_minutes = vim.g.timetrack_inactivity_timeout_minutes == nil and 15 or vim.g.timetrack_inactivity_timeout_minutes

-- Require the time tracking module
local timeTrack = require('maorun.time')

-- Call the setup function of the timeTrack module.
-- The module's setup function will read the vim.g variables.
timeTrack.setup({})

-- User command to toggle inactivity detection
vim.api.nvim_create_user_command('TimeTrackToggleInactivity', function()
    -- Toggle the global variable
    vim.g.timetrack_inactivity_detection_enabled = not vim.g.timetrack_inactivity_detection_enabled

    -- Re-run setup to apply the change. The setup function in maorun.time
    -- is expected to read the updated vim.g variable and call
    -- enable_inactivity_tracking() or disable_inactivity_tracking() accordingly.
    timeTrack.setup({})

    if vim.g.timetrack_inactivity_detection_enabled then
        vim.notify("Inactivity detection enabled.", vim.log.levels.INFO, {title = "TimeTrack"})
    else
        vim.notify("Inactivity detection disabled.", vim.log.levels.INFO, {title = "TimeTrack"})
    end
end, { desc = "Toggle inactivity detection for TimeTrack.nvim" })

-- User command to set inactivity timeout
vim.api.nvim_create_user_command('TimeTrackSetInactivityTimeout', function(opts)
    local minutes = tonumber(opts.args)
    if minutes and minutes > 0 then
        vim.g.timetrack_inactivity_timeout_minutes = minutes

        -- Re-run setup to apply the new timeout. The setup function
        -- in maorun.time will pick up the updated vim.g variable.
        timeTrack.setup({})

        vim.notify("Inactivity timeout set to " .. minutes .. " minutes.", vim.log.levels.INFO, {title = "TimeTrack"})
    else
        vim.notify("Usage: TimeTrackSetInactivityTimeout <minutes>", vim.log.levels.ERROR, {title = "TimeTrack"})
    end
end, { nargs = 1, desc = "Set inactivity timeout for TimeTrack.nvim (minutes)" })
