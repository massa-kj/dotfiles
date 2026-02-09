local is_vscode = require('utils').is_vscode

local fidget = {
  'j-hui/fidget.nvim',
  lazy = false,
  enabled = not is_vscode(),
  config = function()
    require('fidget').setup({})
  end,
}

return fidget
