return {
    {
        "nvim-neotest/neotest",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "alfaix/neotest-gtest",
            "nvim-neotest/neotest-vim-test",
        },
        keys = {
            {
                "<leader>tL",
                function()
                    require("neotest").run.run_last({ strategy = "dap" })
                end,
                desc = "Debug Last Test",
            },
        },
        opts = function(_, opts)
            table.insert(opts.adapters, require("neotest-gtest").setup({ mappings = { configure = nil } }))
            table.insert(opts.adapters, require("neotest-vim-test"))
            --table.insert(opts.adapters, require("")) - For additional adapters, just add more table.insert calls (and add a corresponding dependency)
        end,
    },
}
