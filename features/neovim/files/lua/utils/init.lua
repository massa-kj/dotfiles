-- utility functions

local M = {}

function M.is_vscode()
  return vim.g.vscode
end

function M.is_windows()
  return vim.loop.os_uname().sysname == 'Windows_NT'
end

function M.is_wsl()
  return vim.loop.os_uname().release:lower():find('microsoft') ~= nil
end

function M.get_browser_path()
  if M.is_windows then
    return vim.fn.expand('~/windows/scoop/apps/googlechrome/current/chrome.exe')
  elseif M.is_wsl() then
    return vim.fn.expand('~/scoop/apps/googlechrome/current/chrome.exe')
  else
    return "firefox"
  end
end

-- Searches for a specified file by traversing up the directory tree from the current buffer's directory.
-- @param file_name The name of the file to search for.
-- @param include_file_name Boolean indicating whether to include the file name in the returned path.
-- @return The path to the directory containing the file, or the full file path if include_file_name is true. Returns nil if the file is not found.
function M.find_file_path(file_name, include_file_name)
  local current_path = vim.fn.expand('%:p:h')
  while current_path ~= '/' do
    local file_path = current_path .. '/' .. file_name
    if vim.fn.filereadable(file_path) == 1 then
      if include_file_name then
        return file_path
      else
        return current_path
      end
    end
    current_path = vim.fn.fnamemodify(current_path, ':h')
  end
  return nil
end

-- Return mode list as array
local function normalize_modes(mode)
  if type(mode) == 'string' then
    return { mode }
  elseif type(mode) == 'table' then
    return mode
  else
    error('Invalid mode type: ' .. vim.inspect(mode))
  end
end

local keys = {}
M.keymap = function(mode, lhs, rhs, opts)
  opts = opts or {}
  local modes = normalize_modes(mode)

  -- Common default options
  local defaults = { noremap = true, silent = true }
  opts = vim.tbl_deep_extend('force', defaults, opts)

  -- Check duplicate
  for _, m in ipairs(modes) do
    local key = m .. ':' .. lhs
    if keys[key] then
      vim.notify('Duplicate keymap: ' .. key, vim.log.levels.WARN)
    end
    keys[key] = true
  end

  vim.keymap.set(mode, lhs, rhs, opts)
end

function M.get_latest_node_bin_path()
  local node_version = tonumber(vim.fn.system('node --version'):match('v(%d+)'))
  if node_version and node_version < 20 then
    -- Find latest Node version ≥ 20 managed by mise
    local latest_node_path = vim.fn.trim(
      vim.fn.system(
        'mise list node --json | jq -r \'[.[] | select(.version | test("^2[0-9]+"))] | max_by(.version) | .install_path\''
      )
    ) .. '/bin/'

    if latest_node_path ~= '' then
      return latest_node_path
    end
  end
  if M.is_windows() then
    local node_path = vim.fn.system('(Get-Command node).Source'):gsub('[\n\r]*$', '')
    return vim.fn.fnamemodify(node_path, ':h')
  else
    return vim.fn.system('which node'):gsub('[\n\r]*$', ''):gsub('/[^/]+$', '/')
  end
end

return M
