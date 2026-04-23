#!/bin/bash
# Bitnami compatibility shim

. /opt/bitnami/scripts/liblog.sh

BOLD='\033[1m'

print_welcome_page() {
    if [[ -z "${DISABLE_WELCOME_MESSAGE:-}" ]]; then
        if [[ -n "${BITNAMI_APP_NAME:-}" ]]; then
            info ""
            info "${BOLD}Welcome to the ${BITNAMI_APP_NAME} container${RESET}"
            info ""
        fi
    fi
}
