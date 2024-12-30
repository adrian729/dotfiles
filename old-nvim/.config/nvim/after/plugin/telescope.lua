local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Telescope search files' })
vim.keymap.set('n', '<leader>fg', builtin.git_files, { desc = 'Telescope git search files' })
-- Pre-requisite: install [ripgrep](https://github.com/BurntSushi/ripgrep?tab=readme-ov-file#installation)
vim.keymap.set('n', '<leader>ps', function()
    builtin.grep_string({ search = vim.fn.input("Grep > ") });
end, { desc = 'Telescope project search' })
