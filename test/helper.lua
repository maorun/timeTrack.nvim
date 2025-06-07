local M = {}

-- Store original functions for cleanup
local original_functions = {}

--- Mocks Neovim API calls.
-- @param api_name The name of the API to mock (e.g., "nvim_buf_get_name").
-- @param mock_value The value or function to return when the API is called.
function M.mock_nvim_api(api_name, mock_value)
    local api_parts = {}
    for part in string.gmatch(api_name, '[^%.]+') do
        table.insert(api_parts, part)
    end

    local base = _G
    for i = 1, #api_parts - 1 do
        base = base[api_parts[i]]
        if not base then
            error('Invalid API path: ' .. api_name)
        end
    end

    local func_name = api_parts[#api_parts]
    original_functions[api_name] = base[func_name]

    if type(mock_value) == 'function' then
        base[func_name] = mock_value
    else
        base[func_name] = function(...)
            return mock_value
        end
    end
end

--- Generic function to mock other Lua functions.
-- @param module_name The global name of the module (e.g., "my_module").
-- @param func_name The name of the function to mock.
-- @param mock_implementation The function to replace the original function with.
function M.mock_function(module_name, func_name, mock_implementation)
    local module = _G[module_name]
    if not module then
        error('Module not found: ' .. module_name)
    end

    local key = module_name .. '.' .. func_name
    original_functions[key] = module[func_name]
    module[func_name] = mock_implementation
end

--- Restores all mocked functions to their original implementations.
function M.restore_mocks()
    for key, original_func in pairs(original_functions) do
        local parts = {}
        for part in string.gmatch(key, '[^%.]+') do
            table.insert(parts, part)
        end

        if #parts == 2 then -- Assuming "module.func"
            local module_name, func_name = parts[1], parts[2]
            if _G[module_name] then
                _G[module_name][func_name] = original_func
            end
        elseif #parts > 2 and parts[1] == 'vim' and parts[2] == 'api' then -- Assuming "vim.api.something"
            local base = _G
            for i = 1, #parts - 1 do
                if base[parts[i]] then
                    base = base[parts[i]]
                else
                    base = nil -- path no longer exists
                    break
                end
            end
            if base and parts[#parts] then
                base[parts[#parts]] = original_func
            end
        end
        original_functions[key] = nil
    end
end

-- Teardown function to be called after each test file or suite
-- For busted, you might call this in a `after_each` or `teardown` block.
function M.teardown()
    M.restore_mocks()
end

return M
