-- TODO: see how to do all the lsp config from here instead of in config.lsp
return {
  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    keys = {
      { "<leader>cm", "<cmd>Mason<cr>", desc = "Mason" }
    },
    build = ":MasonUpdate",
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason.nvim",
    },
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = {
      "williamboman/mason.nvim",
      "neovim/nvim-lspconfig",
    },
  },
  {
    "rafamadriz/friendly-snippets",
  },
  {
    "L3MON4D3/LuaSnip",
    dependencies = { "rafamadriz/friendly-snippets" },
    version = "v2.*",
    build = "make install_jsregexp"
  },
  {
    "saadparwaiz1/cmp_luasnip",
    dependencies = { "L3MON4D3/LuaSnip", "hrsh7th/nvim-cmp" },
  },
  {
    "hrsh7th/cmp-nvim-lsp",
  },
  {
    "hrsh7th/cmp-buffer",
  },
  {
    "hrsh7th/cmp-path",
  },
  {
    "hrsh7th/cmp-cmdline",
  },
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "saadparwaiz1/cmp_luasnip",
    },
  },
  {
    "VonHeikemen/lsp-zero.nvim",
    dependencies = {
      "hrsh7th/nvim-cmp",
      "hrsh7th/cmp-nvim-lsp",
      "williamboman/mason.nvim",
      "neovim/nvim-lspconfig",
      "williamboman/mason-lspconfig.nvim",
    },
    config = function()
      -- NOTE: to make any of this work you need a language server.
      -- If you don't know what that is, watch this 5 min video:
      -- https://www.youtube.com/watch?v=LaS32vctfOY

      -- Reserve a space in the gutter
      vim.opt.signcolumn = 'yes'

      -- Add cmp_nvim_lsp capabilities settings to lspconfig
      -- !This should be executed before you configure any language server
      local lspconfig_defaults = require('lspconfig').util.default_config
      lspconfig_defaults.capabilities = vim.tbl_deep_extend(
        'force',
        lspconfig_defaults.capabilities,
        require('cmp_nvim_lsp').default_capabilities()
      )
      local capabilities = lspconfig_defaults.capabilities

      -- This is where you enable features that only work
      -- if there is a language server active in the file
      vim.api.nvim_create_autocmd('LspAttach', {
        desc = 'LSP actions',
        callback = function(event)
          local opts = { buffer = event.buf }

          -- TODO: add personal remaps
          vim.keymap.set('n', 'K', '<cmd>lua vim.lsp.buf.hover()<cr>', opts)
          vim.keymap.set('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<cr>', opts)
          vim.keymap.set('n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<cr>', opts)
          vim.keymap.set('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<cr>', opts)
          vim.keymap.set('n', 'go', '<cmd>lua vim.lsp.buf.type_definition()<cr>', opts)
          vim.keymap.set('n', 'gr', '<cmd>lua vim.lsp.buf.references()<cr>', opts)
          vim.keymap.set('n', 'gs', '<cmd>lua vim.lsp.buf.signature_help()<cr>', opts)
          vim.keymap.set('n', '<F2>', '<cmd>lua vim.lsp.buf.rename()<cr>', opts)
          vim.keymap.set({ 'n', 'x' }, '<F3>', '<cmd>lua vim.lsp.buf.format({async = true})<cr>', opts)
          vim.keymap.set('n', '<F4>', '<cmd>lua vim.lsp.buf.code_action()<cr>', opts)
        end,
      })

      -- Format keybinding
      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(event)
          local opts = { buffer = event.buf }

          vim.keymap.set({ 'n', 'x' }, 'gq', function()
            vim.lsp.buf.format({ async = false, timeout_ms = 10000 })
          end, opts)
        end
      })

      -----------------------------------------------------------------------------------------------------------------------

      -- Enable lsp autoformat before buffer write
      local buffer_autoformat = function(bufnr)
        local group = 'lsp_autoformat'
        vim.api.nvim_create_augroup(group, { clear = false })
        vim.api.nvim_clear_autocmds({ group = group, buffer = bufnr })

        vim.api.nvim_create_autocmd('BufWritePre', {
          buffer = bufnr,
          group = group,
          desc = 'LSP format on save',
          callback = function()
            -- note: do not enable async formatting
            vim.lsp.buf.format({ async = false, timeout_ms = 10000 })
          end,
        })
      end
      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(event)
          local id = vim.tbl_get(event, 'data', 'client_id')
          local client = id and vim.lsp.get_client_by_id(id)
          if client == nil then
            return
          end

          -- make sure there is at least one client with formatting capabilities
          if client.supports_method('textDocument/formatting') then
            buffer_autoformat(event.buf)
          end
        end
      })

      -----------------------------------------------------------------------------------------------------------------------

      ----------------------
      -- Language Servers --
      ----------------------

      require('mason').setup({})
      require('mason-lspconfig').setup({
        -- You'll find a list of language servers here:
        -- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md
        -- MASON LSPs: https://github.com/williamboman/mason-lspconfig.nvim?tab=readme-ov-file#available-lsp-servers
        ensure_installed = {
          'bashls',      -- npm i -g bash-language-server
          'lua_ls',      -- to install: https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#lua_ls
          'pylsp',       -- sudo apt-get install python3-pylsp
          'eslint',      -- npm i -g vscode-langservers-extracted
          'ts_ls',       -- npm install -g typescript typescript-language-server
          'jsonls',      -- npm i -g vscode-langservers-extracted
          'html',        -- npm i -g vscode-langservers-extracted
          'cssls',       -- npm i -g vscode-langservers-extracted
          'tailwindcss', -- npm install -g @tailwindcss/language-server
          'marksman'     -- brew install marksman (or sudo snap install marksman)
        },
        handlers = {
          -- default lsp handler
          function(server_name)
            require('lspconfig')[server_name].setup({})
          end,
          -- lsp handlers with setup/custom
          lua_ls = function()
            local lua_settings = {
              runtime = { version = 'LuaJIT' },
              -- Make the server aware of Neovim runtime files
              workspace = {
                checkThirdParty = false,
                library = { vim.env.VIMRUNTIME }
              },
              diagnostics = {
                -- Get the language server to recognize the `vim` global
                globals = { 'vim', 'require' }
              },
              format = {
                enable = true,
                defaultConfig = {
                  -- !If the editor has ANY config, it overwrites this
                  indent_style = "space",
                  indent_size = "2"
                }
              }
            }
            require('lspconfig').lua_ls.setup({
              capabilities = capabilities,
              on_init = function(client)
                if client.workspace_folders then
                  local path =
                      client.workspace_folders[1].name
                  if vim.uv.fs_stat(path .. '/.luarc.json') or
                      vim.uv.fs_stat(path .. '/.luarc.jsonc') then
                    return
                  end
                end
                client.config.settings.Lua =
                    vim.tbl_deep_extend('force', client.config
                      .settings.Lua,
                      lua_settings)
              end,
              settings = {
                Lua = {
                  format = {
                    enable = true,
                    defaultConfig = {
                      indent_style = "space",
                      indent_size = "2"
                    }
                  }

                }
              }
            })
          end,
          eslint = function()
            require('lspconfig').eslint.setup({
              capabilities = capabilities,
              on_attach = function(client, bufnr)
                vim.api.nvim_create_autocmd("BufWritePre", {
                  buffer = bufnr,
                  command = "EslintFixAll"
                })
              end
            })
          end,
          html = function()
            -- Enable (broadcasting) snippet capability for completion
            local html_capabilities = vim.lsp.protocol
                .make_client_capabilities()
            html_capabilities.textDocument.completion.completionItem
            .snippetSupport = true

            require('lspconfig').html.setup {
              capabilities = html_capabilities
            }
          end,
          cssls = function()
            -- Enable (broadcasting) snippet capability for completion
            local css_capabilities = vim.lsp.protocol
                .make_client_capabilities()
            css_capabilities.textDocument.completion.completionItem
            .snippetSupport = true

            require 'lspconfig'.cssls.setup {
              capabilities = css_capabilities
            }
          end
        }
      })

      -----------------------------------------------------------------------------------------------------------------------

      ---------
      -- CMP --
      ---------

      --[[
        TODO: remove this once we know them by heart
        Keybindings: These are the keybindings nvim-cmp's preset enables by default. They are meant to follow Neovim's default.
        <Ctrl-y>: Confirms selection.
        <Ctrl-e>: Cancel the completion.
        <Down>: Navigate to the next item on the list.
        <Up>: Navigate to previous item on the list.
        <Ctrl-n>: Go to the next item in the completion menu, or trigger completion menu.
        <Ctrl-p>: Go to the previous item in the completion menu, or trigger completion menu.
      --]]
      local cmp = require("cmp")
      cmp.setup({
        sources = {
          {
            name = 'nvim_lsp',
          },
          {
            name = 'buffer',
          },
          {
            name = 'luasnip'
          }
        },
        mapping = cmp.mapping.preset.insert({
          -- Navigate between completion items
          ['<C-p>'] = cmp.mapping.select_prev_item({
            behavior = 'select'
          }),
          ['<C-n>'] = cmp.mapping.select_next_item({
            behavior = 'select'
          }),
          -- `Enter` key to confirm completion
          ['<CR>'] = cmp.mapping.confirm({ select = false }),
          -- Ctrl+Space to trigger completion menu
          ['<C-Space>'] = cmp.mapping.complete(),
          -- Scroll up and down in the completion documentation
          ['<C-u>'] = cmp.mapping.scroll_docs(-4),
          ['<C-d>'] = cmp.mapping.scroll_docs(4),
          -- Jump to the next snippet placeholder
          ['<C-f>'] = cmp.mapping(function(fallback)
            local luasnip = require('luasnip')
            if luasnip.locally_jumpable(1) then
              luasnip.jump(1)
            else
              fallback()
            end
          end, { 'i', 's' }),
          -- Jump to the previous snippet placeholder
          ['<C-b>'] = cmp.mapping(function(fallback)
            local luasnip = require('luasnip')
            if luasnip.locally_jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { 'i', 's' }),
          -- Super tab
          ['<Tab>'] = cmp.mapping(function(fallback)
            local luasnip = require('luasnip')
            local col = vim.fn.col('.') - 1

            if cmp.visible() then
              cmp.select_next_item({ behavior = 'select' })
            elseif luasnip.expand_or_locally_jumpable() then
              luasnip.expand_or_jump()
            elseif col == 0 or
                vim.fn.getline('.'):sub(col, col):match('%s') then
              fallback()
            else
              cmp.complete()
            end
          end, { 'i', 's' }),
          -- Super shift tab
          ['<S-Tab>'] = cmp.mapping(function(fallback)
            local luasnip = require('luasnip')
            if cmp.visible() then
              cmp.select_prev_item({ behavior = 'select' })
            elseif luasnip.locally_jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { 'i', 's' })
        }),
        snippet = {
          expand = function(args)
            -- You need Neovim v0.10 to use vim.snippet
            -- vim.snippet.expand(args.body)
            require('luasnip').lsp_expand(args.body)
          end
        },
        preselect = 'item',
        completion = {
          autocomplete = false,
          completeopt = 'menu,menuone,noinsert'
        }
      })

      -- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won't work anymore).
      cmp.setup.cmdline({ '/', '?' }, {
        mapping = cmp.mapping.preset.cmdline(),
        sources = {
          { name = 'buffer' }
        }
      })

      -- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
      cmp.setup.cmdline(':', {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({
          { name = 'path' }
        }, {
          { name = 'cmdline' }
        }),
        matching = { disallow_symbol_nonprefix_matching = false }
      })
    end,
  },
}
