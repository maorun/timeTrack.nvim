local core = require('maorun.time.core')
local utils = require('maorun.time.utils') -- For get_project_and_file_info

local M = {}

function M.setup_autocmds()
    local timeGroup = vim.api.nvim_create_augroup('Maorun-Time', { clear = true })

    vim.api.nvim_create_autocmd('VimEnter', {
        group = timeGroup,
        desc = 'Attempt to acquire lock and start Timetracking on VimEnter for the initial buffer',
        callback = function()
            if core.acquire_instance_lock() then
                -- vim.notify("VimEnter: Acquired lock, starting tracking.", vim.log.levels.INFO)
                local current_buf = vim.api.nvim_get_current_buf()
                local info = utils.get_project_and_file_info(current_buf)
                if info then
                    core.TimeStart({ project = info.project, file = info.file })
                else
                    core.TimeStart() -- Use defaults if no info
                end
            else
                -- vim.notify("VimEnter: Did not acquire lock.", vim.log.levels.INFO)
            end
        end,
    })

    vim.api.nvim_create_autocmd('BufEnter', {
        group = timeGroup,
        desc = 'Start Timetracking when entering a buffer, if instance has lock',
        callback = function(args)
            if core.has_instance_lock() then
                -- vim.notify("BufEnter: Has lock, starting tracking for buffer.", vim.log.levels.INFO)
                local info = utils.get_project_and_file_info(args.buf)
                if info then
                    core.TimeStart({ project = info.project, file = info.file })
                else
                    core.TimeStart()
                end
            else
                -- vim.notify("BufEnter: No lock, not tracking for buffer.", vim.log.levels.INFO)
            end
        end,
    })

    vim.api.nvim_create_autocmd('FocusGained', {
        group = timeGroup,
        desc = 'Start Timetracking when Neovim gains focus, if instance has or can acquire lock',
        callback = function()
            local acquired_now = false
            if not core.has_instance_lock() then
                if core.acquire_instance_lock() then
                    -- vim.notify("FocusGained: Acquired lock now.", vim.log.levels.INFO)
                    acquired_now = true
                else
                    -- vim.notify("FocusGained: Still no lock, not starting tracking.", vim.log.levels.INFO)
                    return -- Did not acquire lock, do nothing
                end
            end
            -- If we have the lock (either previously or acquired now)
            if core.has_instance_lock() then
                -- vim.notify("FocusGained: Has lock, starting tracking.", vim.log.levels.INFO)
                local current_buf = vim.api.nvim_get_current_buf()
                local info = utils.get_project_and_file_info(current_buf)
                if info then
                    core.TimeStart({ project = info.project, file = info.file })
                else
                    core.TimeStart()
                end
            end
        end,
    })

    vim.api.nvim_create_autocmd('BufLeave', {
        group = timeGroup,
        desc = 'Stop Timetracking for the buffer being left, if instance has lock',
        callback = function(args)
            if core.has_instance_lock() then
                -- vim.notify("BufLeave: Has lock, stopping tracking for buffer.", vim.log.levels.INFO)
                local info = utils.get_project_and_file_info(args.buf)
                if info then
                    core.TimeStop({ project = info.project, file = info.file })
                else
                    core.TimeStop()
                end
            else
                -- vim.notify("BufLeave: No lock, not stopping tracking for buffer.", vim.log.levels.INFO)
            end
        end,
    })

    vim.api.nvim_create_autocmd('VimLeavePre', {
        group = timeGroup,
        desc = 'End Timetracking on VimLeave and release lock if owned',
        callback = function(args)
            if core.has_instance_lock() then
                -- vim.notify("VimLeavePre: Has lock, stopping tracking.", vim.log.levels.INFO)
                local info = utils.get_project_and_file_info(args.buf) -- args.buf might be -1 or invalid here
                -- It's safer to just call a general TimeStop if needed, or ensure TimeStop handles nil gracefully.
                -- For now, let's assume the last active buffer's info is what we want, or default.
                -- The current TimeStop defaults project/file if not provided, which is fine.
                if info and info.project and info.file then
                     core.TimeStop({ project = info.project, file = info.file })
                else
                     core.TimeStop() -- Stop with default/last known if any
                end
            else
                -- vim.notify("VimLeavePre: No lock, not stopping tracking.", vim.log.levels.INFO)
            end
            -- Always attempt to release the lock; release_instance_lock will check ownership.
            -- vim.notify("VimLeavePre: Releasing lock.", vim.log.levels.INFO)
            core.release_instance_lock()
        end,
    })
end

return M
