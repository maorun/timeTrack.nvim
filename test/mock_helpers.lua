local M = {}

-- Mock for vim.ui.input
local input_mock = {
    prompts_called_with = {},
    texts_to_return = {}, -- Queue of texts
    current_text_idx = 1,
    was_called_count = 0,
}

function input_mock:reset()
    self.prompts_called_with = {}
    self.texts_to_return = {}
    self.current_text_idx = 1
    self.was_called_count = 0
end

function input_mock:set_texts_to_return(texts) -- Expects a table (queue)
    -- self:reset() -- Reset is good, but might be better to do it in teardown or explicitly in test setup
    self.texts_to_return = texts
    self.current_text_idx = 1 -- Reset index for new texts
end

function input_mock:get_prompts_called_with()
    return self.prompts_called_with
end

function input_mock:get_call_count()
    return self.was_called_count
end

local original_vim_ui_input = vim.ui.input
vim.ui.input = function(opts, callback)
    input_mock.was_called_count = input_mock.was_called_count + 1
    table.insert(input_mock.prompts_called_with, opts.prompt)

    local text_to_return
    if input_mock.current_text_idx <= #input_mock.texts_to_return then
        text_to_return = input_mock.texts_to_return[input_mock.current_text_idx]
        input_mock.current_text_idx = input_mock.current_text_idx + 1
    else
        text_to_return = nil -- Default if queue is exhausted
    end

    if callback then
        callback(text_to_return)
    else
        return text_to_return
    end
end
M.input_mock = input_mock

-- Mock for vim.ui.select
local select_mock = {
    prompt = nil,
    items = nil,
    item_to_return = nil,
    was_called = false,
}

function select_mock:reset()
    self.prompt = nil
    self.items = nil
    self.item_to_return = nil
    self.was_called = false
end

function select_mock:set_item_to_return(item)
    -- self:reset()
    self.item_to_return = item
end

function select_mock:get_prompt()
    return self.prompt
end

function select_mock:get_items()
    return self.items
end

function select_mock:was_called_flag()
    local called = self.was_called
    -- self.was_called = false -- Resetting here might hide multiple calls if not checked carefully
    return called
end

local original_vim_ui_select = vim.ui.select
vim.ui.select = function(items, opts, callback)
    select_mock.items = items
    select_mock.prompt = opts.prompt
    select_mock.was_called = true
    if callback then
        callback(select_mock.item_to_return)
    else
        return select_mock.item_to_return
    end
end
M.select_mock = select_mock

-- Mock for require('maorun.time.weekday_select')
local weekday_select_mock_module_api = {
    show_called_with_options = nil,
    selected_weekday_to_return = nil,
    was_called = false,
}

function weekday_select_mock_module_api:reset()
    self.show_called_with_options = nil
    self.selected_weekday_to_return = nil
    self.was_called = false
end

function weekday_select_mock_module_api:set_selected_weekday(weekday)
    -- self:reset()
    self.selected_weekday_to_return = weekday
end

function weekday_select_mock_module_api:get_show_called_with_options()
    return self.show_called_with_options
end

function weekday_select_mock_module_api:was_called_flag()
    local called = self.was_called
    -- self.was_called = false
    return called
end

local actual_mock_weekday_select_module = {}
actual_mock_weekday_select_module.show = function(options, callback)
    weekday_select_mock_module_api.show_called_with_options = options
    weekday_select_mock_module_api.was_called = true
    if callback then
        callback(weekday_select_mock_module_api.selected_weekday_to_return)
    end
    return weekday_select_mock_module_api.selected_weekday_to_return
end

local original_weekday_select_module_val = package.loaded['maorun.time.weekday_select']
package.loaded['maorun.time.weekday_select'] = actual_mock_weekday_select_module
M.weekday_select_mock = weekday_select_mock_module_api

-- Mock for _G.notify
local notify_mock = {
    message = nil,
    level = nil,
    opts = nil,
    was_called = false,
    all_calls = {}, -- To capture multiple calls if needed
}

function notify_mock:reset()
    self.message = nil
    self.level = nil
    self.opts = nil
    self.was_called = false
    self.all_calls = {}
end

function notify_mock:get_message()
    return self.message
end
function notify_mock:get_level()
    return self.level
end
function notify_mock:get_opts()
    return self.opts
end
function notify_mock:get_all_calls()
    return self.all_calls
end

function notify_mock:was_called_flag()
    local called = self.was_called
    -- self.was_called = false
    return called
end

local original_notify = _G.notify
_G.notify = function(message, level, opts)
    notify_mock.message = message
    notify_mock.level = level
    notify_mock.opts = opts
    notify_mock.was_called = true
    table.insert(notify_mock.all_calls, { message = message, level = level, opts = opts })
end
M.notify_mock = notify_mock

-- Teardown function to restore original functions and reset mocks
function M.teardown_all_mocks()
    vim.ui.input = original_vim_ui_input
    vim.ui.select = original_vim_ui_select
    _G.notify = original_notify

    if original_weekday_select_module_val then
        package.loaded['maorun.time.weekday_select'] = original_weekday_select_module_val
    else
        package.loaded['maorun.time.weekday_select'] = nil -- Remove if it wasn't there originally
    end

    M.input_mock:reset()
    M.select_mock:reset()
    M.weekday_select_mock:reset()
    M.notify_mock:reset()
end

-- Function to reset was_called flags on mocks that have it for convenience in tests
function M.reset_all_was_called_flags()
    if M.input_mock.was_called_count then
        M.input_mock.was_called_count = 0
    end -- Specific to input mock
    if M.select_mock.was_called then
        M.select_mock.was_called = false
    end
    if M.weekday_select_mock.was_called then
        M.weekday_select_mock.was_called = false
    end
    if M.notify_mock.was_called then
        M.notify_mock.was_called = false
    end
    if M.notify_mock.all_calls then
        M.notify_mock.all_calls = {}
    end
end

return M
