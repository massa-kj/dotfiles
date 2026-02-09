local keymap = require('utils').keymap
local is_vscode = require('utils').is_vscode

local plug = {
  'stevearc/overseer.nvim',
  -- dependencies = {
  -- 	'nvim-lua/plenary.nvim',
  -- 	'nvim-telescope/telescope.nvim',
  -- },
  enabled = not is_vscode(),
  config = function()
    local overseer = require('overseer')

    -- Get a list of folder names under overseer/template
    local function get_template_folders()
      local template_path = vim.fn.stdpath('config') .. '/lua/overseer/template'
      local folders = {}
      for _, folder in ipairs(vim.fn.readdir(template_path)) do
        if vim.fn.isdirectory(template_path .. '/' .. folder) == 1 then
          table.insert(folders, folder)
        end
      end
      return folders
    end
    local templates = get_template_folders()

    overseer.setup({
      templates = {
        'builtin',
        unpack(templates),
      },
      task_list = {
        direction = 'right',
        max_width = { 200, 0.8 },
        bindings = {
          ['?'] = 'ShowHelp',
          -- ['<CR>'] = 'RunAction',
          -- ['<C-e>'] = 'Edit',
          -- ['o'] = 'Open',
          -- ['<C-v>'] = 'OpenVsplit',
          -- ['<C-s>'] = 'OpenSplit',
          -- ['<C-f>'] = 'OpenFloat',
          -- ['<C-q>'] = 'OpenQuickFix',
          -- ['p'] = 'TogglePreview',
          ['L'] = 'IncreaseDetail',
          ['H'] = 'DecreaseDetail',
          ['<M-l>'] = 'IncreaseAllDetail',
          ['<M-h>'] = 'DecreaseAllDetail',
          -- ['['] = 'DecreaseWidth',
          -- [']'] = 'IncreaseWidth',
          -- ['{'] = 'PrevTask',
          -- ['}'] = 'NextTask',
        },
      },
    })

    vim.api.nvim_create_user_command('OverseerRestartLast', function()
      local tasks = overseer.list_tasks({ recent_first = true })
      if vim.tbl_isempty(tasks) then
        vim.notify('No tasks found', vim.log.levels.WARN)
      else
        overseer.run_action(tasks[1], 'restart')
      end
    end, {})

    keymap('n', '<Leader>to', '<cmd>OverseerToggle<CR>', { desc = '' })
    keymap('n', '<Leader>tr', '<cmd>OverseerRun<CR>', { desc = '' })
    keymap('n', '<Leader>tl', '<cmd>OverseerRestartLast<CR>', { desc = '' })
  end,
}

return plug
