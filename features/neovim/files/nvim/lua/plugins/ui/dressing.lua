local is_vscode = require('utils').is_vscode

local plug = {
  'stevearc/dressing.nvim',
  enabled = not is_vscode(),
  config = function()
    require('dressing').setup({})
  end,
}

return plug
