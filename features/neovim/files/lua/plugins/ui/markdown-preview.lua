local is_vscode = require('utils').is_vscode
local is_windows = require('utils').is_windows
local is_wsl = require('utils').is_wsl
local get_browser_path = require('utils').get_browser_path

local plug = {
  "iamcco/markdown-preview.nvim",
  cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
  build = "cd app && npm install",
  init = function()
    vim.g.mkdp_filetypes = { "markdown" }
  end,
  ft = { "markdown" },
  enabled = not is_vscode(),
  config = function()
    local browser = get_browser_path()
    if is_windows() then
      vim.g.mkdp_browser = browser
    elseif is_wsl() then
      vim.cmd(string.format([[
        function! OpenBrowserWSL(url)
          call system('"%s" ' . a:url)
        endfunction
      ]], browser))
      vim.g.mkdp_browserfunc = "OpenBrowserWSL"
    else
      vim.g.mkdp_browser = browser
    end
  end,
}

return plug

