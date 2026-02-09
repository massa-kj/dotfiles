local is_vscode = require('utils').is_vscode
local get_latest_node_bin_path = require('utils').get_latest_node_bin_path

-- local copilot = {
-- 	'github/copilot.vim',
-- 	lazy = false,
-- }

local copilot = {
  'zbirenbaum/copilot.lua',
  cmd = 'Copilot',
  event = 'InsertEnter',
  enabled = not is_vscode(),
  init = function()
    vim.g.copilot_node_command = vim.fs.joinpath(get_latest_node_bin_path(), 'node')
  end,
  config = function()
    require('copilot').setup({
      copilot_node_command = vim.fs.joinpath(get_latest_node_bin_path(), 'node'),
    })
  end,
}

return copilot
