local is_vscode = require('utils').is_vscode

local plug = {
  'nvim-zh/colorful-winsep.nvim',
  event = { 'WinLeave' },
  enabled = not is_vscode(),
  config = function()
    require('colorful-winsep').setup({
      hi = {
        bg = '',
        fg = '#E8AEAA',
      },
    })
  end,
}

return plug
