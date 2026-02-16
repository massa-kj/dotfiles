#!/usr/bin/env python3
"""
Minimal API doc generator for dotfiles core modules.

Spec (minimal):
- Module header exists and is a contiguous "#" comment block.
- Header contains:
  - "Module: <name>"
  - "Public API (Stable):" followed by signature lines (optional but section required)
  - "Public API (Internal):" optional section
- Stable API signatures are written as one line, e.g.:
    state_add_file <feature> <absolute_path>
- For each Stable API function, there MUST be a 1-3 line comment immediately above
  the function definition in the same file:
    # state_add_file <feature> <absolute_path>
    # Registers a file path under a feature in state.
    # (optional 2nd-3rd description lines if essential)

PowerShell:
- Same "# ..." comment format.
- Function definition: "function name" (supports braces on same line or next)
Bash:
- Function definition: "name() {" or "function name {" or "function name() {"
"""

from __future__ import annotations

import argparse
import dataclasses
import re
import sys
from pathlib import Path
from typing import Iterable, List, Optional, Tuple, Dict, Set


# ----------------------------
# Configuration
# ----------------------------

# Default output directory relative to repository root
DEFAULT_OUTPUT_DIR = "docs"

# Default output filenames
DEFAULT_BASH_OUTPUT = "API.bash.md"
DEFAULT_PS_OUTPUT = "API.ps1.md"


# ----------------------------
# Data models
# ----------------------------

@dataclasses.dataclass(frozen=True)
class Signature:
    name: str
    args: Tuple[str, ...]  # tokens like "<feature>"

    @property
    def text(self) -> str:
        if self.args:
            return f"{self.name} " + " ".join(self.args)
        return self.name


@dataclasses.dataclass
class FunctionDoc:
    signature: Signature
    description: str  # may contain multiple lines joined by space or newline
    line_no: int  # 1-based line number where the signature comment appears


@dataclasses.dataclass
class ModuleDoc:
    file_path: Path
    module_name: str
    lang: str  # "bash" or "powershell"
    responsibility: Optional[str]
    stable_apis: List[Signature]
    internal_apis: List[Signature]
    function_docs: Dict[str, FunctionDoc]  # key=function name


# ----------------------------
# Parsing helpers
# ----------------------------

# Header parsing: Matches any line starting with "#"
RE_HEADER_LINE = re.compile(r"^\s*#(.*)$")

# Module name: "# Module: state"
RE_MODULE = re.compile(r"^\s*#\s*Module:\s*(?P<name>.+?)\s*$")

# Responsibility section marker: "# Responsibility:"
RE_RESPONSIBILITY = re.compile(r"^\s*#\s*Responsibility:\s*$")

# Stable API section marker: "# Public API (Stable):"
RE_SECTION_STABLE = re.compile(r"^\s*#\s*Public API\s*\(Stable\):\s*$")

# Internal API section marker: "# Public API (Internal):"
RE_SECTION_INTERNAL = re.compile(r"^\s*#\s*Public API\s*\(Internal\):\s*$")

# Separator line: "# -------------"
RE_SEPARATOR = re.compile(r"^\s*#\s*-{5,}\s*$")

# API signature in header: "# state_init" or "# state_add_file <feature> <path>"
# Supports both snake_case (Bash) and kebab-case (PowerShell)
# Also supports optional args in square brackets: [version]
RE_SIGNATURE = re.compile(
    r"^\s*#\s*(?P<name>[A-Za-z][A-Za-z0-9_-]*)"
    r"(?:\s+(?P<args>(?:(?:<[^>]+>|\[[^\]]+\])\s*)+))?\s*$"
)

# Function comment signature line: same format as RE_SIGNATURE but before function def
RE_FUNC_COMMENT_SIG = re.compile(
    r"^\s*#\s*(?P<name>[A-Za-z][A-Za-z0-9_-]*)"
    r"(?:\s+(?P<args>(?:(?:<[^>]+>|\[[^\]]+\])\s*)+))?\s*$"
)

# Function comment description line: any non-empty comment line
RE_FUNC_COMMENT_DESC = re.compile(r"^\s*#\s*(?P<desc>\S.*)\s*$")

# Bash function definition: "name() {" or "function name {" or "function name() {"
RE_BASH_FUNC = re.compile(
    r"^\s*(?:function\s+)?(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*(?:\(\s*\))?\s*\{?\s*$"
)

# PowerShell function definition: "function Name-With-Hyphens"
RE_PS_FUNC = re.compile(
    r"^\s*function\s+(?P<name>[A-Za-z][A-Za-z0-9_-]*)\b.*$",
    re.IGNORECASE,
)

