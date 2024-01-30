return {
    {
        "nvim-neotest/neotest",
        dependencies = {
            "alfaix/neotest-gtest",
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
            table.insert(opts.adapters, require("neotest-gtest").setup({}))
            --table.insert(opts.adapters, require("")) - For additional adapters, just add more table.insert calls (and add a corresponding dependency)
        end,
    },
}
