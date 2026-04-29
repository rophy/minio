#!/bin/bash
# MinIO library functions compatible with Bitnami chart expectations

. /opt/bitnami/scripts/libservice.sh
. /opt/bitnami/scripts/libnet.sh
. /opt/bitnami/scripts/libos.sh
. /opt/bitnami/scripts/libvalidations.sh
. /opt/bitnami/scripts/libminioclient.sh

is_distributed_ellipses_syntax() {
	! is_empty_value "$MINIO_DISTRIBUTED_NODES" && [[ $MINIO_DISTRIBUTED_NODES == *"..."* ]]
}

minio_distributed_drives() {
	local -a drives=()
	local -a nodes
	if ! is_empty_value "$MINIO_DISTRIBUTED_NODES"; then
		read -r -a nodes <<<"$(tr ',;' ' ' <<<"${MINIO_DISTRIBUTED_NODES}")"
		for node in "${nodes[@]}"; do
			drive="$(parse_uri "${MINIO_SCHEME}://${node}" "path")"
			drives+=("$drive")
		done
	fi
	echo "${drives[@]}"
}

is_minio_running() {
	local pid
	pid="$(pgrep -f "$(command -v minio) server" 2>/dev/null | head -1)"
	if [[ -z $pid ]]; then
		return 1
	fi
	echo "$pid" >"$MINIO_PID_FILE"
	if ! is_service_running "$pid"; then
		return 1
	fi
	local status
	status="$(minio_client_execute_timeout admin info local --json 2>/dev/null | jq -r .info.mode 2>/dev/null)"
	[[ $status == "online" ]]
}

is_minio_live() {
	local pid
	pid="$(pgrep -f "$(command -v minio) server" 2>/dev/null | head -1)"
	if [[ -z $pid ]]; then
		return 1
	fi
	echo "$pid" >"$MINIO_PID_FILE"
	if ! is_service_running "$pid"; then
		return 1
	fi
	local status_code
	status_code=$(curl --write-out '%{http_code}' --silent --output /dev/null "${MINIO_SCHEME}://127.0.0.1:${MINIO_API_PORT_NUMBER}/minio/health/live")
	[[ $status_code == "200" ]]
}

wait_for_minio() {
	local waited_time=0
	while ! is_minio_live && [[ $waited_time -lt $MINIO_STARTUP_TIMEOUT ]]; do
		sleep 5
		waited_time=$((waited_time + 5))
	done
}

minio_start_bg() {
	local -r exec=$(command -v minio)
	local -a args=("server" "--certs-dir" "${MINIO_CERTS_DIR}" "--address" ":${MINIO_API_PORT_NUMBER}")
	local -a nodes
	local browser
	browser="$(echo "$MINIO_BROWSER" | tr '[:upper:]' '[:lower:]')"
	[[ $browser == "on" ]] && args+=("--console-address" ":${MINIO_CONSOLE_PORT_NUMBER}")
	if is_boolean_yes "$MINIO_DISTRIBUTED_MODE_ENABLED"; then
		read -r -a nodes <<<"$(tr ',;' ' ' <<<"${MINIO_DISTRIBUTED_NODES}")"
		for node in "${nodes[@]}"; do
			if is_distributed_ellipses_syntax; then
				args+=("${MINIO_SCHEME}://${node}")
			else
				args+=("${MINIO_SCHEME}://${node}:${MINIO_API_PORT_NUMBER}/${MINIO_DATA_DIR}")
			fi
		done
	else
		args+=("${MINIO_DATA_DIR}")
	fi
	is_minio_running && return
	info "Starting MinIO in background..."
	if am_i_root; then
		debug_execute run_as_user "$MINIO_DAEMON_USER" "${exec}" "${args[@]}" &
	else
		debug_execute "${exec}" "${args[@]}" &
	fi
	wait_for_minio
}

minio_stop() {
	if is_minio_running; then
		info "Stopping MinIO..."
		minio_client_execute_timeout admin service stop local >/dev/null 2>&1 || true
		local counter=5
		while is_minio_running; do
			[[ $counter -le 0 ]] && break
			sleep 1
			counter=$((counter - 1))
		done
	else
		info "MinIO is already stopped..."
	fi
}

