local find_file_path = require('utils').find_file_path

return {
  name = 'pnpm sample',
  builder = function(params)
    return {
      cmd = 'pnpm',
      args = { '-F', params.package, 'run', 'test' },
      -- env = {
      -- 	NODE_ENV = params.node_env or 'production',
      -- },
      cwd = find_file_path('Cargo.toml', false),
      components = {
        { 'default' },
        -- { 'on_output_quickfix', open = true },
        -- { 'on_result_diagnostics_quickfix', open = true },
        { 'display_duration' },
      },
      -- on_complete = function(task)
      -- 	vim.notify('Task Completed: ' .. task.name, vim.log.levels.INFO)
      -- end,
    }
  end,
  params = {
    package = {
      type = 'string',
      prompt = 'Arguments',
      default = 'package_prefix',
      optional = false,
      description = 'Which test tot run',
    },
  },
  condition = {
    -- filetype = { 'rs' },
    callback = function()
      -- Enable the task only if Cargo.toml exists
      local path = find_file_path('Cargo.toml', false)
      return path
    end,
  },
}
