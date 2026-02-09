local is_vscode = require('utils').is_vscode

local indentblankline = {
  'lukas-reineke/indent-blankline.nvim',
  enabled = not is_vscode(),
  config = function()
    require('ibl').setup({
      scope = { show_start = true },
    })
  end,
}

return indentblankline