def _split_args(arg_blob: Optional[str]) -> Tuple[str, ...]:
    """Parse argument string like '<feature> <path> [version]' into tuple of tokens."""
    if not arg_blob:
        return tuple()
    tokens = [t.strip() for t in arg_blob.strip().split() if t.strip()]
    return tuple(tokens)

def _detect_language(path: Path) -> str:
    """Detect language from file extension (.sh -> bash, .ps1 -> powershell)."""
    ext = path.suffix.lower()
    if ext == ".sh":
        return "bash"
    if ext == ".ps1":
        return "powershell"
    return "unknown"

def _is_function_definition(line: str, lang: str) -> Optional[str]:
    """Check if line is a function definition, return function name if match."""
    if lang == "bash":
        m = RE_BASH_FUNC.match(line)
        return m.group("name") if m else None
    if lang == "powershell":
        m = RE_PS_FUNC.match(line)
        return m.group("name") if m else None
    return None


# ----------------------------
# Core parsing
# ----------------------------

class SpecError(Exception):
    """Raised when module does not conform to documentation spec."""
    pass


def _extract_header_block(lines: List[str]) -> List[str]:
    """Extract the first contiguous comment block from file (module header)."""
    i = 0
    # Skip leading blank lines
    while i < len(lines) and lines[i].strip() == "":
        i += 1
    
    # Collect all consecutive comment lines
    header_lines: List[str] = []
    while i < len(lines):
        if RE_HEADER_LINE.match(lines[i]):
            header_lines.append(lines[i])
            i += 1
        else:
            break
    
    return header_lines


def _extract_module_name(header_lines: List[str], path: Path) -> str:
    """Extract module name from header, raise SpecError if missing."""
    for line in header_lines:
        m = RE_MODULE.match(line)
        if m:
            return m.group("name").strip()
    raise SpecError(f"{path}: header missing 'Module: <name>' line")


def _extract_responsibility(header_lines: List[str]) -> Optional[str]:
    """Extract responsibility description if present in header."""
    resp_idx = None
    for idx, line in enumerate(header_lines):
        if RE_RESPONSIBILITY.match(line):
            resp_idx = idx
            break
    
    if resp_idx is None:
        return None
    
    # Find next non-empty comment line after "Responsibility:"
    j = resp_idx + 1
    while j < len(header_lines) and header_lines[j].strip() in ("#", "# "):
        j += 1
    
    if j < len(header_lines):
        m = RE_HEADER_LINE.match(header_lines[j])
        if m:
            body = m.group(1).strip()
            if body:
                return body
    
    return None


def _parse_api_section(header_lines: List[str], start_idx: int) -> List[Signature]:
    """Parse API signatures from a header section (Stable or Internal)."""
    signatures: List[Signature] = []
    k = start_idx + 1
    
    while k < len(header_lines):
        line = header_lines[k]
        
        # Stop at next section marker
        if (RE_SECTION_INTERNAL.match(line) or 
            RE_SECTION_STABLE.match(line) or 
            RE_RESPONSIBILITY.match(line) or 
            RE_MODULE.match(line)):
            break
        
        # Try to parse as signature
        m = RE_SIGNATURE.match(line)
        if m:
            name = m.group("name")
            args = _split_args(m.group("args"))
            signatures.append(Signature(name=name, args=args))
        
        k += 1
    
    return signatures


def _find_function_comment(lines: List[str], func_idx: int, func_name: str, lang: str) -> Tuple[Optional[str], List[str], int]:
    """
    Search backwards from function definition to find signature + description comment block.
    
    Returns: (signature_line, description_lines, signature_line_index)
             or (None, [], -1) if not found
    """
    # Search backwards up to 20 lines
    for test_idx in range(func_idx - 1, max(-1, func_idx - 20), -1):
        if test_idx < 0:
            break
        
        test_line = lines[test_idx]
        
        # Stop at blank line
        if test_line.strip() == "":
            break
        
        # Check if this is the signature line we're looking for
        ms = RE_FUNC_COMMENT_SIG.match(test_line)
        if ms and ms.group("name") == func_name:
            # Found signature line, collect description lines below it
            desc_lines: List[str] = []
            for desc_idx in range(test_idx + 1, func_idx):
                desc_line = lines[desc_idx]
                m_desc = RE_FUNC_COMMENT_DESC.match(desc_line)
                if not m_desc:
                    break
                desc_lines.append(m_desc.group("desc").strip())
            
            return (test_line, desc_lines, test_idx)
        
        # If not a comment line, stop searching
        if not RE_FUNC_COMMENT_DESC.match(test_line):
            break
    
    return (None, [], -1)


