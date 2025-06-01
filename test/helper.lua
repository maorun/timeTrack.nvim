local function join_paths(...)
    local result = table.concat({ ... }, '/')
    return result
end

local function test_dir()
    local data_path = vim.fn.stdpath('data')
    local package_root = join_paths(data_path, 'test')
    return package_root
end

local function notify_dep()
    local package_root = test_dir()
    local lspconfig_path = join_paths(package_root, 'notify')
    vim.opt.runtimepath:append(lspconfig_path)
    if vim.fn.isdirectory(lspconfig_path) ~= 1 then
        vim.fn.system({
            'git',
            'clone',
            'https://github.com/rcarriga/nvim-notify',
            lspconfig_path,
        })
    end
end

local function plenary_dep()
    local package_root = test_dir()
    local lspconfig_path = join_paths(package_root, 'plenary')
    vim.opt.runtimepath:append(lspconfig_path)
    if vim.fn.isdirectory(lspconfig_path) ~= 1 then
        vim.fn.system({
            'git',
            'clone',
            'https://github.com/nvim-lua/plenary.nvim',
            lspconfig_path,
        })
    end
end

return {
    plenary_dep = plenary_dep,
    plenary_dep = plenary_dep,
    notify_dep = notify_dep,
    wait = function(ms, callback)
        -- vim.wait is the preferred method if available (Neovim 0.5+)
        -- It processes events while waiting.
        if vim.wait then
            vim.wait(ms, callback or function() end, 10) -- Check every 10ms
        else
            -- Fallback for older Neovim or if vim.wait is not suitable
            -- This is a very basic sleep and might not process events well for timers.
            local start = vim.loop.now()
            while vim.loop.now() - start < ms do
                vim.loop.sleep(10) -- Sleep in 10ms intervals
                -- May need vim.rpcnotify(0, 'nvim_eval', '1') or similar to drive event loop
            end
            if callback then callback() end
        end
    end,
}
