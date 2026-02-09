local is_vscode = require('utils').is_vscode

local nvimtree = {
  'nvim-tree/nvim-tree.lua',
  version = '*',
  lazy = false,
  dependencies = {
    'nvim-tree/nvim-web-devicons',
  },
  enabled = not is_vscode(),
  config = function()
    require('nvim-tree').setup({
      update_focused_file = {
        enable = true,
        update_cwd = false,
      },
      view = {
        width = '30%',
        side = 'left',
      },
      git = {
        enable = false,
        ignore = false,
      },
    })
  end,
  keys = {
    { mode = 'n', '<Leader>ee', '<cmd>NvimTreeToggle<CR>' },
    { mode = 'n', '<Leader>er', '<cmd>NvimTreeCollapseKeepBuffers<CR>' },
    { mode = 'n', '<Leader>ec', '<cmd>NvimTreeFindFileToggle<CR>' },
  },
}

return nvimtree
