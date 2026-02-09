local is_vscode = require('utils').is_vscode

local plug = {
  'kevinhwang91/nvim-bqf',
  ft = 'qf',
  enabled = not is_vscode(),
}

return plug
