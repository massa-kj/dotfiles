local is_vscode = require('utils').is_vscode

local comment = {
  'numToStr/Comment.nvim',
  enabled = not is_vscode(),
  config = function()
    require('Comment').setup({})
  end,
}

return comment
