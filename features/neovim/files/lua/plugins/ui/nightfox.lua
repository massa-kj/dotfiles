local is_vscode = require('utils').is_vscode

local nightfox = {
  'EdenEast/nightfox.nvim',
  enabled = not is_vscode(),
  config = function()
    require('nightfox').setup({
      vim.cmd([[colorscheme nightfox]]),
      -- vim.cmd[[colorscheme duskfox]]
      -- vim.cmd[[colorscheme nordfox]]
    })
  end,
}

return nightfox
