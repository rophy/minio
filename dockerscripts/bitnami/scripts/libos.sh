#!/bin/bash
# OS functions compatible with Bitnami chart expectations

. /opt/bitnami/scripts/liblog.sh
. /opt/bitnami/scripts/libfs.sh
. /opt/bitnami/scripts/libvalidations.sh

user_exists() {
    local user="${1:?user is missing}"
    id "$user" >/dev/null 2>&1
}

group_exists() {
    local group="${1:?group is missing}"
    getent group "$group" >/dev/null 2>&1
}

ensure_group_exists() {
    local group="${1:?group is missing}"
    local is_system_user=false
    local gid=""
    shift 1
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -i|--gid) shift; gid="${1:?missing gid}" ;;
            -s|--system) is_system_user=true ;;
            *) echo "Invalid command line flag $1" >&2; return 1 ;;
        esac
        shift
    done
    if ! group_exists "$group"; then
        local -a args=("$group")
        [[ -n "$gid" ]] && args+=("--gid" "$gid")
        $is_system_user && args+=("--system")
        addgroup "${args[@]}" >/dev/null 2>&1 || groupadd "${args[@]}" >/dev/null 2>&1 || true
    fi
}

ensure_user_exists() {
    local user="${1:?user is missing}"
    local group="" home=""
    shift 1
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -g|--group) shift; group="${1:?missing group}" ;;
            -h|--home) shift; home="${1:?missing home directory}" ;;
            *) shift ;;
        esac
        shift 2>/dev/null || true
    done
    if ! user_exists "$user"; then
        adduser -D -H "$user" >/dev/null 2>&1 || useradd -r "$user" >/dev/null 2>&1 || true
    fi
    if [[ -n "$group" ]]; then
        ensure_group_exists "$group"
    fi
}

am_i_root() {
    [[ "$(id -u)" = "0" ]]
}

debug_execute() {
    if is_boolean_yes "${BITNAMI_DEBUG:-false}"; then
        "$@"
    else
        "$@" >/dev/null 2>&1
    fi
}

retry_while() {
    local cmd="${1:?cmd is missing}"
    local retries="${2:-12}"
    local sleep_time="${3:-5}"
    local return_value=1
    read -r -a command <<<"$cmd"
    for ((i = 1; i <= retries; i += 1)); do
        "${command[@]}" && return_value=0 && break
        sleep "$sleep_time"
    done
    return $return_value
}

run_as_user() {
    run_chroot "$@"
}

exec_as_user() {
    run_chroot --replace-process "$@"
}

run_chroot() {
    local replace=false
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -r|--replace-process) replace=true ;;
            --) shift; break ;;
            -*) stderr_print "unrecognized flag $1"; return 1 ;;
            *) break ;;
        esac
        shift
    done
    if [[ "$#" -lt 2 ]]; then
        echo "expected at least 2 arguments"; return 1
    fi
    local userspec=$1; shift
    local user; user=$(echo "$userspec" | cut -d':' -f1)
    if ! am_i_root; then
        error "Could not switch to '${userspec}': Operation not permitted"
        return 1
    fi
    local homedir; homedir=$(eval echo "~${user}")
    [[ ! -d $homedir ]] && homedir="${HOME:-/}"
    local -r cwd="$(pwd)"
    if [[ "$replace" = true ]]; then
        exec chroot --userspec="$userspec" / bash -c "cd ${cwd}; export HOME=${homedir}; exec \"\$@\"" -- "$@"
    else
        chroot --userspec="$userspec" / bash -c "cd ${cwd}; export HOME=${homedir}; exec \"\$@\"" -- "$@"
    fi
}

get_machine_ip() {
    local hostname; hostname="$(hostname)"
    local -a ip_addresses
    read -r -a ip_addresses <<< "$(getent ahosts "$hostname" | awk '/STREAM/ {print $1}' | head -n 1)"
    echo "${ip_addresses[0]}"
}
