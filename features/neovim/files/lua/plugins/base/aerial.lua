local keymap = require('utils').keymap
local is_vscode = require('utils').is_vscode

local aerial = {
  'stevearc/aerial.nvim',
  dependencies = {
    'nvim-treesitter/nvim-treesitter',
    'nvim-tree/nvim-web-devicons',
  },
  enabled = not is_vscode(),
  config = function()
    require('aerial').setup({
      layout = {
        default_direction = 'prefer_right',
      },
      keymaps = {
        ['<CR>'] = 'actions.jump',
        ['l'] = 'actions.jump',
      },
    })
    keymap('n', 'gO', '<cmd>AerialToggle!<CR>', { desc = 'Aerial toggle' })
    keymap('n', ']o', '<cmd>AerialNext<CR>', { desc = '' })
    keymap('n', '[o', '<cmd>AerialPrev<CR>', { desc = '' })
  end,
}

return aerial
