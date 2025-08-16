-- Simple CLI for timeTrack.nvim
-- Direct implementation without complex compatibility layers

local M = {}

-- JSON handling using basic Lua patterns
local function json_encode(obj)
    if type(obj) == 'nil' then
        return 'null'
    elseif type(obj) == 'boolean' then
        return obj and 'true' or 'false'
    elseif type(obj) == 'number' then
        return tostring(obj)
    elseif type(obj) == 'string' then
        local escaped = obj:gsub('\\', '\\\\')
            :gsub('"', '\\"')
            :gsub('\n', '\\n')
            :gsub('\r', '\\r')
            :gsub('\t', '\\t')
        return '"' .. escaped .. '"'
    elseif type(obj) == 'table' then
        local parts = {}
        for k, v in pairs(obj) do
            table.insert(parts, json_encode(tostring(k)) .. ':' .. json_encode(v))
        end
        return '{' .. table.concat(parts, ',') .. '}'
    else
        return 'null'
    end
end

local function json_decode(str)
    -- Try to use available JSON libraries
    local ok, json_lib = pcall(require, 'json')
    if ok and json_lib.decode then
        return json_lib.decode(str)
    end

    ok, json_lib = pcall(require, 'dkjson')
    if ok and json_lib.decode then
        return json_lib.decode(str)
    end

    -- Fallback error
    error('JSON parsing not available - please install lua-json or dkjson: luarocks install json')
end

-- Get data directory
local function get_data_dir()
    local home = os.getenv('HOME') or os.getenv('USERPROFILE')
    if not home then
        error('Could not determine home directory')
    end

    local os_name = os.getenv('OS')
    if os_name and os_name:match('Windows') then
        local appdata = os.getenv('APPDATA')
        return appdata and (appdata .. '\\nvim') or (home .. '\\AppData\\Roaming\\nvim')
    else
        local xdg_data = os.getenv('XDG_DATA_HOME')
        return xdg_data and (xdg_data .. '/nvim') or (home .. '/.local/share/nvim')
    end
end

-- File operations
local function file_exists(path)
    local file = io.open(path, 'r')
    if file then
        file:close()
        return true
    end
    return false
end

local function read_file(path)
    local file = io.open(path, 'r')
    if not file then
        return ''
    end
    local content = file:read('*all')
    file:close()
    return content or ''
end

local function write_file(path, content)
    local file = io.open(path, 'w')
    if not file then
        error('Failed to open file for writing: ' .. path)
    end
    file:write(content)
    file:close()
end

-- Default configuration
local default_config = {
    hoursPerWeekday = {
        Monday = 8,
        Tuesday = 8,
        Wednesday = 8,
        Thursday = 8,
        Friday = 8,
        Saturday = 0,
        Sunday = 0,
    },
}

-- Initialize and load data
function M.init(config_override)
    local sep = package.config:sub(1, 1)
    local data_file = get_data_dir() .. sep .. 'maorun-time.json'

    local data = {}
    if file_exists(data_file) then
        local content = read_file(data_file)
        if content and content ~= '' then
            data = json_decode(content)
        end
    end

    -- Ensure basic structure
    if not data.hoursPerWeekday then
        data.hoursPerWeekday = default_config.hoursPerWeekday
    end
    if not data.data then
        data.data = {}
    end

    return {
        path = data_file,
        content = data,
    }
end

-- Save data
function M.save(obj)
    write_file(obj.path, json_encode(obj.content))
end

-- Get weekly summary
function M.get_weekly_summary(opts)
    opts = opts or {}
    local obj = M.init()

    local year = opts.year or os.date('%Y')
    local week = opts.week or os.date('%W')

    local summary_data = {}

    if
        obj.content.data
        and obj.content.data[tostring(year)]
        and obj.content.data[tostring(year)][tostring(week)]
    then
        local week_data = obj.content.data[tostring(year)][tostring(week)]

        for weekday, weekday_data in pairs(week_data) do
            if weekday ~= 'summary' then
                summary_data[weekday] = {
                    projects = {},
                    total_hours = 0,
                }

                for project, project_data in pairs(weekday_data) do
                    if project ~= 'summary' then
                        summary_data[weekday].projects[project] = {}
                        local project_hours = 0

                        for file, file_data in pairs(project_data) do
                            if file ~= 'summary' and file_data.summary then
                                local file_hours = file_data.summary.diffInHours or 0
                                summary_data[weekday].projects[project][file] = file_hours
                                project_hours = project_hours + file_hours
                            end
                        end

                        summary_data[weekday].total_hours = summary_data[weekday].total_hours
                            + project_hours
                    end
                end
            end
        end
    end

    return summary_data
end

-- Add manual time entry
function M.add_time_entry(opts)
    if not opts.project or not opts.file or not opts.hours then
        error('project, file, and hours are required')
    end

    local obj = M.init()
    local weekday = opts.weekday or os.date('%A')
    local year = tostring(os.date('%Y'))
    local week = tostring(os.date('%W'))

    -- Initialize data structure
    if not obj.content.data[year] then
        obj.content.data[year] = {}
    end
    if not obj.content.data[year][week] then
        obj.content.data[year][week] = {}
    end
    if not obj.content.data[year][week][weekday] then
        obj.content.data[year][week][weekday] = {}
    end
    if not obj.content.data[year][week][weekday][opts.project] then
        obj.content.data[year][week][weekday][opts.project] = {}
    end
    if not obj.content.data[year][week][weekday][opts.project][opts.file] then
        obj.content.data[year][week][weekday][opts.project][opts.file] = {
            items = {},
            summary = { diffInHours = 0 },
        }
    end

    -- Add the time entry
    local current_time = os.time()
    local end_time = current_time + (opts.hours * 3600) -- Convert hours to seconds

    local file_data = obj.content.data[year][week][weekday][opts.project][opts.file]

    -- Ensure items is an array
    if not file_data.items then
        file_data.items = {}
    end

    table.insert(file_data.items, {
        startTime = current_time,
        startReadable = os.date('%H:%M', current_time),
        endTime = end_time,
        endReadable = os.date('%H:%M', end_time),
        diffInHours = opts.hours,
    })

    -- Update summary
    if not file_data.summary then
        file_data.summary = { diffInHours = 0 }
    end
    file_data.summary.diffInHours = (file_data.summary.diffInHours or 0) + opts.hours

    M.save(obj)
    return true
