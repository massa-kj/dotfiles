local is_vscode = require('utils').is_vscode

local kanagawa = {
  'rebelot/kanagawa.nvim',
  enabled = not is_vscode(),
  config = function()
    require('kanagawa').setup({
      vim.cmd([[colorscheme kanagawa-wave]]),
      -- vim.cmd[[colorscheme kanagawa-dragon]]
    })
  end,
}

return kanagawa
