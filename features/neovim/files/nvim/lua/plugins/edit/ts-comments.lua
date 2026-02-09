local is_vscode = require('utils').is_vscode

local tscomments = {
  'folke/ts-comments.nvim',
  event = 'VeryLazy',
  enabled = vim.fn.has('nvim-0.10.0') == 1 and not is_vscode(),
  config = function()
    require('ts-comments').setup({})
  end,
}

return tscomments
