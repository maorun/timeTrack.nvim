-- CLI compatibility layer for Neovim-specific APIs
-- This module provides CLI-compatible versions of Neovim APIs

local M = {}

-- JSON handling
M.json = {}

-- Simple JSON encoder (basic implementation)
function M.json.encode(obj)
    if type(obj) == 'nil' then
        return 'null'
    elseif type(obj) == 'boolean' then
        return obj and 'true' or 'false'
    elseif type(obj) == 'number' then
        return tostring(obj)
    elseif type(obj) == 'string' then
        -- Basic string escaping
        local escaped = obj:gsub('\\', '\\\\')
            :gsub('"', '\\"')
            :gsub('\n', '\\n')
            :gsub('\r', '\\r')
            :gsub('\t', '\\t')
        return '"' .. escaped .. '"'
    elseif type(obj) == 'table' then
        -- Check if it's an array
        local is_array = true
        local max_index = 0
        for k, v in pairs(obj) do
            if type(k) ~= 'number' or k <= 0 or k ~= math.floor(k) then
                is_array = false
                break
            end
            max_index = math.max(max_index, k)
        end

        if is_array then
            -- Array encoding
            local parts = {}
            for i = 1, max_index do
                parts[i] = M.json.encode(obj[i])
            end
            return '[' .. table.concat(parts, ',') .. ']'
        else
            -- Object encoding
            local parts = {}
            for k, v in pairs(obj) do
                table.insert(parts, M.json.encode(tostring(k)) .. ':' .. M.json.encode(v))
            end
            return '{' .. table.concat(parts, ',') .. '}'
        end
    else
        return 'null'
    end
end

-- Simple JSON decoder - using external library if available, fallback to basic parsing
function M.json.decode(str)
    -- Try to use an external JSON library if available
    local ok, json_lib = pcall(require, 'json')
    if ok and json_lib.decode then
        return json_lib.decode(str)
    end

    -- Try dkjson as fallback
    ok, json_lib = pcall(require, 'dkjson')
    if ok and json_lib.decode then
        return json_lib.decode(str)
    end

    -- Basic JSON parsing (very simple, only for basic structures)
    -- This is a fallback for simple cases
    if str == 'null' then
        return nil
    end
    if str == 'true' then
        return true
    end
    if str == 'false' then
        return false
    end

    -- Try to parse as number
    local num = tonumber(str)
    if num then
        return num
    end

    -- If it's a string, remove quotes
    if str:match('^".*"$') then
        return str:sub(2, -2)
            :gsub('\\"', '"')
            :gsub('\\\\', '\\')
            :gsub('\\n', '\n')
            :gsub('\\r', '\r')
            :gsub('\\t', '\t')
    end

    error('JSON parsing not available - please install a JSON library (json or dkjson)')
end

-- Path handling
M.path = {}

function M.path.get_data_dir()
    -- Get standard data directory based on OS
    local home = os.getenv('HOME') or os.getenv('USERPROFILE')
    if not home then
        error('Could not determine home directory')
    end

    local os_name = os.getenv('OS')
    if os_name and os_name:match('Windows') then
        -- Windows
        local appdata = os.getenv('APPDATA')
        return appdata and (appdata .. '\\nvim') or (home .. '\\AppData\\Roaming\\nvim')
    else
        -- Unix-like (Linux, macOS)
        local xdg_data = os.getenv('XDG_DATA_HOME')
        return xdg_data and (xdg_data .. '/nvim') or (home .. '/.local/share/nvim')
    end
end

function M.path.join(...)
    local parts = { ... }
    local sep = package.config:sub(1, 1) -- Get path separator
    return table.concat(parts, sep)
end

-- Notification handling (CLI output)
function M.notify(message, level, opts)
    opts = opts or {}
    local level_name = ''

    if level then
        if level == 1 then
            level_name = '[ERROR] '
        elseif level == 2 then
            level_name = '[WARN] '
        elseif level == 3 then
            level_name = '[INFO] '
        elseif level == 4 then
            level_name = '[DEBUG] '
        end
    end

    local prefix = opts.title and ('[' .. opts.title .. '] ') or ''
    print(prefix .. level_name .. message)
end

-- Log levels (equivalent to vim.log.levels)
M.log = {
    levels = {
        ERROR = 1,
        WARN = 2,
        INFO = 3,
        DEBUG = 4,
    },
}

-- Table utilities (equivalent to vim.tbl_*)
M.tbl = {}

function M.tbl.deep_extend(behavior, ...)
    local ret = {}
    if behavior ~= 'force' and behavior ~= 'keep' then
        error("tbl_deep_extend: behavior must be 'force' or 'keep'")
    end

    for _, tbl in ipairs({ ... }) do
        if type(tbl) == 'table' then
            for k, v in pairs(tbl) do
                if type(v) == 'table' and type(ret[k]) == 'table' then
                    ret[k] = M.tbl.deep_extend(behavior, ret[k], v)
                elseif behavior == 'force' or ret[k] == nil then
                    ret[k] = type(v) == 'table' and M.tbl.deep_extend(behavior, {}, v) or v
                end
            end
        end
    end

    return ret
end

function M.deep_copy(obj)
    if type(obj) ~= 'table' then
        return obj
    end

    local copy = {}
    for k, v in pairs(obj) do
        copy[k] = M.deep_copy(v)
    end
    return copy
end

-- Mock vim functions for CLI
M.vim = {
    fn = {
        stdpath = function(what)
            if what == 'data' then
                return M.path.get_data_dir()
            end
            error('stdpath: unknown path type: ' .. tostring(what))
        end,
        json_encode = M.json.encode,
        json_decode = M.json.decode,
    },
    notify = M.notify,
    log = M.log,
    tbl_deep_extend = M.tbl.deep_extend,
    deepcopy = M.deep_copy,
    api = {
        -- Mock API functions that might be called but aren't relevant for CLI
        nvim_buf_get_name = function()
            return ''
        end,
    },
}

return M
