local keymap = require('utils').keymap
local is_vscode = require('utils').is_vscode

local diffview = {
  'sindrets/diffview.nvim',
  lazy = false,
  enabled = not is_vscode(),
  config = function()
    local actions = require('diffview.actions')
    require('diffview').setup({
      show_help_hints = false,
      file_panel = {
        listing_style = 'tree', -- One of 'list' or 'tree'
        tree_options = {
          flatten_dirs = true,
          folder_statuses = 'never', -- One of 'never', 'only_folded' or 'always'.
        },
        win_config = {
          position = 'bottom',
          height = 10,
          win_opts = {},
        },
      },
      keymaps = {
        file_panel = {
          { 'n', 'e', actions.goto_file_edit, { desc = 'Open the file' } },
          { 'n', 's', actions.toggle_stage_entry, { desc = 'Stage / unstage the selected entry' } },
        },
      },
    })
    keymap('n', '<Leader>hh', '<cmd>DiffviewOpen HEAD<CR>', { desc = '' })
    keymap('n', '<Leader>hf', '<cmd>DiffviewFileHistory %<CR>', { desc = '' })
    keymap('n', '<Leader>hc', '<cmd>DiffviewClose<CR>', { desc = '' })
    keymap('n', '<Leader>hd', '<cmd>Diffview<CR>', { desc = '' })
  end,
}

return diffview