end

-- Get status
function M.get_status()
    local obj = M.init()

    local current_year = os.date('%Y')
    local current_week = os.date('%W')
    local current_weekday = os.date('%A')

    local status = {
        data_file = obj.path,
        current_year = current_year,
        current_week = current_week,
        current_weekday = current_weekday,
        paused = obj.content.paused or false,
        hours_per_weekday = obj.content.hoursPerWeekday or default_config.hoursPerWeekday,
    }

    -- Get current week summary
    status.current_week_summary = M.get_weekly_summary({
        year = current_year,
        week = current_week,
    })

    return status
end

-- List time entries
function M.list_entries(opts)
    opts = opts or {}
    local obj = M.init()

    local year = opts.year or os.date('%Y')
    local week = opts.week or os.date('%W')

    local entries = {}

    if
        obj.content.data
        and obj.content.data[tostring(year)]
        and obj.content.data[tostring(year)][tostring(week)]
    then
        local week_data = obj.content.data[tostring(year)][tostring(week)]

        for weekday, weekday_data in pairs(week_data) do
            if weekday ~= 'summary' then
                for project, project_data in pairs(weekday_data) do
                    if project ~= 'summary' then
                        for file, file_data in pairs(project_data) do
                            if file ~= 'summary' and file_data.items then
                                -- Handle both array-style and key-value items
                                if type(file_data.items) == 'table' then
                                    for key, item in pairs(file_data.items) do
                                        if type(item) == 'table' and item.startTime then
                                            table.insert(entries, {
                                                weekday = weekday,
                                                project = project,
                                                file = file,
                                                startTime = item.startTime,
                                                startReadable = item.startReadable,
                                                endTime = item.endTime,
                                                endReadable = item.endReadable,
                                                diffInHours = item.diffInHours,
                                            })
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Sort entries by start time
    table.sort(entries, function(a, b)
        return a.startTime < b.startTime
    end)

    return entries
end

-- Export data
function M.export_data(opts)
    opts = opts or {}
    local format = opts.format or 'csv'
    local entries = M.list_entries(opts)

    if format == 'csv' then
        local lines = { 'Weekday,Project,File,Hours,Start,End' }
        for _, entry in ipairs(entries) do
            table.insert(
                lines,
                string.format(
                    '%s,%s,%s,%.1f,%s,%s',
                    entry.weekday,
                    entry.project,
                    entry.file,
                    entry.diffInHours or 0,
                    entry.startReadable,
                    entry.endReadable
                )
            )
        end
        return table.concat(lines, '\n')
    elseif format == 'markdown' then
        local lines = {
            '| Weekday | Project | File | Hours | Start | End |',
            '| --- | --- | --- | --- | --- | --- |',
        }
        for _, entry in ipairs(entries) do
            table.insert(
                lines,
                string.format(
                    '| %s | %s | %s | %.1f | %s | %s |',
                    entry.weekday,
                    entry.project,
                    entry.file,
                    entry.diffInHours or 0,
                    entry.startReadable,
                    entry.endReadable
                )
            )
        end
        return table.concat(lines, '\n')
    else
        error('Unsupported format: ' .. format)
    end
end

-- Basic validation
function M.validate_data(opts)
    opts = opts or {}
    local obj = M.init()

    local issues = {}
    local summary = {
        total_issues = 0,
        total_overlaps = 0,
        total_duplicates = 0,
        total_errors = 0,
    }

    if obj.content.data then
        for year, year_data in pairs(obj.content.data) do
            for week, week_data in pairs(year_data) do
                for weekday, weekday_data in pairs(week_data) do
                    if weekday ~= 'summary' then
                        for project, project_data in pairs(weekday_data) do
                            if project ~= 'summary' then
                                for file, file_data in pairs(project_data) do
                                    if file ~= 'summary' and file_data.items then
                                        for _, item in ipairs(file_data.items) do
                                            local item_issues = {}

                                            -- Check for invalid times
                                            if item.startTime and item.endTime then
                                                if item.startTime >= item.endTime then
                                                    table.insert(
                                                        item_issues,
                                                        'Start time after end time'
                                                    )
                                                end

                                                local duration = (item.endTime - item.startTime)
                                                    / 3600
                                                if duration > 24 then
                                                    table.insert(
                                                        item_issues,
                                                        string.format(
                                                            'Unrealistic duration: %.1fh',
                                                            duration
                                                        )
                                                    )
                                                end
                                                if duration < 0 then
                                                    table.insert(item_issues, 'Negative duration')
                                                end
                                            end

                                            if #item_issues > 0 then
                                                table.insert(issues, {
                                                    weekday = weekday,
                                                    project = project,
                                                    file = file,
                                                    issues = item_issues,
                                                })
                                                summary.total_errors = summary.total_errors + 1
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    summary.total_issues = summary.total_overlaps + summary.total_duplicates + summary.total_errors

    return {
        issues = { [os.date('%A')] = issues }, -- Group by current weekday for compatibility
        summary = summary,
    }
end

return M
