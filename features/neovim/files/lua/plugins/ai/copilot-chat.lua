local keymap = require('utils').keymap
local is_vscode = require('utils').is_vscode

local copilotchat = {
  'CopilotC-Nvim/CopilotChat.nvim',
  dependencies = {
    { 'github/copilot.vim' }, -- or zbirenbaum/copilot.lua
    { 'nvim-lua/plenary.nvim', branch = 'master' }, -- for curl, log and async functions
  },
  enabled = not is_vscode(),
  config = function()
    require('CopilotChat').setup({
      debug = false,

      window = {
        layout = 'float',
        relative = 'editor',
        width = 0.8,
        height = 0.8,
      },
      mappings = {
        complete = {
          insert = '<Tab>',
        },
        close = {
          normal = 'q',
          insert = '<C-c>',
        },
        reset = {
          normal = '<C-l>',
          insert = '<C-l>',
        },
        submit_prompt = {
          normal = '<CR>',
          insert = '<C-s>',
        },
      },
      prompts = {
        Explain = {
          prompt = '/COPILOT_EXPLAIN Please write a paragraph explaining the code I have selected. Please reply in Japanese.',
          context = 'buffer:current',
        },
        Review = {
          prompt = '/COPILOT_REVIEW Review the selected code.',
          callback = function(response, source) end,
        },
        Fix = {
          prompt = '/COPILOT_FIX This code has a problem. Please rewrite it to fix the bug.',
        },
        Refactor = {
          prompt = 'Please refactor the following code to improve its scalability and readability.',
        },
        Name = {
          prompt = 'Please improve the variable and function names in the selected code.',
        },
        Optimize = {
          prompt = '/COPILOT_REFACTOR Optimize selected code to improve performance and readability.',
        },
        Docs = {
          prompt = '/COPILOT_DOCS Add documentation comments to selected code.',
        },
        Tests = {
          prompt = '/COPILOT_TESTS Write detailed unit test functions for selected code.',
        },
        Translate = {
          prompt = 'Please translate the selected text into Japanese.',
        },
        Commit = {
          prompt = [[
          Please write the commit message of the change.
          The title should be a maximum of 50 characters, and the message should be wrapped at 72 characters.
          Enclose the entire message in a code block in the gitcommit language.
          Format: <type>(<scope>): <subject>
          <scope> is optional.
          feat: (new feature for the user, not a new feature for build script)
          fix: (bug fix for the user, not a fix to a build script)
          docs: (changes to the documentation)
          style: (formatting, missing semi colons, etc; no production code change)
          refactor: (refactoring production code, eg. renaming a variable)
          test: (adding missing tests, refactoring tests; no production code change)
          chore: (updating grunt tasks etc; no production code change)
          ]],
          context = 'git:staged',
        },
      },
    })

    vim.api.nvim_create_user_command('ShowCopilotChatActionPrompt', function()
      local actions = require('CopilotChat.actions')
      require('CopilotChat.integrations.telescope').pick(actions.prompt_actions())
    end, {})

    keymap({ 'n', 'x' }, '<leader>io', '<cmd>ShowCopilotChatActionPrompt<CR>', { desc = '' })
    keymap({ 'n', 'x' }, '<leader>ic', '<cmd>CopilotChatToggle<CR>', { desc = '' })
  end,
}

return copilotchat
