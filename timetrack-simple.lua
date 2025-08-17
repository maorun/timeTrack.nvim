#!/usr/bin/env lua
-- timeTrack CLI - Simple standalone command-line interface for timeTrack.nvim
-- Usage: lua timetrack-simple.lua <command> [options]

-- Ensure we can find the modules
local script_dir = debug.getinfo(1, 'S').source:match('@(.*/)')
if script_dir then
    package.path = script_dir .. 'cli/?.lua;' .. script_dir .. 'cli/?/init.lua;' .. package.path
else
    package.path = './cli/?.lua;./cli/?/init.lua;' .. package.path
end

local cli = require('simple')

-- Helper function to print usage
local function print_usage()
    print([[
timeTrack CLI - Time tracking without Neovim

Usage: lua timetrack-simple.lua <command> [options]

Commands:
  status                    Show current time tracking status
  summary [week] [year]     Show weekly summary (defaults to current week)
  add <project> <file> <hours> [weekday]  Add manual time entry
  list [week] [year]        List all time entries for a week
  validate                  Validate time data for issues
  export <format> [week] [year]  Export data (csv, markdown)
  help                      Show this help message

Examples:
  lua timetrack-simple.lua status
  lua timetrack-simple.lua summary
  lua timetrack-simple.lua summary 25 2024
  lua timetrack-simple.lua add "MyProject" "main.lua" 2.5
  lua timetrack-simple.lua add "MyProject" "main.lua" 2.5 "Monday"
  lua timetrack-simple.lua list
  lua timetrack-simple.lua export csv
  lua timetrack-simple.lua validate
]])
end

-- Helper function to format hours
local function format_hours(hours)
    return string.format('%.1fh', hours)
end

