local keymap = require('utils').keymap

local dial = {
  'monaqa/dial.nvim',
  config = function()
    local augend = require('dial.augend')
    local dial = require('dial.config')

    dial.augends:register_group({
      default = {
        -- Add a custom rule for toggling `true` and `false`
        augend.constant.new({
          elements = { 'true', 'false' }, -- Elements to toggle between
          word = true, -- Match whole words only
          cyclic = true, -- Loop back to the start (e.g., false -> true)
        }),
        -- Preserve other default rules
        augend.integer.alias.decimal, -- Decimal integers
        augend.integer.alias.hex, -- Hexadecimal numbers
        augend.date.alias['%Y/%m/%d'], -- Dates in YYYY/MM/DD format
      },
    })
    keymap('n', '<C-a>', require('dial.map').inc_normal(), { desc = '' })
    keymap('n', '<C-x>', require('dial.map').dec_normal(), { desc = '' })
    keymap('v', '<C-a>', require('dial.map').inc_visual(), { desc = '' })
    keymap('v', '<C-x>', require('dial.map').dec_visual(), { desc = '' })
    keymap('v', 'g<C-a>', require('dial.map').inc_gvisual(), { desc = '' })
    keymap('v', 'g<C-x>', require('dial.map').dec_gvisual(), { desc = '' })
  end,
}

return dial
