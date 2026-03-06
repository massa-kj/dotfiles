#!/usr/bin/env bash
# Run Docker-based integration tests

set -euo pipefail

# Detect dotfiles root (this script is at tests/environment/linux/docker/test.sh)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

cd "$DOTFILES_ROOT"

IMAGE_NAME="dotfiles-test"
DOCKERFILE="tests/environment/linux/docker/Dockerfile"

# Color output
readonly COLOR_RESET='\033[0m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_YELLOW='\033[0;33m'

log_step() {
    echo -e "${COLOR_GREEN}==>${COLOR_RESET} $*"
}

log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"
}

# Usage
usage() {
    local exit_code="${1:-0}"
    cat <<EOF
Usage: $(basename "$0") <command>

Run Docker-based integration tests for dotfiles.

Commands:
  build              Build test image
  minimal            Run minimal scenario
  idempotent         Run idempotent scenario
  uninstall          Run uninstall scenario
  version-install    Run version install scenario
  version-upgrade    Run version upgrade scenario
  version-mixed      Run version mixed scenario
  all                Run all scenarios (default)
  shell              Open interactive shell in container
  clean              Remove test image

Examples:
  $(basename "$0") minimal           # Run minimal test only
  $(basename "$0") uninstall         # Run uninstall test only
  $(basename "$0") version-upgrade   # Run version upgrade test
  $(basename "$0") build             # Build image only
  $(basename "$0") shell             # Open shell for manual testing

EOF
    exit "$exit_code"
}

# Build test image
build_image() {
    log_step "Building test image..."
    log_info "Dockerfile: $DOCKERFILE"
    log_info "Context: $DOTFILES_ROOT"
    
    docker build -f "$DOCKERFILE" -t "$IMAGE_NAME" .
    
    log_step "Build complete"
}

# Run scenario
run_scenario() {
    local scenario="$1"
    local script="./tests/environment/linux/docker/scenarios/${scenario}.sh"
    
    log_step "Running ${scenario} scenario..."
    
    if ! docker run --rm "$IMAGE_NAME" "$script"; then
        echo ""
        log_info "Test failed: $scenario"
        return 1
    fi
    
    echo ""
    return 0
}

# Clean test image
clean_image() {
    log_step "Removing test image..."
    docker rmi "$IMAGE_NAME" 2>/dev/null || true
    log_step "Clean complete"
}

# Open interactive shell
open_shell() {
    log_step "Opening interactive shell in container..."
    log_info "You can manually run bootstrap and tests:"
    log_info "  ./platforms/linux/bootstrap.sh"
    log_info "  ./dotfiles apply profiles/linux.yaml"
    log_info "  ./tests/environment/linux/docker/scenarios/minimal.sh"
    echo ""
    
    docker run --rm -it "$IMAGE_NAME" /bin/bash
}

# Main
COMMAND="${1:-}"

case "$COMMAND" in
    build)
        build_image
        ;;
    minimal)
        build_image
        run_scenario "minimal"
        ;;
    idempotent)
        build_image
        run_scenario "idempotent"
        ;;
    uninstall)
        build_image
        run_scenario "uninstall"
        ;;
    version-install)
        build_image
        run_scenario "version_install"
        ;;
    version-upgrade)
        build_image
        run_scenario "version_upgrade"
        ;;
    version-mixed)
        build_image
        run_scenario "version_mixed"
        ;;
    all)
        build_image
        # run_scenario "minimal"
        run_scenario "idempotent"
        run_scenario "uninstall"
        run_scenario "version_install"
        run_scenario "version_upgrade"
        run_scenario "version_mixed"
        log_step "All tests passed!"
        ;;
    shell)
        build_image
        open_shell
        ;;
    clean)
        clean_image
        ;;
    help|--help|-h)
        usage 0
        ;;
    *)
        echo "Unknown command: $COMMAND"
        echo ""
        usage 1
        ;;
esac
