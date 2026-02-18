# Quality Assurance Tools

Development tools for maintaining code quality and documentation consistency.

## Test Suites

### Docker-based Integration Tests

See [docker/README.md](docker/README.md) for Docker-based integration testing.

Tests verify state guarantees in isolated environments:
- Basic execution (minimal)
- Idempotent behavior
- Safe uninstall
- Version specification features

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

Runs code quality checks on profiles and Neovim configuration.

**Usage:**

```bash
bash quality/lint.sh
```

**Checks:**

- Profile format validation (YAML syntax and schema)
  - Ensures `features` is a map (not array)
  - Validates feature entries are maps or null
- `stylua` - Lua code formatting (Neovim config)
- `luacheck` - Lua static analysis (Neovim config)

## Adding New Tools

Place new quality assurance scripts in this directory and document them here with:

- Tool name and purpose
- Usage command
- Key options/flags
- Expected output or side effects
