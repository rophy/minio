#!/bin/bash
# MinIO Client functions compatible with Bitnami chart expectations

. /opt/bitnami/scripts/libos.sh

minio_client_bucket_exists() {
	local -r bucket_name="${1:?bucket required}"
	minio_client_execute stat "${bucket_name}" >/dev/null 2>&1
}

minio_client_execute() {
	local -r args=("--config-dir" "${MINIO_CLIENT_CONF_DIR}" "--quiet" "$@")
	local exec
	exec=$(command -v mc)
	if am_i_root; then
		run_as_user "$MINIO_DAEMON_USER" "${exec}" "${args[@]}"
	else
		"${exec}" "${args[@]}"
	fi
}

minio_client_execute_timeout() {
	local -r args=("--config-dir" "${MINIO_CLIENT_CONF_DIR}" "--quiet" "$@")
	local exec
	exec=$(command -v mc)
	timeout 5s "${exec}" "${args[@]}"
}

minio_client_configure_local() {
	local scheme
	scheme="$(echo "$MINIO_SERVER_SCHEME" | tr '[:upper:]' '[:lower:]')"
	info "Adding local Minio host to 'mc' configuration..."
	minio_client_execute alias set local "${scheme}://localhost:${MINIO_SERVER_PORT_NUMBER}" "$MINIO_SERVER_ROOT_USER" "$MINIO_SERVER_ROOT_PASSWORD" >/dev/null 2>&1
}
