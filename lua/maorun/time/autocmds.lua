local core = require('maorun.time.core')
local utils = require('maorun.time.utils') -- For get_project_and_file_info

local M = {}

-- Simple state tracking to avoid redundant calls
local last_context = {
    project = nil,
    file = nil,
}

-- Helper to get normalized project/file info
local function get_normalized_info(buf)
    local info = utils.get_project_and_file_info(buf)
    if info then
        return info.project, info.file
    else
        return 'default_project', 'default_file'
    end
end

-- Check if context has actually changed
local function has_context_changed(project, file)
    return last_context.project ~= project or last_context.file ~= file
end

-- Update context tracking
local function update_context(project, file)
    last_context.project = project
    last_context.file = file
end

-- Start tracking with context switching
local function start_tracking(project, file)
    if has_context_changed(project, file) then
        -- Stop previous context if it exists and is different
        if
            last_context.project and (last_context.project ~= project or last_context.file ~= file)
        then
            core.TimeStop({ project = last_context.project, file = last_context.file })
        end

        -- Start new context
        core.TimeStart({ project = project, file = file })
        update_context(project, file)
    end
end

function M.setup_autocmds()
    local timeGroup = vim.api.nvim_create_augroup('Maorun-Time', { clear = true })

    vim.api.nvim_create_autocmd('VimEnter', {
        group = timeGroup,
        desc = 'Start Timetracking on VimEnter for the initial buffer',
        callback = function()
            local current_buf = vim.api.nvim_get_current_buf()
            local project, file = get_normalized_info(current_buf)
            core.TimeStart({ project = project, file = file })
            update_context(project, file)
        end,
    })

    vim.api.nvim_create_autocmd('BufEnter', {
        group = timeGroup,
        desc = 'Start Timetracking when entering a buffer (smart context switching)',
        callback = function(args)
            local project, file = get_normalized_info(args.buf)
            start_tracking(project, file)
        end,
    })

    vim.api.nvim_create_autocmd('FocusGained', {
        group = timeGroup,
        desc = 'Resume Timetracking when Neovim gains focus',
        callback = function()
            local current_buf = vim.api.nvim_get_current_buf()
            local project, file = get_normalized_info(current_buf)
            -- Only start if no context is currently tracked (focus was truly lost)
            if not last_context.project then
                core.TimeStart({ project = project, file = file })
                update_context(project, file)
            end
        end,
    })

    -- Note: Removed BufLeave autocmd to avoid issues with splits/tabs
    -- Time stopping now only happens when switching to different context or on VimLeave

    vim.api.nvim_create_autocmd('VimLeavePre', {
        group = timeGroup,
        desc = 'End Timetracking on VimLeave',
        callback = function()
            if last_context.project then
                core.TimeStop({ project = last_context.project, file = last_context.file })
                update_context(nil, nil)
            end
        end,
    })
end

return M
