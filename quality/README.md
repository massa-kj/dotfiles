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
