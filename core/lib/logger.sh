#!/usr/bin/env bash
# Log output functions

# Color definitions
readonly LOG_COLOR_RESET='\033[0m'
readonly LOG_COLOR_RED='\033[0;31m'
readonly LOG_COLOR_GREEN='\033[0;32m'
readonly LOG_COLOR_YELLOW='\033[0;33m'
readonly LOG_COLOR_BLUE='\033[0;34m'
readonly LOG_COLOR_GRAY='\033[0;90m'

# Log levels
log_debug() {
    echo -e "${LOG_COLOR_GRAY}[DEBUG] $*${LOG_COLOR_RESET}" >&2
}

log_info() {
    echo -e "${LOG_COLOR_BLUE}[INFO] $*${LOG_COLOR_RESET}" >&2
}

log_success() {
    echo -e "${LOG_COLOR_GREEN}[SUCCESS] $*${LOG_COLOR_RESET}" >&2
}

log_warn() {
    echo -e "${LOG_COLOR_YELLOW}[WARN] $*${LOG_COLOR_RESET}" >&2
}

log_error() {
    echo -e "${LOG_COLOR_RED}[ERROR] $*${LOG_COLOR_RESET}" >&2
}

# Task execution log (start/end of processing)
log_task() {
    echo -e "${LOG_COLOR_GREEN}==>${LOG_COLOR_RESET} $*" >&2
}
