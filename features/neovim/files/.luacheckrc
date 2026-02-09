std = "lua51"
globals = {
  "vim",                   -- Neovim API (vim.*)
  "require",               -- Usually not needed, but allowed for safety
}
unused_args = false        -- Disable warnings for unused function arguments (to keep function signatures)
allow_defined_top = true   -- Allow top-level variables defined in the file
ignore = {
  "631",                   -- Ignore warnings about using variables outside if statements
  "111",                   -- Ignore global variable redefinition (e.g., with vim.keymap.set)
}
