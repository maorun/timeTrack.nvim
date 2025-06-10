local Path = require('plenary.path')
local config_module = require('maorun.time.config') -- Adjusted path

local M = {}

function M.save()
    Path:new(config_module.obj.path):write(vim.fn.json_encode(config_module.obj.content), 'w')
end

function M.get_project_and_file_info(buffer_path_or_bufnr)
    local filepath_str
    if type(buffer_path_or_bufnr) == 'number' then
        filepath_str = vim.api.nvim_buf_get_name(buffer_path_or_bufnr)
    elseif type(buffer_path_or_bufnr) == 'string' then
        filepath_str = buffer_path_or_bufnr
    else
        return nil -- Invalid input type
    end

    if filepath_str == nil or filepath_str == '' then
        return nil
    end

    local file_path_obj = Path:new(filepath_str)
    if not file_path_obj then -- Ensure Path object was created
        return nil
    end

    local file_name = file_path_obj.name
    if file_name == nil or file_name == '' then
        return nil -- No valid file name (e.g. a directory path was passed)
    end

    local project_name = nil
    local current_dir = file_path_obj:parent()

    -- Loop upwards to find .git directory or stop at root
    while current_dir and current_dir:absolute() ~= '' and current_dir:absolute() ~= Path:new('/'):absolute() do
        if current_dir:joinpath('.git'):exists() then
            project_name = current_dir.name
            break
        end
        local parent_dir = current_dir:parent()
        -- Break if parent is the same as current (indicates root or error)
        if parent_dir and parent_dir:absolute() == current_dir:absolute() then
            break
        end
        current_dir = parent_dir
        if not current_dir then -- Safety break if parent() returns nil unexpectedly
            break
        end
    end

    if project_name == nil then
        -- Fallback: use parent directory name if .git not found
        local parent_dir_obj = file_path_obj:parent()
        if parent_dir_obj and parent_dir_obj.name and parent_dir_obj.name ~= '' then
            if parent_dir_obj:is_root() or parent_dir_obj:absolute() == Path:new('/'):absolute() then
                project_name = '_root_' -- Or "filesystem_root"
            else
                project_name = parent_dir_obj.name
            end
        else
            project_name = 'default_project' -- Ultimate fallback
        end
    end

    -- Ensure file_name is not nil or empty before returning
    if file_name and file_name ~= '' then
        return { project = project_name, file = file_name }
    else
        -- This case should ideally be caught earlier, but as a safeguard:
        return nil
    end
end

-- calculate an average over the hoursPerWeekday
function M.calculateAverage()
    local sum = 0
    local count = 0
    for _, value in pairs(config_module.config.hoursPerWeekday) do
        sum = sum + value
        count = count + 1
    end
    if count == 0 then return 0 end -- Avoid division by zero
    return sum / count
end

return M
