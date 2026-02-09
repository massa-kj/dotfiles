local is_vscode = require('utils').is_vscode

local ale = {
  'dense-analysis/ale',
  event = { 'BufRead', 'BufNewFile' },
  enabled = not is_vscode(),
  config = function()
    vim.g.ale_linters = {
      javascript = { 'eslint' },
      typescript = { 'eslint' },
      typescriptreact = { 'eslint' },
      javascriptreact = { 'eslint' },
      -- cs = {'omnisharp'},
      -- ['css'] = ['stylelint'],
      -- ['scss'] = ['stylelint'],
      -- ['html'] = ['htmlhint'],
      -- ['json'] = ['jsonlint'],
      -- ['markdown'] = ['markdownlint'],
      lua = { 'luacheck' },
      -- ['yaml'] = ['yamllint'],
      -- ['rust'] = ['cargo'],
    }

    vim.g.ale_fix_on_save = 0

    -- vim.g.ale_sign_error = '✗'
    -- vim.g.ale_sign_warning = '⚠'
    vim.g.ale_sign_error = '>>'
    vim.g.ale_sign_warning = '--'

    vim.g.ale_sign_column_always = 1

    vim.g.ale_statusline_format = {
      errors = 'E:%d',
      warnings = 'W:%d',
    }

    vim.g.ale_virtualtext_cursor = 1

    vim.g.ale_lint_on_enter = 1
    vim.g.ale_lint_on_text_changed = 'always'
  end,
}

return ale
