local core = require('maorun.time.core')
local utils = require('maorun.time.utils') -- For get_project_and_file_info

local M = {}

function M.setup_autocmds()
    local timeGroup = vim.api.nvim_create_augroup('Maorun-Time', { clear = true })

    vim.api.nvim_create_autocmd('VimEnter', {
        group = timeGroup,
        desc = 'Start Timetracking on VimEnter for the initial buffer',
        callback = function()
            local current_buf = vim.api.nvim_get_current_buf()
            local info = utils.get_project_and_file_info(current_buf)
            if info then
                core.TimeStart({ project = info.project, file = info.file })
            else
                core.TimeStart() -- Use defaults if no info
            end
        end,
    })

    vim.api.nvim_create_autocmd('BufEnter', {
        group = timeGroup,
        desc = 'Start Timetracking when entering a buffer',
        callback = function(args)
            local info = utils.get_project_and_file_info(args.buf)
            if info then
                core.TimeStart({ project = info.project, file = info.file })
            else
                core.TimeStart()
            end
        end,
    })

    vim.api.nvim_create_autocmd('FocusGained', {
        group = timeGroup,
        desc = 'Start Timetracking when Neovim gains focus',
        callback = function()
            local current_buf = vim.api.nvim_get_current_buf()
            local info = utils.get_project_and_file_info(current_buf)
            if info then
                core.TimeStart({ project = info.project, file = info.file })
            else
                core.TimeStart()
            end
        end,
    })

    vim.api.nvim_create_autocmd('FocusLost', {
        group = timeGroup,
        desc = 'Stop Timetracking when Neovim loses focus',
        callback = function()
            local current_buf = vim.api.nvim_get_current_buf()
            local info = utils.get_project_and_file_info(current_buf)
            if info then
                core.TimeStop({ project = info.project, file = info.file })
            else
                core.TimeStop()
            end
        end,
    })

    vim.api.nvim_create_autocmd('BufLeave', {
        group = timeGroup,
        desc = 'Stop Timetracking for the buffer being left',
        callback = function(args)
            local info = utils.get_project_and_file_info(args.buf)
            if info then
                core.TimeStop({ project = info.project, file = info.file })
            else
                core.TimeStop()
            end
        end,
    })

    vim.api.nvim_create_autocmd('VimLeavePre', {
        group = timeGroup,
        desc = 'End Timetracking on VimLeave (general stop)',
        callback = function(args)
            local info = utils.get_project_and_file_info(args.buf)
            if info then
                core.TimeStop({ project = info.project, file = info.file })
            else
                core.TimeStop()
            end
        end,
    })
end

return M
