local is_vscode = require('utils').is_vscode
local get_latest_node_bin_path = require('utils').get_latest_node_bin_path

local lspconfig = {
  'neovim/nvim-lspconfig',
  dependencies = {
    { 'hrsh7th/cmp-nvim-lsp' },
  },
  -- lazy = false,
  -- priority = 1000
  event = { 'BufReadPre', 'BufNewFile' },
  enabled = not is_vscode(),
  config = function()
    local lspconfig = require('lspconfig')

    -- Settings for LSP Complement
    local capabilities = require('cmp_nvim_lsp').default_capabilities()

    local on_attach = function(client, bufnr)
      local bufopts = { noremap = true, silent = true, buffer = bufnr }
      vim.keymap.set('n', 'gd', vim.lsp.buf.definition, bufopts)
      vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, bufopts)
      vim.keymap.set('n', 'gr', vim.lsp.buf.references, bufopts)
      vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, bufopts)
      vim.keymap.set('n', '<Leader>k', vim.lsp.buf.hover, bufopts)
      vim.keymap.set('n', '<Leader>ar', vim.lsp.buf.rename, bufopts)
      vim.keymap.set('n', '<Leader>aa', vim.lsp.buf.code_action, bufopts)
      vim.keymap.set('n', '<Leader>ae', vim.diagnostic.open_float, bufopts)
      vim.keymap.set('n', ']g', vim.diagnostic.goto_next, bufopts)
      vim.keymap.set('n', '[g', vim.diagnostic.goto_prev, bufopts)
      vim.lsp.handlers['textDocument/publishDiagnostics'] =
        vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, { virtual_text = false })
    end

    -- Individual settings for each server
    local servers = {
      rust_analyzer = {
        filetypes = { 'rust' },
        cmd = { 'rust-analyzer' },
        capabilities = capabilities,
        on_attach = on_attach,
        -- cmd = { '/usr/local/bin/rust-analyzer' },
        settings = {
          -- ['rust-analyzer'] = {
          -- 		checkOnSave = { command = 'clippy' },
          -- },
        },
      },
      ts_ls = {
        filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
        cmd = {
          get_latest_node_bin_path() .. 'node',
          get_latest_node_bin_path() .. 'typescript-language-server',
          '--stdio',
        },
        capabilities = capabilities,
        on_attach = on_attach,
        settings = {
          completions = { completeFunctionCalls = true },
        },
      },
      -- omnisharp = {
      -- 	filetypes = { 'cs' },
      -- 	capabilities = capabilities,
      -- 	on_attach = on_attach,
      -- 	cmd = { 'omnisharp' },
      -- 	root_dir = lspconfig.util.root_pattern('.sln', '.csproj', '.git'),
      -- },
      pylsp = {
        filetypes = { 'python' },
        cmd = { 'pylsp' },
        apabilities = capabilities,
        on_attach = on_attach,
      },
      lua_ls = {
        filetypes = { 'lua' },
        cmd = { 'lua-language-server' },
        capabilities = capabilities,
        on_attach = on_attach,
        settings = {
          Lua = {
            diagnostics = {
              globals = { 'vim' },
            },
            workspace = { library = vim.api.nvim_get_runtime_file('', true) },
          },
        },
      },
    }

    -- Apply settings for each server
    for server, opts in pairs(servers) do
      opts = opts or {}
      lspconfig[server].setup(opts)
    end

    -- require('nvim-lspconfig').setup({
    -- })
  end,
}

return lspconfig
