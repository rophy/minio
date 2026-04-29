#!/bin/bash

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
