vim.api.nvim_set_var('mapleader', ' ')

vim.opt.clipboard = 'unnamedplus'
vim.opt.swapfile = false
vim.opt.signcolumn = 'yes'
vim.opt.laststatus = 3

vim.opt.ignorecase = true
vim.opt.smartcase = true
-- vim.opt.incsearch = true

-- ui
vim.opt.number = true
vim.opt.cursorline = true
vim.opt.termguicolors = true
vim.opt.pumblend = 10
vim.opt.winblend = 20

-- wrap lines
vim.opt.wrap = true
vim.opt.breakindent = true
vim.opt.showbreak = '↪ '

-- indenting
vim.opt.autoindent = true
vim.opt.smartindent = true
vim.opt.smarttab = true

vim.opt.expandtab = false
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
