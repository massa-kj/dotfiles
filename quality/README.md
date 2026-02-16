# Quality Assurance Tools

Development tools for maintaining code quality and documentation consistency.

## Scripts

### gen_api_md.py

Generates API documentation from source code comments.

**Usage:**

```bash
python3 quality/gen_api_md.py [--warn]
```

**Options:**

- `--warn`: Show warnings for missing documentation sections

**Output:**

- `docs/API.bash.md` - Bash API reference
- `docs/API.ps1.md` - PowerShell API reference

**Source Format:**

Requires module headers with API signatures and function comments:

```bash
# Module: example
# Public API (Stable):
#   function_name <arg1> [optional_arg]

# function_name <arg1> [optional_arg]
# Brief description of the function.
function_name() {
    # implementation
}
```

### lint.sh

Runs code quality checks on Neovim configuration.

**Usage:**

```bash
bash quality/lint.sh
```

**Checks:**

- `stylua` - Lua code formatting
- `luacheck` - Lua static analysis

## Adding New Tools

Place new quality assurance scripts in this directory and document them here with:

- Tool name and purpose
- Usage command
- Key options/flags
- Expected output or side effects
