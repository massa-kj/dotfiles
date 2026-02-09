local is_vscode = require('utils').is_vscode

local tsautotag = {
  'windwp/nvim-ts-autotag',
  event = 'VeryLazy',
  enabled = vim.fn.has('nvim-0.10.0') == 1 and not is_vscode(),
  config = function()
    require('nvim-ts-autotag').setup({
      opts = {
        enable_close = true,
        enable_rename = true,
        enable_close_on_slash = false,
      },
    })
  end,
}

return tsautotag