minio_validate() {
	debug "Validating settings in MINIO_* env vars.."
	local error_code=0
	print_validation_error() {
		error "$1"
		error_code=1
	}
	check_yes_no_value() {
		if ! is_yes_no_value "${!1}"; then
			print_validation_error "The allowed values for $1 are [yes, no]"
		fi
	}
	check_allowed_port() {
		local validate_port_args=()
		! am_i_root && validate_port_args+=("-unprivileged")
		local err
		if ! err=$(validate_port "${validate_port_args[@]}" "${!1}"); then
			print_validation_error "An invalid port was specified in the environment variable $1: $err"
		fi
	}
	if is_boolean_yes "$MINIO_DISTRIBUTED_MODE_ENABLED"; then
		if [[ -z ${MINIO_ROOT_USER:-} ]] || [[ -z ${MINIO_ROOT_PASSWORD:-} ]]; then
			print_validation_error "Distributed mode is enabled. Both MINIO_ROOT_USER and MINIO_ROOT_PASSWORD environment must be set"
		fi
		if [[ -z ${MINIO_DISTRIBUTED_NODES:-} ]]; then
			print_validation_error "Distributed mode is enabled. Nodes must be indicated setting the environment variable MINIO_DISTRIBUTED_NODES"
		else
			read -r -a nodes <<<"$(tr ',;' ' ' <<<"${MINIO_DISTRIBUTED_NODES}")"
			if ! is_distributed_ellipses_syntax && ([[ ${#nodes[@]} -lt 4 ]] || (("${#nodes[@]}" % 2))); then
				print_validation_error "Number of nodes must even and greater than 4."
			fi
		fi
	else
		if [[ -n ${MINIO_DISTRIBUTED_NODES:-} ]]; then
			warn "Distributed mode is not enabled. The nodes set at the environment variable MINIO_DISTRIBUTED_NODES will be ignored."
		fi
	fi
	if [[ -n ${MINIO_HTTP_TRACE:-} ]]; then
		if [[ -w $MINIO_HTTP_TRACE ]]; then
			info "HTTP log trace enabled. Find the HTTP logs at: $MINIO_HTTP_TRACE"
		else
			print_validation_error "The HTTP log file specified at the environment variable MINIO_HTTP_TRACE is not writable by current user \"$(id -u)\""
		fi
	fi
	shopt -s nocasematch
	if ! is_dir_empty "${MINIO_CERTS_DIR}" && [[ ${MINIO_SCHEME} == "http" ]] && [[ ${MINIO_SERVER_URL} == "http://"* ]]; then
		warn "Certificates provided but 'http' scheme in use. Please set MINIO_SCHEME and/or MINIO_SERVER_URL variables"
	fi
	if [[ ${MINIO_SCHEME} != "http" ]] && [[ ${MINIO_SCHEME} != "https" ]]; then
		print_validation_error "The values allowed for MINIO_SCHEME are only [http, https]"
	fi
	shopt -u nocasematch
	check_yes_no_value MINIO_SKIP_CLIENT
	check_yes_no_value MINIO_DISTRIBUTED_MODE_ENABLED
	check_yes_no_value MINIO_FORCE_NEW_KEYS
	check_allowed_port MINIO_CONSOLE_PORT_NUMBER
	check_allowed_port MINIO_API_PORT_NUMBER
	return "$error_code"
}

minio_create_default_buckets() {
	if [[ -n $MINIO_DEFAULT_BUCKETS ]]; then
		read -r -a buckets <<<"$(tr ',;' ' ' <<<"${MINIO_DEFAULT_BUCKETS}")"
		info "Creating default buckets..."
		for b in "${buckets[@]}"; do
			read -r -a bucket_info <<<"$(tr ':' ' ' <<<"${b}")"
			if ! minio_client_bucket_exists "local/${bucket_info[0]}"; then
				if [[ -n ${MINIO_REGION_NAME:-} ]]; then
					minio_client_execute mb "--region" "${MINIO_REGION_NAME}" "local/${bucket_info[0]}"
				else
					minio_client_execute mb "local/${bucket_info[0]}"
				fi
				if [ ${#bucket_info[@]} -eq 2 ]; then
					info "Setting policy ${bucket_info[1]} for local bucket ${bucket_info[0]}"
					minio_client_execute anonymous set "${bucket_info[1]}" local/"${bucket_info[0]}"/
				fi
			else
				info "Bucket local/${bucket_info[0]} already exists, skipping creation."
			fi
		done
	fi
}

minio_regenerate_keys() {
	local error_code=0
	if is_boolean_yes "$MINIO_FORCE_NEW_KEYS" && [[ -f "${MINIO_DATA_DIR}/.root_user" ]] && [[ -f "${MINIO_DATA_DIR}/.root_password" ]]; then
		MINIO_ROOT_USER_OLD="$(cat "${MINIO_DATA_DIR}/.root_user")"
		MINIO_ROOT_PASSWORD_OLD="$(cat "${MINIO_DATA_DIR}/.root_password")"
		if [[ $MINIO_ROOT_USER_OLD != "$MINIO_ROOT_USER" ]] || [[ $MINIO_ROOT_PASSWORD_OLD != "$MINIO_ROOT_PASSWORD" ]]; then
			info "Reconfiguring MinIO credentials..."
			export MINIO_ROOT_USER_OLD MINIO_ROOT_PASSWORD_OLD
			minio_start_bg
			info "Forcing container restart after key regeneration"
			error_code=1
		fi
	fi
	echo "$MINIO_ROOT_USER" >"${MINIO_DATA_DIR}/.root_user"
	echo "$MINIO_ROOT_PASSWORD" >"${MINIO_DATA_DIR}/.root_password"
	chmod 600 "${MINIO_DATA_DIR}/.root_user" "${MINIO_DATA_DIR}/.root_password" 2>/dev/null ||
		warn "Unable to set secure permissions on key files ${MINIO_DATA_DIR}/.root_*"
	[[ $error_code -eq 0 ]] || exit "$error_code"
}

minio_node_hostname() {
	if is_boolean_yes "$MINIO_DISTRIBUTED_MODE_ENABLED"; then
		read -r -a nodes <<<"$(tr ',;' ' ' <<<"${MINIO_DISTRIBUTED_NODES}")"
		for node in "${nodes[@]}"; do
			[[ $(get_machine_ip) == $(dns_lookup "$node") ]] && echo "$node" && return
		done
		error "Could not find own node in MINIO_DISTRIBUTE_NODES: ${MINIO_DISTRIBUTED_NODES}"
		exit 1
	else
		echo "localhost"
	fi
}

is_minio_not_running() {
	! is_minio_running
}

minio_initialize() {
	if am_i_root; then
		debug "Ensuring MinIO daemon user/group exists"
		ensure_user_exists "$MINIO_DAEMON_USER" --group "$MINIO_DAEMON_GROUP"
		debug "Ensuring MinIO config folder '$MINIO_CLIENT_CONF_DIR' exists"
		ensure_dir_exists "$MINIO_CLIENT_CONF_DIR"
		if [[ -n ${MINIO_DAEMON_USER:-} ]]; then
			chown -R "${MINIO_DAEMON_USER:-}" "$MINIO_BASE_DIR" "$MINIO_DATA_DIR" "$MINIO_CLIENT_CONF_DIR"
		fi
	fi
}
