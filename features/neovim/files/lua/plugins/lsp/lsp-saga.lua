local is_vscode = require('utils').is_vscode

local plug = {
  'nvimdev/lspsaga.nvim',
  dependencies = {
    'nvim-treesitter/nvim-treesitter', -- optional
    'nvim-tree/nvim-web-devicons', -- optional
  },
  enabled = not is_vscode(),
  config = function()
    require('lspsaga').setup({
      symbol_in_winbar = {
        enable = false,
      },
    })
  end,
}

return plug
