local is_vscode = require('utils').is_vscode

local plug = {
  'ray-x/lsp_signature.nvim',
  event = 'VeryLazy',
  enabled = not is_vscode(),
  config = function(_, opts)
    require('lsp_signature').setup(opts)
  end,
}

return plug
