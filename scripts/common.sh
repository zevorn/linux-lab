#!/bin/bash
# Common functions for linux-lab scripts
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[ OK ]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERR ]${NC} $*" >&2; }
log_fatal() { log_error "$@"; exit 1; }

# Check if a command exists
check_cmd() {
    command -v "$1" >/dev/null 2>&1 || log_fatal "Required command not found: $1"
}

# Check if a file exists, with helpful error
check_file() {
    local file="$1"
    local hint="${2:-}"
    if [ ! -f "$file" ]; then
        log_error "File not found: $file"
        [ -n "$hint" ] && log_info "Hint: $hint"
        return 1
    fi
}

# Check available disk space (in MB)
check_disk_space() {
    local required_mb="${1:-5120}"
    local dir="${2:-.}"
    # Use parent dir if target doesn't exist yet
    local check_dir="$dir"
    while [ ! -d "$check_dir" ] && [ "$check_dir" != "/" ]; do
        check_dir=$(dirname "$check_dir")
    done
    local available_mb
    available_mb=$(df -m "$check_dir" | awk 'NR==2 {print $4}')
    if [ "$available_mb" -lt "$required_mb" ]; then
        log_warn "Low disk space: ${available_mb}MB available, ${required_mb}MB recommended"
        log_warn "Run 'make disk-usage' to see breakdown, 'make clean' to free space"
    fi
}

# Ensure directory exists
ensure_dir() {
    mkdir -p "$1"
}

# Download with resume and fallback
download_file() {
    local url="$1"
    local url_alt="${2:-}"
    local dest="$3"
    local sha256="${4:-}"

    ensure_dir "$(dirname "$dest")"

    log_info "Downloading $(basename "$dest")..."
    local tmp_dir
    tmp_dir="$(dirname "$dest")"
    if ! wget -q --show-progress -P "$tmp_dir" "$url" 2>/dev/null; then
        if [ -n "$url_alt" ]; then
            log_warn "Primary mirror failed, trying fallback..."
            wget -q --show-progress -P "$tmp_dir" "$url_alt" || \
                log_fatal "Download failed from both mirrors"
            url="$url_alt"
        else
            log_fatal "Download failed: $url"
        fi
    fi
    # Rename downloaded file to expected destination
    local downloaded
    downloaded="$tmp_dir/$(basename "$url")"
    if [ "$downloaded" != "$dest" ] && [ -f "$downloaded" ]; then
        mv "$downloaded" "$dest"
    fi

    if [ -n "$sha256" ]; then
        log_info "Verifying checksum..."
        echo "$sha256  $dest" | sha256sum -c --quiet || \
            log_fatal "Checksum verification failed for $dest"
        log_ok "Checksum verified"
    fi
}

# Logging to file
LOG_DIR=""
setup_logging() {
    local board="$1"
    local target="$2"
    LOG_DIR="${OUTPUT_DIR:-output}/${board}/logs"
    ensure_dir "$LOG_DIR"
    LOG_FILE="${LOG_DIR}/${target}-$(date +%Y%m%d-%H%M%S).log"
    log_info "Logging to $LOG_FILE"
}

# Run command with logging
run_logged() {
    if [ -n "${LOG_FILE:-}" ]; then
        "$@" 2>&1 | tee -a "$LOG_FILE"
        return "${PIPESTATUS[0]}"
    else
        "$@"
    fi
}

# Show last N lines of log on failure
show_log_tail() {
    local n="${1:-20}"
    if [ -n "${LOG_FILE:-}" ] && [ -f "$LOG_FILE" ]; then
        log_error "Last $n lines of log:"
        tail -n "$n" "$LOG_FILE" >&2
        log_error "Full log: $LOG_FILE"
    fi
}
