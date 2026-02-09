local keymap = require('utils').keymap

local flash = {
  'folke/flash.nvim',
  event = 'VeryLazy',
  config = function()
    require('flash').setup({
      search = {
        -- Each mode will take ignorecase and smartcase into account.
        -- * exact: exact match
        -- * search: regular search
        -- * fuzzy: fuzzy search
        -- * fun(str): custom function that returns a pattern
        --   For example, to only match at the beginning of a word:
        --   mode = function(str)
        --     return '\\<' .. str
        --   end,
        mode = 'exact',
      },
      label = {
        reuse = 'none', ---@type 'lowercase' | 'all' | 'none'
        -- for the current window, label targets closer to the cursor first
        distance = true,
        -- position of the label extmark
        style = 'overlay', ---@type 'eol' | 'overlay' | 'right_align' | 'inline'
      },
      highlight = { backdrop = false },
    })
    keymap({ 'n', 'x' }, 's', function()
      require('flash').jump()
    end, { desc = '' })
    keymap({ 'n', 'x' }, 'S', function()
      require('flash').jump({ continue = true })
    end, { desc = '' })
  end,
}

return flash
