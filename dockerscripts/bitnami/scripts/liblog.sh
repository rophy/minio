#!/bin/bash
# Logging functions compatible with Bitnami chart expectations

RESET='\033[0m'
RED='\033[38;5;1m'
GREEN='\033[38;5;2m'
YELLOW='\033[38;5;3m'
MAGENTA='\033[38;5;5m'
CYAN='\033[38;5;6m'

stderr_print() {
    local bool="${BITNAMI_QUIET:-false}"
    shopt -s nocasematch
    if ! [[ "$bool" = 1 || "$bool" =~ ^(yes|true)$ ]]; then
        printf "%b\\n" "${*}" >&2
    fi
}

log() {
    stderr_print "${CYAN}${MODULE:-} ${MAGENTA}$(date "+%T.%2N ")${RESET}${*}"
}

info() {
    log "${GREEN}INFO ${RESET} ==> ${*}"
}

warn() {
    log "${YELLOW}WARN ${RESET} ==> ${*}"
}

error() {
    log "${RED}ERROR${RESET} ==> ${*}"
}

debug() {
    local debug_bool="${BITNAMI_DEBUG:-false}"
    shopt -s nocasematch
    if [[ "$debug_bool" = 1 || "$debug_bool" =~ ^(yes|true)$ ]]; then
        log "${MAGENTA}DEBUG${RESET} ==> ${*}"
    fi
}

indent() {
    local string="${1:-}"
    local num="${2:?missing num}"
    local char="${3:-" "}"
    local indent_unit=""
    for ((i = 0; i < num; i++)); do
        indent_unit="${indent_unit}${char}"
    done
    echo "$string" | sed "s/^/${indent_unit}/"
}
