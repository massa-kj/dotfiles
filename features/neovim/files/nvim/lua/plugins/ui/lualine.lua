local is_vscode = require('utils').is_vscode

local lualine = {
  'nvim-lualine/lualine.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  enabled = not is_vscode(),
  config = function()
    require('lualine').setup({
      options = {
        theme = 'auto',
        section_separators = '',
        component_separators = '',
      },
      sections = {
        lualine_a = { 'mode' },
        lualine_b = { 'branch' },
        lualine_c = {
          {
            'filename',
            path = 1,
            shorting_target = 40,
            file_status = true,
            symbols = {
              modified = '[+]',
              readonly = '[-]',
              unnamed = '[No name]',
            },
          },
          -- {
          -- 	'diagnostics',
          -- 	sources = { 'nvim_lsp' },
          -- 	symbols = { error = ' ', warn = ' ', info = ' ' },
          -- }
        },
        lualine_x = { 'encoding', 'fileformat', 'filetype' },
        lualine_y = { 'progress' },
        lualine_z = { 'location' },
      },
    })
  end,
}

return lualine
