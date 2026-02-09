local is_vscode = require('utils').is_vscode

local treesitter = {
  'nvim-treesitter/nvim-treesitter',
  dependencies = {
    'nvim-treesitter/nvim-treesitter-textobjects',
  },
  build = ':TSUpdate',
  install = function()
    require('nvim-treesitter.install').setup({
      prefer_git = false,
      compilers = { 'gcc' },
    })
  end,
  config = function()
    require('nvim-treesitter.configs').setup({
      auto_install = false,
      ensure_installed = {
        'bash',
        'c',
        'c_sharp',
        'cpp',
        'css',
        'diff',
        'dockerfile',
        'gitcommit',
        'gitignore',
        'go',
        'html',
        'ini',
        'javascript',
        'jsdoc',
        'json',
        'lua',
        'make',
        'markdown',
        'markdown_inline',
        'mermaid',
        'python',
        'query',
        'rust',
        'scss',
        'sql',
        'typescript',
        'tsx',
        'toml',
        'vim',
        'vimdoc',
        'yaml',
      },
      highlight = {
        enable = not is_vscode(),
        additional_vim_regex_highlighting = false,
      },
      indent = {
        enable = not is_vscode(),
      },
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = 'gnn',
          scope_incremental = 'gns',
          node_incremental = '+',
          node_decremental = '-',
        },
      },
    })
  end,
}

return treesitter
