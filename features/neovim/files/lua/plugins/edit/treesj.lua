local keymap = require('utils').keymap

local treesj = {
  'Wansmer/treesj',
  dependencies = { 'nvim-treesitter/nvim-treesitter' }, -- if you install parsers with `nvim-treesitter`
  config = function()
    require('treesj').setup({
      ---@type boolean Use default keymaps (<space>m - toggle, <space>j - join, <space>s - split)
      use_default_keymaps = false,
    })
    keymap('n', '<leader>M', function()
      require('treesj').toggle({ split = { recursive = true } })
    end, { desc = '' })
  end,
}

return treesj
