#!/bin/bash
# Bitnami Helm chart compatibility entrypoint.
# Wraps MinIO startup with Bitnami env var handling (_FILE expansion,
# MINIO_DEFAULT_BUCKETS, MINIO_DISTRIBUTED_MODE_ENABLED, etc.).

set -o errexit
set -o nounset
set -o pipefail

. /opt/bitnami/scripts/libbitnami.sh
. /opt/bitnami/scripts/liblog.sh

export BITNAMI_APP_NAME="minio"
print_welcome_page

if [[ $* == *"/opt/bitnami/scripts/minio/run.sh"* ]]; then
	info "** Starting MinIO setup **"
	/opt/bitnami/scripts/minio/setup.sh
	info "** MinIO setup finished! **"
fi

echo ""

if [[ $1 == "server" ]]; then
	exec minio "$@"
else
	exec "$@"
fi
