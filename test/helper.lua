-- Combined helper and mock functionalities

-- Content from original test/mock_helpers.lua
local mock_helpers_content = {} -- Use a table to namespace mock helper internals if needed, or keep them local

-- Mock for vim.ui.input
local input_mock_ctrl =
    { -- Renamed from input_mock to avoid conflict if helper.lua had a var of same name
        prompts_called_with = {},
        texts_to_return = {},
        current_text_idx = 1,
        was_called_count = 0,
    }

function input_mock_ctrl:reset()
    self.prompts_called_with = {}
    self.texts_to_return = {}
    self.current_text_idx = 1
    self.was_called_count = 0
end

function input_mock_ctrl:set_texts_to_return(texts)
    self.texts_to_return = texts
    self.current_text_idx = 1
end

function input_mock_ctrl:get_prompts_called_with()
    return self.prompts_called_with
end

function input_mock_ctrl:get_call_count()
    return self.was_called_count
end

local original_vim_ui_input = vim.ui.input
vim.ui.input = function(opts, callback)
    input_mock_ctrl.was_called_count = input_mock_ctrl.was_called_count + 1
    table.insert(input_mock_ctrl.prompts_called_with, opts.prompt)

    local text_to_return
    if input_mock_ctrl.current_text_idx <= #input_mock_ctrl.texts_to_return then
        text_to_return = input_mock_ctrl.texts_to_return[input_mock_ctrl.current_text_idx]
        input_mock_ctrl.current_text_idx = input_mock_ctrl.current_text_idx + 1
    else
        text_to_return = nil
    end

    if callback then
        callback(text_to_return)
    else
        return text_to_return
    end
end
mock_helpers_content.input_mock = input_mock_ctrl -- Store control object

-- Mock for vim.ui.select
local select_mock_ctrl = {
    prompt = nil,
    items = nil,
    item_to_return = nil,
    was_called = false,
}

function select_mock_ctrl:reset()
    self.prompt = nil
    self.items = nil
    self.item_to_return = nil
    self.was_called = false
end

function select_mock_ctrl:set_item_to_return(item)
    self.item_to_return = item
end

function select_mock_ctrl:get_prompt()
    return self.prompt
end
function select_mock_ctrl:get_items()
    return self.items
end
function select_mock_ctrl:was_called_flag()
    local called = self.was_called
    return called
end

local original_vim_ui_select = vim.ui.select
vim.ui.select = function(items, opts, callback)
    select_mock_ctrl.items = items
    select_mock_ctrl.prompt = opts.prompt
    select_mock_ctrl.was_called = true
    if callback then
        callback(select_mock_ctrl.item_to_return)
    else
        return select_mock_ctrl.item_to_return
    end
end
mock_helpers_content.select_mock = select_mock_ctrl

-- Mock for require('maorun.time.weekday_select')
local weekday_select_mock_api_ctrl = {
    show_called_with_options = nil,
    selected_weekday_to_return = nil,
    was_called = false,
}

function weekday_select_mock_api_ctrl:reset()
    self.show_called_with_options = nil
    self.selected_weekday_to_return = nil
    self.was_called = false
end

function weekday_select_mock_api_ctrl:set_selected_weekday(weekday)
    self.selected_weekday_to_return = weekday
end

function weekday_select_mock_api_ctrl:get_show_called_with_options()
    return self.show_called_with_options
end
function weekday_select_mock_api_ctrl:was_called_flag()
    local called = self.was_called
    return called
end

local actual_mock_weekday_select_module = {}
actual_mock_weekday_select_module.show = function(options, callback)
    weekday_select_mock_api_ctrl.show_called_with_options = options
    weekday_select_mock_api_ctrl.was_called = true
    if callback then
        callback(weekday_select_mock_api_ctrl.selected_weekday_to_return)
    end
    return weekday_select_mock_api_ctrl.selected_weekday_to_return
end

local original_weekday_select_module_val = package.loaded['maorun.time.weekday_select']
package.loaded['maorun.time.weekday_select'] = actual_mock_weekday_select_module
mock_helpers_content.weekday_select_mock = weekday_select_mock_api_ctrl

-- Mock for _G.notify
local notify_mock_ctrl = {
    message = nil,
    level = nil,
    opts = nil,
    was_called = false,
    all_calls = {},
}

function notify_mock_ctrl:reset()
    self.message = nil
    self.level = nil
    self.opts = nil
    self.was_called = false
    self.all_calls = {}
end

function notify_mock_ctrl:get_message()
    return self.message
end
function notify_mock_ctrl:get_level()
    return self.level
