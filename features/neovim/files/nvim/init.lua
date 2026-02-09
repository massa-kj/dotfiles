local is_windows = require('utils').is_windows
local is_vscode = require('utils').is_vscode

require('core')

if is_windows() then
  local pwsh_options = {
    shell = vim.fn.executable('pwsh') == 1 and 'pwsh' or 'powershell',
    shellcmdflag = '-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command [Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.Encoding]::UTF8;',
    shellredir = '-RedirectStandardOutput %s -NoNewWindow -Wait',
    shellpipe = '2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode',
    shellquote = '',
    shellxquote = '',
  }

  for k, v in pairs(pwsh_options) do
    vim.opt[k] = v
  end
end

if is_vscode() then
  require('core/vscode-keymaps')
end

require('plugins/lazy')
