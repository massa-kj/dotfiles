local keymap = require('utils').keymap
local is_vscode = require('utils').is_vscode

local cmp = {
  'hrsh7th/nvim-cmp',
  dependencies = {
    'hrsh7th/cmp-nvim-lsp',
    'hrsh7th/cmp-buffer',
    'hrsh7th/cmp-path',
    'hrsh7th/cmp-cmdline',
    'L3MON4D3/LuaSnip', -- Snipet engine
    'saadparwaiz1/cmp_luasnip', -- Completion for LuaSnip
    'onsails/lspkind.nvim',
    'zbirenbaum/copilot.lua',
  },
  event = { 'InsertEnter' },
  enabled = not is_vscode(),
  config = function()
    local cmp = require('cmp')
    local types = require('cmp.types')
    local luasnip = require('luasnip')

    -- setup snipet
    require('luasnip.loaders.from_vscode').lazy_load()

    cmp.setup({
      snippet = {
        expand = function(args)
          luasnip.lsp_expand(args.body)
        end,
      },
      sources = cmp.config.sources({
        { name = 'nvim_lsp' },
        { name = 'luasnip' },
      }, {
        { name = 'buffer' },
        { name = 'path' },
      }),
      mapping = cmp.mapping.preset.insert({
        ['<C-n>'] = cmp.mapping.select_next_item(),
        ['<C-p>'] = cmp.mapping.select_prev_item(),
        ['<C-d>'] = cmp.mapping.scroll_docs(-5),
        ['<C-u>'] = cmp.mapping.scroll_docs(5),
        -- ['<C-.>'] = cmp.mapping.complete(),
        ['<C-e>'] = cmp.mapping.abort(),
        ['<CR>'] = cmp.mapping.confirm({ select = true }),
        -- ['<Tab>'] = cmp.mapping.select_next_item({ behavior = types.cmp.SelectBehavior.Insert }),
        -- ['<S-Tab>'] = cmp.mapping.select_prev_item({ behavior = types.cmp.SelectBehavior.Insert }),
        -- ['<Tab>'] = cmp.mapping(function(fallback)
        -- 	if cmp.visible() then
        -- 		cmp.select_next_item()
        -- 	elseif luasnip.expand_or_jumpable() then
        -- 		luasnip.expand_or_jump()
        -- 	else
        -- 		fallback()
        -- 	end
        -- end, { 'i', 's' }),
        -- ['<S-Tab>'] = cmp.mapping(function(fallback)
        -- 	if cmp.visible() then
        -- 		cmp.select_prev_item()
        -- 	elseif luasnip.jumpable(-1) then
        -- 		luasnip.jump(-1)
        -- 	else
        -- 		fallback()
        -- 	end
        -- end, { 'i', 's' }),
      }),
      experimental = {
        ghost_text = true,
      },
      completion = {
        autocomplete = { types.cmp.TriggerEvent.TextChanged },
        -- keyword_length = 2,
      },
      performance = {
        debounce = 200,
      },
    })
    cmp.setup.cmdline('/', {
      mapping = cmp.mapping.preset.cmdline(),
      sources = {
        { name = 'buffer' },
      },
    })
    cmp.setup.cmdline(':', {
      mapping = cmp.mapping.preset.cmdline(),
      sources = {
        { name = 'path' },
        { name = 'cmdline' },
      },
    })
    keymap('i', '<C-y>', '<Plug>(copilot-accept-line)', { desc = '' })
    keymap('i', '<C-l>', '<Plug>(copilot-accept-word)', { desc = '' })
    keymap('i', '<M-]>', '<Plug>(copilot-next)', { desc = '' })
    keymap('i', '<M-[>', '<Plug>(copilot-previous)', { desc = '' })
    keymap('i', '<M-i>', '<Plug>(copilot-suggest)', { desc = '' })
  end,
}

return cmp