end
function notify_mock_ctrl:get_opts()
    return self.opts
end
function notify_mock_ctrl:get_all_calls()
    return self.all_calls
end
function notify_mock_ctrl:was_called_flag()
    local called = self.was_called
    return called
end

local original_notify = _G.notify
_G.notify = function(message, level, opts)
    notify_mock_ctrl.message = message
    notify_mock_ctrl.level = level
    notify_mock_ctrl.opts = opts
    notify_mock_ctrl.was_called = true
    table.insert(notify_mock_ctrl.all_calls, { message = message, level = level, opts = opts })
end
mock_helpers_content.notify_mock = notify_mock_ctrl

-- Teardown function to restore original functions and reset mocks
function mock_helpers_content.teardown_all_mocks()
    vim.ui.input = original_vim_ui_input
    vim.ui.select = original_vim_ui_select
    _G.notify = original_notify

    if original_weekday_select_module_val then
        package.loaded['maorun.time.weekday_select'] = original_weekday_select_module_val
    else
        package.loaded['maorun.time.weekday_select'] = nil
    end

    mock_helpers_content.input_mock:reset()
    mock_helpers_content.select_mock:reset()
    mock_helpers_content.weekday_select_mock:reset()
    mock_helpers_content.notify_mock:reset()
end

-- Function to reset was_called flags
function mock_helpers_content.reset_all_was_called_flags()
    if mock_helpers_content.input_mock.was_called_count then
        mock_helpers_content.input_mock.was_called_count = 0
    end
    if mock_helpers_content.select_mock.was_called then
        mock_helpers_content.select_mock.was_called = false
    end
    if mock_helpers_content.weekday_select_mock.was_called then
        mock_helpers_content.weekday_select_mock.was_called = false
    end
    if mock_helpers_content.notify_mock.was_called then
        mock_helpers_content.notify_mock.was_called = false
    end
    if mock_helpers_content.notify_mock.all_calls then
        mock_helpers_content.notify_mock.all_calls = {}
    end
end

-- End of content from original test/mock_helpers.lua

-- Content from original test/helper.lua
local H = {} -- This will be the final returned table

local function join_paths(...)
    local result = table.concat({ ... }, '/')
    return result
end
H.join_paths = join_paths -- Add to returned table if it's generally useful, or keep local

local function test_dir()
    local data_path = vim.fn.stdpath('data')
    -- Ensure 'test' directory for dependencies is distinct from project's own test dir if necessary
    -- For now, assume it's fine or adjust path as needed.
    local package_root = join_paths(data_path, 'maorun_test_dependencies')
    vim.fn.mkdir(package_root, 'p') -- Ensure directory exists
    return package_root
end
-- H.test_dir = test_dir -- Expose if needed

function H.notify_dep()
    local package_root = test_dir()
    local notify_install_path = join_paths(package_root, 'nvim-notify') -- Changed from 'notify' to 'nvim-notify' for clarity
    vim.opt.runtimepath:prepend(notify_install_path) -- Prepend to ensure it's found
    if vim.fn.isdirectory(notify_install_path) ~= 1 then
        print('Cloning nvim-notify dependency...')
        local clone_result = vim.fn.system({
            'git',
            'clone',
            '--depth',
            '1', -- Shallow clone
            'https://github.com/rcarriga/nvim-notify',
            notify_install_path,
        })
        if vim.v.shell_error ~= 0 then
            print('Error cloning nvim-notify: ' .. clone_result)
        else
            print('nvim-notify cloned successfully.')
        end
    else
        print('nvim-notify dependency already present.')
    end
end

function H.plenary_dep()
    local package_root = test_dir()
    local plenary_install_path = join_paths(package_root, 'plenary.nvim') -- Changed from 'plenary' to 'plenary.nvim'
    vim.opt.runtimepath:prepend(plenary_install_path) -- Prepend
    if vim.fn.isdirectory(plenary_install_path) ~= 1 then
        print('Cloning plenary.nvim dependency...')
        local clone_result = vim.fn.system({
            'git',
            'clone',
            '--depth',
            '1', -- Shallow clone
            'https://github.com/nvim-lua/plenary.nvim',
            plenary_install_path,
        })
        if vim.v.shell_error ~= 0 then
            print('Error cloning plenary.nvim: ' .. clone_result)
        else
            print('plenary.nvim cloned successfully.')
        end
    else
        print('plenary.nvim dependency already present.')
    end
end

-- Merge mock helper functionalities into the final H table
for k, v in pairs(mock_helpers_content) do
    H[k] = v
end

return H
