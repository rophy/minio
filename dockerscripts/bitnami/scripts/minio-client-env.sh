#!/bin/bash
# Environment configuration for minio-client - compatible with Bitnami chart expectations

. /opt/bitnami/scripts/liblog.sh

export BITNAMI_ROOT_DIR="/opt/bitnami"
export BITNAMI_VOLUME_DIR="/bitnami"
export MODULE="${MODULE:-minio-client}"
export BITNAMI_DEBUG="${BITNAMI_DEBUG:-false}"

# _FILE env var expansion
minio_client_env_vars=(
    MINIO_CLIENT_CONF_DIR
    MINIO_SERVER_HOST
    MINIO_SERVER_PORT_NUMBER
    MINIO_SERVER_SCHEME
    MINIO_SERVER_ROOT_USER
    MINIO_SERVER_ROOT_PASSWORD
)
for env_var in "${minio_client_env_vars[@]}"; do
    file_env_var="${env_var}_FILE"
    if [[ -n "${!file_env_var:-}" ]]; then
        if [[ -r "${!file_env_var:-}" ]]; then
            export "${env_var}=$(< "${!file_env_var}")"
            unset "${file_env_var}"
        else
            warn "Skipping export of '${env_var}'. '${!file_env_var:-}' is not readable."
        fi
    fi
done
unset minio_client_env_vars

# Paths
export MINIO_CLIENT_CONF_DIR="${MINIO_CLIENT_CONF_DIR:-/.mc}"

# MinIO Client configuration
export MINIO_SERVER_HOST="${MINIO_SERVER_HOST:-}"
export MINIO_SERVER_PORT_NUMBER="${MINIO_SERVER_PORT_NUMBER:-9000}"
export MINIO_SERVER_SCHEME="${MINIO_SERVER_SCHEME:-http}"

# MinIO Client security
MINIO_SERVER_ROOT_USER="${MINIO_SERVER_ROOT_USER:-"${MINIO_CLIENT_ACCESS_KEY:-}"}"
MINIO_SERVER_ROOT_USER="${MINIO_SERVER_ROOT_USER:-"${MINIO_SERVER_ACCESS_KEY:-}"}"
export MINIO_SERVER_ROOT_USER="${MINIO_SERVER_ROOT_USER:-}"
MINIO_SERVER_ROOT_PASSWORD="${MINIO_SERVER_ROOT_PASSWORD:-"${MINIO_CLIENT_SECRET_KEY:-}"}"
MINIO_SERVER_ROOT_PASSWORD="${MINIO_SERVER_ROOT_PASSWORD:-"${MINIO_SERVER_SECRET_KEY:-}"}"
export MINIO_SERVER_ROOT_PASSWORD="${MINIO_SERVER_ROOT_PASSWORD:-}"

export MINIO_DAEMON_USER="minio"
export MINIO_DAEMON_GROUP="minio"
