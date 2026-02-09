local is_vscode = require('utils').is_vscode

local toggleterm = {
  'akinsho/toggleterm.nvim',
  lazy = false,
  enabled = not is_vscode(),
  config = function()
    require('toggleterm').setup({
      open_mapping = [[<C-t>]],
      start_in_insert = true,
      insert_mappings = false,
      persist_size = true,
      direction = 'float',
    })
  end,
}

return toggleterm
