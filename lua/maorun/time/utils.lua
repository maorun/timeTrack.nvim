local Path = require('plenary.path')
local config_module = require('maorun.time.config') -- Adjusted path

local M = {}

function M.save()
    local file_path = config_module.obj.path
    local path_obj = Path:new(file_path)
    local temp_path = file_path .. '.tmp'
    local temp_obj = Path:new(temp_path)

    -- Use atomic write pattern to prevent file corruption during concurrent access
    -- 1. Write to temporary file
    -- 2. Rename temporary file to target file (atomic operation on most filesystems)

    temp_obj:write(vim.fn.json_encode(config_module.obj.content), 'w')

    -- Atomic rename (this is the key to preventing corruption)
    if temp_obj:exists() then
        -- Use os.rename for atomic operation
        local success = os.rename(temp_path, file_path)
        if not success then
            -- Fallback: if rename fails, try direct write and remove temp
            path_obj:write(vim.fn.json_encode(config_module.obj.content), 'w')
            if temp_obj:exists() then
                temp_obj:rm()
            end
        end
    else
        -- Fallback to direct write if temp file creation failed
        path_obj:write(vim.fn.json_encode(config_module.obj.content), 'w')
    end
end

-- Backup of the original save function for testing purposes
function M.save_without_merge()
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

    local file_name = file_path_obj.filename
    if file_name == nil or file_name == '' then
        return nil -- No valid file name (e.g. a directory path was passed)
    end

    local project_name = nil
    local current_dir = file_path_obj:parent()
    local last_sensible_parent = file_path_obj:parent() -- Initialize with the first parent

    -- Loop upwards to find .git directory
    while current_dir do
        if current_dir:joinpath('.git'):exists() then
            project_name = current_dir.filename
            break
        end
        if current_dir.filename == '/' then
            break
        end
        last_sensible_parent = current_dir -- Update before going higher
        current_dir = current_dir:parent()
    end

    if project_name == nil then
        -- Fallback logic using last_sensible_parent
        if last_sensible_parent then
            if last_sensible_parent.filename == '/' then
                project_name = '_root_'
            elseif last_sensible_parent.filename and last_sensible_parent.filename ~= '' then
                project_name = last_sensible_parent.filename
            else
                project_name = 'default_project'
            end
        else
            project_name = 'default_project'
        end
    end

    if project_name == '' then
        project_name = '_root_'
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
    if count == 0 then
        return 0
    end -- Avoid division by zero
    return sum / count
end

return M
