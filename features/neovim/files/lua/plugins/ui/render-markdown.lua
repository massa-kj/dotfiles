local is_vscode = require('utils').is_vscode

local rendermarkdown = {
  'MeanderingProgrammer/render-markdown.nvim',
  dependencies = {
    'nvim-treesitter/nvim-treesitter',
    'nvim-tree/nvim-web-devicons',
  },
  enabled = not is_vscode(),
  config = function()
    require('render-markdown').setup({})
  end,
}

return rendermarkdown
