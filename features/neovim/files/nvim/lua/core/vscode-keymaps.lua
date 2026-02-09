-- Move to next tab
vim.api.nvim_set_keymap('n', '<leader>l', ":call VSCodeNotify('workbench.action.nextEditor')<CR>", { noremap = true, silent = true })
-- Move to previous tab
vim.api.nvim_set_keymap('n', '<leader>h', ":call VSCodeNotify('workbench.action.previousEditor')<CR>", { noremap = true, silent = true })
-- Close the buffer (file)
vim.api.nvim_set_keymap('n', '<leader>q', ":call VSCodeNotify('workbench.action.closeActiveEditor')<CR>", { noremap = true, silent = true })
-- Open Recent
vim.api.nvim_set_keymap('n', '<leader>fw', ":call VSCodeNotify('workbench.action.openRecent')<CR>", { noremap = true, silent = true })

-- Open Explorer pane
vim.api.nvim_set_keymap('n', '<leader>fe', ":call VSCodeNotify('workbench.view.explorer')<CR>", { noremap = true, silent = true })

-- Open Search pane
vim.api.nvim_set_keymap('n', '<leader>fa', ":call VSCodeNotify('workbench.view.search')<CR>", { noremap = true, silent = true })

-- Open git pane
vim.api.nvim_set_keymap('n', '<leader>g', ":call VSCodeNotify('workbench.view.scm')<CR>", { noremap = true, silent = true })

-- Open terminal pane
vim.api.nvim_set_keymap('n', '<C-t>', ":call VSCodeNotify('workbench.action.terminal.toggleTerminal')<CR>", { noremap = true, silent = true })

-- Open Copilot Chat window
-- @command:workbench.action.chat.open +when:chatPanelParticipantRegistered
vim.api.nvim_set_keymap('n', '<leader>ic', ":call VSCodeNotify('workbench.action.chat.open')<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap('x', '<leader>ic', ":call VSCodeNotify('workbench.action.chat.open')<CR>", { noremap = true, silent = true })
-- @command:workbench.action.chat.openInNewWindow +when:chatIsEnabled
vim.api.nvim_set_keymap('n', '<leader>iw', ":call VSCodeNotify('workbench.action.chat.openInNewWindow')<CR>", { noremap = true, silent = true })
-- @command:inlineChat.start +when:inlineChatHasProvider && inlineChatPossible && !editorReadonly
vim.api.nvim_set_keymap('n', '<leader>ii', ":call VSCodeNotify('inlineChat.start')<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap('v', '<leader>ii', ":call VSCodeNotify('inlineChat.start')<CR>", { noremap = true, silent = true })
