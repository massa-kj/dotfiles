local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out =
    vim.fn.system({ 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { 'Failed to clone lazy.nvim:\n', 'ErrorMsg' },
      { out, 'WarningMsg' },
      { '\nPress any key to exit...' },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

local plugins = {
  -- ai
  require('plugins/ai/copilot'),
  require('plugins/ai/copilot-chat'),

  -- base
  require('plugins/base/aerial'),
  require('plugins/base/toggleterm'),
  require('plugins/base/treesitter'),
  require('plugins/base/fidget'),
  require('plugins/base/autosession'),
  require('plugins/base/bufferline'),
  require('plugins/base/telescope'),
  require('plugins/base/oil'),
  -- require('plugins/base/nvim-tree'),
  require('plugins/base/overseer'),
  require('plugins/base/nvim-notify'),
  require('plugins/base/nvim-bqf'),

  -- edit
  require('plugins/edit/autopairs'),
  require('plugins/edit/dial'),
  require('plugins/edit/flash'),
  require('plugins/edit/nvim-surround'),
  require('plugins/edit/treesj'),
  require('plugins/edit/cursorword'),

  require('plugins/edit/ts-comments'),
  require('plugins/edit/ts-autotag'),

  -- git
  require('plugins/git/diffview'),
  require('plugins/git/gitsigns'),

  -- lsp
  require('plugins/lsp/lspconfig'),
  require('plugins/lsp/nvim-cmp'),
  -- require('plugins/lsp/nvim-dap'),
  require('plugins/lsp/lsp-signature'),
  require('plugins/lsp/lsp-saga'),
  -- require('plugins/lsp/neotest'),
  -- require('plugins/lsp/vimtest'),
  -- lint
  require('plugins/lsp/ale'),

  -- require({ 'simrat39/rust-tools.nvim' }),
  -- require({ 'jose-elias-alvarez/typescript.nvim' }),

  -- ui
  require('plugins/ui/tokyonight'),
  -- require('plugins/ui/nightfox'),
  -- require('plugins/ui/kanagawa'),

  require('plugins/ui/indent-blankline'),
  require('plugins/ui/lualine'),
  require('plugins/ui/markdown-preview'),
  -- require('plugins/ui/render-markdown'),
  require('plugins/ui/dressing'),
  require('plugins/ui/winsep'),

  -- require('folke/which-key.nvim'),
}

require('lazy').setup(plugins)