-- Helper function to print weekly summary
local function print_summary(summary, year, week)
    print(
        string.format(
            '\n📊 Weekly Summary - Year %s, Week %s',
            year or os.date('%Y'),
            week or os.date('%W')
        )
    )
    print(string.rep('=', 50))

    local total_week_hours = 0
    local weekdays =
        { 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday' }

    for _, weekday in ipairs(weekdays) do
        if summary[weekday] then
            print(
                string.format('\n📅 %s - %s', weekday, format_hours(summary[weekday].total_hours))
            )
            total_week_hours = total_week_hours + summary[weekday].total_hours

            for project, files in pairs(summary[weekday].projects) do
                local project_hours = 0
                for file, hours in pairs(files) do
                    project_hours = project_hours + hours
                end
                print(string.format('  📁 %s: %s', project, format_hours(project_hours)))

                for file, hours in pairs(files) do
                    if hours > 0 then
                        print(string.format('    📄 %s: %s', file, format_hours(hours)))
                    end
                end
            end
        end
    end

    print(string.format('\n🏁 Total Week: %s', format_hours(total_week_hours)))
end

-- Helper function to print validation results
local function print_validation_results(results)
    print('\n🔍 Data Validation Results')
    print(string.rep('=', 30))

    if results.summary.total_issues == 0 then
        print('✅ No issues found!')
        return
    end

    print(string.format('Found %d issues:', results.summary.total_issues))

    if results.summary.total_overlaps > 0 then
        print(string.format('  ⚠️  %d overlapping entries', results.summary.total_overlaps))
    end

    if results.summary.total_duplicates > 0 then
        print(string.format('  ⚠️  %d duplicate entries', results.summary.total_duplicates))
    end

    if results.summary.total_errors > 0 then
        print(string.format('  ❌ %d erroneous entries', results.summary.total_errors))
    end

    -- Show detailed issues
    for weekday, issues in pairs(results.issues) do
        if #issues > 0 then
            print(string.format('\n📅 %s:', weekday))
            for _, issue in ipairs(issues) do
                print(
                    string.format(
                        '  • %s/%s: %s',
                        issue.project,
                        issue.file,
                        table.concat(issue.issues, ', ')
                    )
                )
            end
        end
    end
end

-- Parse command line arguments
local function parse_args(args)
    local command = args[1]
    local parsed = { command = command }

    if command == 'summary' or command == 'list' then
        parsed.week = args[2]
        parsed.year = args[3]
    elseif command == 'add' then
        parsed.project = args[2]
        parsed.file = args[3]
        parsed.hours = tonumber(args[4])
        parsed.weekday = args[5]
    elseif command == 'export' then
        parsed.format = args[2]
        parsed.week = args[3]
        parsed.year = args[4]
    end

    return parsed
end

-- Main CLI function
local function main(args)
    local parsed = parse_args(args)
    local command = parsed.command

    if not command or command == 'help' then
        print_usage()
        return
    end

    -- Handle different commands
    if command == 'status' then
        local status = cli.get_status()
        print('\n📊 timeTrack Status')
        print(string.rep('=', 20))
        print(string.format('Data file: %s', status.data_file))
        print(
            string.format(
                'Current: %s, Week %s (%s)',
                status.current_year,
                status.current_week,
                status.current_weekday
            )
        )
        print(string.format('Paused: %s', status.paused and 'Yes' or 'No'))

        print('\n⏰ Hours per weekday:')
        for weekday, hours in pairs(status.hours_per_weekday) do
            print(string.format('  %s: %s', weekday, format_hours(hours)))
        end

        -- Show current week summary if there's data
        local has_data = false
        for _, data in pairs(status.current_week_summary) do
            if data.total_hours > 0 then
                has_data = true
                break
            end
        end

        if has_data then
            print_summary(status.current_week_summary, status.current_year, status.current_week)
        else
            print(
                string.format(
                    '\n📈 No time entries found for current week (%s/%s)',
                    status.current_week,
                    status.current_year
                )
            )
        end
    elseif command == 'summary' then
        local summary = cli.get_weekly_summary({
            week = parsed.week,
            year = parsed.year,
        })
        print_summary(summary, parsed.year, parsed.week)
    elseif command == 'add' then
        if not parsed.project or not parsed.file or not parsed.hours then
            print('❌ Error: project, file, and hours are required')
            print('Usage: lua timetrack-simple.lua add <project> <file> <hours> [weekday]')
            return 1
        end

        local success, err = pcall(cli.add_time_entry, {
            project = parsed.project,
            file = parsed.file,
            hours = parsed.hours,
            weekday = parsed.weekday,
        })

        if success then
            local weekday = parsed.weekday or os.date('%A')
            print(
                string.format(
                    '✅ Added %s to %s/%s for %s',
                    format_hours(parsed.hours),
                    parsed.project,
                    parsed.file,
                    weekday
                )
            )
        else
            print(string.format('❌ Error adding time entry: %s', err))
            return 1
        end
    elseif command == 'list' then
        local entries = cli.list_entries({
            week = parsed.week,
            year = parsed.year,
        })

        print(
            string.format(
                '\n📋 Time Entries - Year %s, Week %s',
                parsed.year or os.date('%Y'),
                parsed.week or os.date('%W')
            )
        )
        print(string.rep('=', 50))

        if #entries == 0 then
            print('No time entries found.')
        else
            for _, entry in ipairs(entries) do
                print(
                    string.format(
                        '%s | %s/%s | %s | %s-%s (%s)',
                        entry.weekday,
                        entry.project,
                        entry.file,
                        format_hours(entry.diffInHours or 0),
                        entry.startReadable,
                        entry.endReadable,
                        format_hours((entry.endTime - entry.startTime) / 3600)
                    )
                )
            end
        end
    elseif command == 'validate' then
        local results = cli.validate_data()
        print_validation_results(results)
    elseif command == 'export' then
        if not parsed.format then
            print('❌ Error: format is required')
            print('Usage: lua timetrack-simple.lua export <format> [week] [year]')
            print('Formats: csv, markdown')
            return 1
        end

        local export_data = cli.export_data({
            format = parsed.format,
            week = parsed.week,
            year = parsed.year,
        })

        if export_data then
            print(export_data)
        else
            print('❌ Error: Failed to export data')
            return 1
        end
    else
        print(string.format('❌ Unknown command: %s', command))
        print_usage()
        return 1
    end

    return 0
end

-- Run the CLI if this script is executed directly
if arg then
    local exit_code = main(arg)
    if exit_code and exit_code ~= 0 then
        os.exit(exit_code)
    end
end

-- Return the main function for testing
return main
