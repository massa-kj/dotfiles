local function set_filetype_autocmds(pattern, tabstop, expandtab)
  vim.api.nvim_create_autocmd('FileType', {
    group = 'FileTypeSpecificSettings',
    pattern = pattern,
    callback = function()
      vim.opt_local.tabstop = tabstop
      vim.opt_local.softtabstop = tabstop
      vim.opt_local.shiftwidth = tabstop
      vim.opt_local.expandtab = expandtab
    end,
  })
end

vim.api.nvim_create_augroup('FileTypeSpecificSettings', { clear = true })

-- Define filetype-specific settings
set_filetype_autocmds('astro', 2, true)
set_filetype_autocmds('cs', 4, false)
set_filetype_autocmds('css', 2, true)
set_filetype_autocmds('scss', 4, false)
set_filetype_autocmds('html', 2, true)
set_filetype_autocmds({ 'javascript', 'javascriptreact' }, 4, false)
set_filetype_autocmds('json', 2, true)
set_filetype_autocmds('lua', 2, true)
set_filetype_autocmds('markdown', 2, true)
set_filetype_autocmds('rust', 4, true)
set_filetype_autocmds('sh', 4, true)
set_filetype_autocmds({ 'typescript', 'typescriptreact' }, 2, false)
