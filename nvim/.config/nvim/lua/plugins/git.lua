return {
    {
        "tpope/vim-fugitive",
        cmd = "Git",
        keys = {
            {
                "<leader>gs",
                vim.cmd.Git,
                desc = "Fugitive Git Status",
            },
        },
    },
    {
        'lewis6991/gitsigns.nvim',
        cmd = "Gitsigns",
        keys = {
            {
                "<leader>glb",
                "<cmd>Gitsigns toggle_current_line_blame<CR>",
                desc = "Gitsigns toggle_current_line_blame"
            },
        },
    },
}
