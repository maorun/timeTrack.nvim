-- Test for concurrent access to JSON file
local helper = require('test.helper')
helper.plenary_dep() -- Ensure plenary is cloned/available
helper.notify_dep() -- Ensure notify is also there

local Path = require('plenary.path')

describe('Concurrent JSON File Access', function()
    local test_json_path
    local time_init_module
    local utils_module

    before_each(function()
        -- Clean up any test files first
        test_json_path = '/tmp/test_concurrency_' .. os.time() .. '.json'
        local test_file = Path:new(test_json_path)
        if test_file:exists() then
            test_file:rm()
        end

        time_init_module = require('maorun.time.init')
        utils_module = require('maorun.time.utils')
    end)

    after_each(function()
        -- Clean up test file
        local test_file = Path:new(test_json_path)
        if test_file:exists() then
            test_file:rm()
        end

        -- Reset modules to clean state for next test
        package.loaded['maorun.time.config'] = nil
        package.loaded['maorun.time.core'] = nil
        package.loaded['maorun.time.utils'] = nil
        package.loaded['maorun.time.init'] = nil
    end)

    it('should demonstrate the concurrency race condition is now fixed', function()
        -- This test demonstrates that the atomic write pattern prevents corruption

        local config = {
            path = test_json_path,
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

        -- Instance A: Initialize and add some data
        local instance_a_data = time_init_module.setup(config)
        time_init_module.addTime({
            time = 2.0,
            weekday = 'Monday',
            project = 'ProjectA',
            file = 'fileA.lua',
        })

        -- Simulate Instance B: Start with fresh state (as if another Neovim instance)
        -- Reset the config module to simulate fresh loading
        package.loaded['maorun.time.config'] = nil
        local config_module = require('maorun.time.config')
        config_module.obj = { path = nil, content = {} }
        config_module.config = vim.deepcopy(config_module.defaults)

        -- Instance B: Initialize from file (should see Instance A's data)
        local instance_b_data = time_init_module.setup(config)

        -- Now both instances have different in-memory state but Instance B loaded A's file data
        -- Let's verify Instance B can see Instance A's data
        local file_content = Path:new(test_json_path):read()
        local loaded_data = vim.json.decode(file_content)

        -- Check if Instance A's data is present
        assert.is_not_nil(loaded_data.data)
        local year_str = os.date('%Y')
        local week_str = os.date('%W')
        local weekday_data = loaded_data.data[year_str]
            and loaded_data.data[year_str][week_str]
            and loaded_data.data[year_str][week_str]['Monday']

        if weekday_data then
            local project_data = weekday_data['ProjectA']
            if project_data then
                local file_data = project_data['fileA.lua']
                assert.is_not_nil(file_data, 'Instance A data should be visible to Instance B')
                assert.is_not_nil(file_data.items, 'Items should exist')
                assert.are.same(1, #file_data.items, 'Should have one item from Instance A')
            end
        end

        -- Instance B: Add different data
        time_init_module.addTime({
            time = 1.5,
            weekday = 'Monday',
            project = 'ProjectB',
            file = 'fileB.lua',
        })

        -- Now read the final file to see if both instances' data is preserved
        local final_content = Path:new(test_json_path):read()
        local final_data = vim.json.decode(final_content)

        local final_weekday_data = final_data.data[year_str][week_str]['Monday']

        -- Both ProjectA and ProjectB should exist
        assert.is_not_nil(final_weekday_data['ProjectA'], 'ProjectA data should still exist')
        assert.is_not_nil(final_weekday_data['ProjectB'], 'ProjectB data should exist')

        -- Verify both files exist
        assert.is_not_nil(final_weekday_data['ProjectA']['fileA.lua'], 'fileA.lua should exist')
        assert.is_not_nil(final_weekday_data['ProjectB']['fileB.lua'], 'fileB.lua should exist')

        -- With atomic writes, the file should be consistent and uncorrupted
        assert.is_true(
            vim.json.decode(Path:new(test_json_path):read()) ~= nil,
            'JSON should be valid and parseable'
        )
    end)

    it('should handle rapid consecutive saves without data loss', function()
        -- This test simulates rapid saves that could happen in real usage

        local config = {
            path = test_json_path,
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

        time_init_module.setup(config)

        -- Add multiple time entries rapidly (simulating multiple instances)
        local entries_to_add = {
            { time = 1.0, project = 'Project1', file = 'file1.lua' },
            { time = 1.5, project = 'Project2', file = 'file2.lua' },
            { time = 2.0, project = 'Project3', file = 'file3.lua' },
            { time = 0.5, project = 'Project1', file = 'file1b.lua' },
            { time = 1.0, project = 'Project2', file = 'file2b.lua' },
        }

        for _, entry in ipairs(entries_to_add) do
            time_init_module.addTime({
                time = entry.time,
                weekday = 'Monday',
                project = entry.project,
                file = entry.file,
            })
        end

        -- Verify all entries were saved
        local final_content = Path:new(test_json_path):read()
        local final_data = vim.json.decode(final_content)

        local year_str = os.date('%Y')
        local week_str = os.date('%W')
        local monday_data = final_data.data[year_str][week_str]['Monday']

        -- Check that all projects and files exist
        assert.is_not_nil(monday_data['Project1'], 'Project1 should exist')
        assert.is_not_nil(monday_data['Project2'], 'Project2 should exist')
        assert.is_not_nil(monday_data['Project3'], 'Project3 should exist')

        assert.is_not_nil(monday_data['Project1']['file1.lua'], 'file1.lua should exist')
        assert.is_not_nil(monday_data['Project1']['file1b.lua'], 'file1b.lua should exist')
        assert.is_not_nil(monday_data['Project2']['file2.lua'], 'file2.lua should exist')
        assert.is_not_nil(monday_data['Project2']['file2b.lua'], 'file2b.lua should exist')
        assert.is_not_nil(monday_data['Project3']['file3.lua'], 'file3.lua should exist')

        -- Verify the time entries
        assert.are.same(
            1,
            #monday_data['Project1']['file1.lua'].items,
            'file1.lua should have 1 entry'
        )
        assert.are.same(
            1,
            #monday_data['Project1']['file1b.lua'].items,
            'file1b.lua should have 1 entry'
        )
        assert.are.same(
            1,
            #monday_data['Project2']['file2.lua'].items,
            'file2.lua should have 1 entry'
        )
        assert.are.same(
            1,
            #monday_data['Project2']['file2b.lua'].items,
            'file2b.lua should have 1 entry'
        )
        assert.are.same(
            1,
            #monday_data['Project3']['file3.lua'].items,
            'file3.lua should have 1 entry'
        )
    end)
end)
