vim.keymap.set({ 'n', 'x' }, 'J', '5j')
vim.keymap.set({ 'n', 'x' }, 'K', '5k')
vim.keymap.set({ 'n', 'x' }, '<Leader>m', '%')

vim.keymap.set('n', '<C-Up>', '<cmd>resize +2<CR>')
vim.keymap.set('n', '<C-Down>', '<cmd>resize -2<CR>')
vim.keymap.set('n', '<C-Right>', '<cmd>vertical resize +4<CR>')
vim.keymap.set('n', '<C-Left>', '<cmd>vertical resize -4<CR>')

vim.keymap.set('n', 'n', 'nzz')
vim.keymap.set('n', 'N', 'Nzz')
vim.keymap.set('n', '*', '*zz')
vim.keymap.set('n', '#', '#zz')
vim.keymap.set('n', '<Leader>/', ':noh<CR>')

vim.keymap.set('n', ']q', ':cnext<CR>')
vim.keymap.set('n', '[q', ':cprev<CR>')

vim.keymap.set('n', '<C-p>', ':bp<CR>')
vim.keymap.set('n', '<C-n>', ':bn<CR>')
vim.keymap.set('n', '<C-q>', '<cmd>bd<CR>')
