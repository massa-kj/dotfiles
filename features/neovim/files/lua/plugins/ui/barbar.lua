local is_vscode = require('utils').is_vscode

local barbar = {
  'romgrk/barbar.nvim',
  dependencies = {
    'lewis6991/gitsigns.nvim', -- OPTIONAL: for git status
    'nvim-tree/nvim-web-devicons', -- OPTIONAL: for file icons
  },
  init = function()
    vim.g.barbar_auto_setup = false
  end,
  enabled = not is_vscode(),
  config = function()
    require('barbar').setup({})
  end,
}

return barbar
