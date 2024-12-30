-- TODO: if change telescope for fzf-lua, check integration.
return {
  {
    "theprimeagen/harpoon",
    branch = "harpoon2",
    lazy = true,
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = function()
      local harpoon = require("harpoon")
      -- REQUIRED
      harpoon:setup({})
      -- REQUIRED

      return {
        {
          "<leader>a",
          function() harpoon:list():add() end,
          desc = "harpoon add file"
        }, {
        "<leader>he",
        function()
          harpoon.ui:toggle_quick_menu(harpoon:list())
        end,
        desc = "harpoon quick menu/explorer"
      },
        {
          "<leader>hh",
          function() harpoon:list():select(1) end,
          desc = "harpoon to file 1"
        },
        {
          "<leader>hj",
          function() harpoon:list():select(2) end,
          desc = "harpoon to file 2"
        },
        {
          "<leader>hk",
          function() harpoon:list():select(3) end,
          desc = "harpoon to file 3"
        },
        {
          "<leader>hl",
          function() harpoon:list():select(4) end,
          desc = "harpoon to file 4"
        }, -- Toggle prev & next buffers stored within harpoon list
        {
          "<leader>hp",
          function() harpoon:list():prev() end,
          desc = "harpoon to prev file"
        },
        -- TODO: check because this seems to clash with kitty(?) new window
        {
          "<leader>hn",
          function() harpoon:list():next() end,
          desc = "harpoon to next file"
        }, -- Telescope integration
        {
          "<leader>ht",
          function()
            local conf = require("telescope.config").values
            local function toggle_telescope(harpoon_files)
              local file_paths = {}
              for _, item in ipairs(harpoon_files.items) do
                table.insert(file_paths, item.value)
              end

              require("telescope.pickers").new({}, {
                prompt_title = "Harpoon",
                finder = require("telescope.finders").new_table(
                  { results = file_paths }),
                previewer = conf.file_previewer({}),
                sorter = conf.generic_sorter({})
              }):find()
            end
            toggle_telescope(harpoon:list())
          end,
          desc = "Open telescope harpoon window"
        }
      }
    end
  }
}
