local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local actions = require('telescope.actions')
local conf = require('telescope.config').values
local action_state = require('telescope.actions.state')
local entry_display = require('telescope.pickers.entry_display')
local displayer = entry_display.create({
    separator = ' ',
    items = {
        { remaining = true },
    },
})
local make_display = function(entry)
    return displayer({
        entry.value,
    })
end

return function(opts)
    opts = vim.tbl_deep_extend('keep', opts or {}, {
        title = '',
        list = {},
        action = function() end,
    })
    pickers
        .new(opts, {
            prompt_title = opts.title,
            attach_mappings = function(propt_bufnr)
                actions.select_default:replace(function()
                    actions.close(propt_bufnr)
                    opts.action(action_state.get_selected_entry().value)
                end)
                return true
            end,
            finder = finders.new_table({
                results = opts.list,
                entry_maker = function(entry)
                    return {
                        value = entry,
                        display = make_display,

                        -- this is what we can fzf
                        ordinal = entry,
                    }
                end,
            }),
            sorter = conf.generic_sorter(opts),
        })
        :find()
end
