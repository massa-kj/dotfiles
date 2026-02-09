local is_vscode = require('utils').is_vscode

local tokyonight = {
  'folke/tokyonight.nvim',
  enabled = not is_vscode(),
  config = function()
    require('tokyonight').setup({
      transparent = true,
      styles = {
        sidebars = 'transparent',
        floats = 'transparent',
      },
    })
    vim.cmd([[colorscheme tokyonight-moon]])
  end,
}

return tokyonight