def parse_module(path: Path, strict: bool = True) -> ModuleDoc:
    """
    Parse a core module file and extract documentation.
    
    Steps:
    1. Extract module header (name, responsibility, API lists)
    2. For each Stable API, find and validate function comment block
    3. Verify all declared APIs have implementations with proper docs
    
    Args:
        path: Path to .sh or .ps1 file
        strict: If True, raise SpecError on violations; if False, collect warnings
    
    Returns:
        ModuleDoc with all extracted information
    """
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    lang = _detect_language(path)

    # ========================================
    # Step 1: Parse module header
    # ========================================
    header_lines = _extract_header_block(lines)
    if not header_lines:
        raise SpecError(f"{path}: missing module header comment block at top")
    
    module_name = _extract_module_name(header_lines, path)
    responsibility = _extract_responsibility(header_lines)

    # Find and parse Stable API section (required)
    stable_idx = None
    for idx, line in enumerate(header_lines):
        if RE_SECTION_STABLE.match(line):
            stable_idx = idx
            break
    if stable_idx is None:
        raise SpecError(f"{path}: header missing 'Public API (Stable):' section")
    
    stable_sigs = _parse_api_section(header_lines, stable_idx)
    
    # Find and parse Internal API section (optional)
    internal_sigs: List[Signature] = []
    internal_idx = None
    for idx, line in enumerate(header_lines):
        if RE_SECTION_INTERNAL.match(line):
            internal_idx = idx
            break
    if internal_idx is not None:
        internal_sigs = _parse_api_section(header_lines, internal_idx)

    stable_names: Set[str] = {s.name for s in stable_sigs}

    # ========================================
    # Step 2: Parse function documentation for Stable APIs
    # ========================================
    func_docs: Dict[str, FunctionDoc] = {}
    errors: List[str] = []
    expected_sig_by_name: Dict[str, Signature] = {s.name: s for s in stable_sigs}

    # Scan file for all function definitions
    for idx in range(len(lines)):
        fname = _is_function_definition(lines[idx], lang)
        if not fname or fname not in stable_names:
            continue  # Only process Stable APIs
        
        # Find comment block above this function
        sig_line, desc_lines, sig_line_idx = _find_function_comment(lines, idx, fname, lang)
        
        if not sig_line:
            errors.append(f"{path}:{idx+1}: stable API '{fname}' missing signature comment line '# {fname} <args>'")
            continue
        
        if not desc_lines:
            errors.append(f"{path}:{idx+1}: stable API '{fname}' missing description (at least 1 line required)")
            continue
        
        # Validate signature matches header declaration
        ms = RE_FUNC_COMMENT_SIG.match(sig_line)
        doc_args = _split_args(ms.group("args"))
        expected = expected_sig_by_name.get(fname)
        
        if expected and expected.args != doc_args:
            errors.append(
                f"{path}:{idx+1}: stable API '{fname}' doc args {doc_args} do not match header args {expected.args}"
            )
            continue
        
        # Store function documentation
        desc = "  \n".join(desc_lines)  # Markdown line break (2 spaces + newline)
        func_docs[fname] = FunctionDoc(
            signature=Signature(name=fname, args=doc_args),
            description=desc,
            line_no=(sig_line_idx + 1),
        )

    # ========================================
    # Step 3: Verify all declared APIs are implemented with docs
    # ========================================
    implemented_stable: Set[str] = set()
    for idx in range(len(lines)):
        fn = _is_function_definition(lines[idx], lang)
        if fn and fn in stable_names:
            implemented_stable.add(fn)

    for sig in stable_sigs:
        if sig.name not in implemented_stable:
            errors.append(f"{path}: stable API '{sig.name}' declared in header but no function definition found")
        elif sig.name not in func_docs:
            errors.append(f"{path}: stable API '{sig.name}' implemented but doc comment missing/invalid")

    if errors and strict:
        raise SpecError("\n".join(errors))

    return ModuleDoc(
        file_path=path,
        module_name=module_name,
        lang=lang,
        responsibility=responsibility,
        stable_apis=stable_sigs,
        internal_apis=internal_sigs,
        function_docs=func_docs,
    )


# ----------------------------
# API.md generation
# ----------------------------

