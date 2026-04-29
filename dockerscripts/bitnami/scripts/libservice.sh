#!/bin/bash
# Service functions compatible with Bitnami chart expectations

. /opt/bitnami/scripts/libvalidations.sh
. /opt/bitnami/scripts/liblog.sh

get_pid_from_file() {
	local pid_file="${1:?pid file is missing}"
	if [[ -f $pid_file ]]; then
		if [[ -n "$(<"$pid_file")" ]] && [[ "$(<"$pid_file")" -gt 0 ]]; then
			echo "$(<"$pid_file")"
		fi
	fi
}

is_service_running() {
	local pid="${1:?pid is missing}"
	kill -0 "$pid" 2>/dev/null
}