def render_api_md(modules: List[ModuleDoc], title: str = "Core API") -> str:
    """
    Generate Markdown documentation from parsed modules.
    
    Args:
        modules: List of parsed modules
        title: Document title (e.g., "Core API (Bash)" or "Core API (PowerShell)")
    
    Returns:
        Markdown-formatted string with all Stable APIs documented
    """
    out: List[str] = []
    out.append(f"# {title}\n")
    out.append("This document is generated from source comments.\n")
    out.append("Only **Stable** APIs are listed.\n")

    # Sort modules alphabetically by name, then by language
    modules_sorted = sorted(modules, key=lambda m: (m.module_name.lower(), m.lang))

    for m in modules_sorted:
        # Module header
        out.append(f"\n## {m.module_name}\n")
        if m.responsibility:
            out.append(f"{m.responsibility}\n")

        if not m.stable_apis:
            out.append("_No stable APIs._\n")
            continue

        # API list
        out.append("\n### Stable APIs\n")
        for sig in m.stable_apis:
            fd = m.function_docs.get(sig.name)
            if fd:
                # Function signature (bold)
                out.append(f"- **`{sig.text}`**  \n")
                # Description with proper indentation for multi-line
                desc_with_indent = fd.description.replace("\n", "\n  ")
                out.append(f"  {desc_with_indent}\n\n")
            else:
                # If non-strict mode, doc might be missing
                out.append(f"- `{sig.text}`\n")

    out.append("\n")
    return "".join(out)


# ----------------------------
# CLI
# ----------------------------

def iter_core_lib_files(root: Path) -> Iterable[Path]:
    """Find all core library files (.sh and .ps1) in the repository."""
    candidates = []
    core_lib = root / "core" / "lib"
    if core_lib.exists():
        candidates.extend(core_lib.rglob("*.sh"))
        candidates.extend(core_lib.rglob("*.ps1"))
    return sorted(set(candidates))


def find_repo_root() -> Path:
    """Find repository root by locating .git directory or using script location."""
    # Start from script location
    current = Path(__file__).resolve().parent
    
    # Search upwards for .git directory
    while current != current.parent:
        if (current / ".git").exists():
            return current
        current = current.parent
    
    # Fallback: assume script is in quality/, so repo root is parent
    script_dir = Path(__file__).resolve().parent
    if script_dir.name == "quality":
        return script_dir.parent
    
    # Last resort: current working directory
    return Path.cwd()


def main(argv: Optional[List[str]] = None) -> int:
    p = argparse.ArgumentParser(description="Generate API.md from minimal source comments.")
    p.add_argument("--root", type=str, help="Repository root (default: auto-detect)")
    p.add_argument("--out-bash", type=str, help=f"Output file for Bash APIs (default: {DEFAULT_OUTPUT_DIR}/{DEFAULT_BASH_OUTPUT})")
    p.add_argument("--out-ps", type=str, help=f"Output file for PowerShell APIs (default: {DEFAULT_OUTPUT_DIR}/{DEFAULT_PS_OUTPUT})")
    p.add_argument("--strict", action="store_true", help="Fail on any spec violation (recommended for CI)")
    p.add_argument("--warn", action="store_true", help="Do not fail; print warnings and generate best-effort")
    args = p.parse_args(argv)

    # Determine repository root
    if args.root:
        root = Path(args.root).resolve()
    else:
        root = find_repo_root()
    
    strict = args.strict or not args.warn

    # Determine output paths with defaults in docs/
    out_dir = root / DEFAULT_OUTPUT_DIR
    out_bash = Path(args.out_bash) if args.out_bash else (out_dir / DEFAULT_BASH_OUTPUT)
    out_ps = Path(args.out_ps) if args.out_ps else (out_dir / DEFAULT_PS_OUTPUT)
    
    # Make output paths absolute if they're relative
    if not out_bash.is_absolute():
        out_bash = root / out_bash
    if not out_ps.is_absolute():
        out_ps = root / out_ps

    modules: List[ModuleDoc] = []
    warnings: List[str] = []

    files = list(iter_core_lib_files(root))
    if not files:
        print(f"ERROR: no core/lib/*.sh or *.ps1 found under {root}", file=sys.stderr)
        return 2

    for f in files:
        try:
            modules.append(parse_module(f, strict=strict))
        except SpecError as e:
            if strict:
                print(f"SPEC VIOLATION:\n{e}", file=sys.stderr)
                return 1
            warnings.append(str(e))

    if warnings:
        print("WARNINGS:", file=sys.stderr)
        for w in warnings:
            print(w, file=sys.stderr)

    # Separate modules by language
    bash_modules = [m for m in modules if m.lang == "bash"]
    ps_modules = [m for m in modules if m.lang == "powershell"]

    # Ensure output directory exists
    if bash_modules or ps_modules:
        out_bash.parent.mkdir(parents=True, exist_ok=True)

    # Generate and write Bash API doc
    if bash_modules:
        api_md_bash = render_api_md(bash_modules, title="Core API (Bash)")
        out_bash.write_text(api_md_bash, encoding="utf-8")
        print(f"Wrote: {out_bash}")

    # Generate and write PowerShell API doc
    if ps_modules:
        api_md_ps = render_api_md(ps_modules, title="Core API (PowerShell)")
        out_ps.write_text(api_md_ps, encoding="utf-8")
        print(f"Wrote: {out_ps}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
