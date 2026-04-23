#!/bin/bash
set -uo pipefail

BITNAMI_IMAGE="${BITNAMI_IMAGE:-bitnamilegacy/minio:latest}"
OUR_IMAGE="${OUR_IMAGE:-ghcr.io/rophy/minio:bitnami-test}"
BITNAMI_PORT=9100
OUR_PORT=9200
PASS=0
FAIL=0
SKIP=0

cleanup() {
    docker rm -f minio-test-bitnami minio-test-ours minio-test-file 2>/dev/null || true
    rm -rf /tmp/minio-test-secrets 2>/dev/null || true
}

log_pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
log_fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
log_skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }

wait_healthy() {
    local port=$1 name=$2
    for i in $(seq 1 30); do
        if curl -sf http://localhost:${port}/minio/health/live >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done
    echo "  FAIL: ${name} did not become healthy within 30s"
    docker logs "minio-test-${name}" 2>&1 | tail -20
    return 1
}

wait_ready() {
    local container=$1
    for i in $(seq 1 15); do
        if docker exec "$container" mc --config-dir /tmp/.mc-ready alias set local http://localhost:9000 minioadmin minioadmin123 >/dev/null 2>&1 && \
           docker exec "$container" mc --config-dir /tmp/.mc-ready ls local/ 2>/dev/null | grep -q .; then
            return 0
        fi
        sleep 1
    done
    return 1
}

run_mc() {
    local container=$1; shift
    docker exec "$container" mc --config-dir /tmp/.mc-test "$@" 2>&1
}

setup_mc() {
    local container=$1 port=$2
    run_mc "$container" alias set local http://localhost:${port} minioadmin minioadmin123 >/dev/null 2>&1
}

# ============================================================
echo "=== Test 1: Basic startup with default buckets ==="
# ============================================================
cleanup

docker run -d --name minio-test-bitnami \
    -e MINIO_ROOT_USER=minioadmin \
    -e MINIO_ROOT_PASSWORD=minioadmin123 \
    -e MINIO_DEFAULT_BUCKETS="bucket-a,bucket-b:download,bucket-c:public" \
    -p ${BITNAMI_PORT}:9000 \
    "$BITNAMI_IMAGE" >/dev/null 2>&1

docker run -d --name minio-test-ours \
    -e MINIO_ROOT_USER=minioadmin \
    -e MINIO_ROOT_PASSWORD=minioadmin123 \
    -e MINIO_DEFAULT_BUCKETS="bucket-a,bucket-b:download,bucket-c:public" \
    -p ${OUR_PORT}:9000 \
    "$OUR_IMAGE" >/dev/null 2>&1

wait_healthy $BITNAMI_PORT bitnami || exit 1
wait_healthy $OUR_PORT ours || exit 1

# Wait for bucket metadata to be fully loaded (health endpoint responds before this)
wait_ready minio-test-bitnami
wait_ready minio-test-ours

# Health check
if curl -sf http://localhost:${BITNAMI_PORT}/minio/health/live >/dev/null; then
    log_pass "bitnami health endpoint"
else
    log_fail "bitnami health endpoint"
fi

if curl -sf http://localhost:${OUR_PORT}/minio/health/live >/dev/null; then
    log_pass "ours health endpoint"
else
    log_fail "ours health endpoint"
fi

# Bucket creation
setup_mc minio-test-bitnami 9000
setup_mc minio-test-ours 9000

bitnami_buckets=$(run_mc minio-test-bitnami ls local/ | awk '{print $NF}' | sort | tr '\n' ' ')
our_buckets=$(run_mc minio-test-ours ls local/ | awk '{print $NF}' | sort | tr '\n' ' ')

if [[ "$bitnami_buckets" == "$our_buckets" ]]; then
    log_pass "bucket creation matches: ${our_buckets}"
else
    log_fail "bucket mismatch: bitnami='${bitnami_buckets}' ours='${our_buckets}'"
fi

# Bucket policies
for bucket in bucket-b bucket-c; do
    bitnami_policy=$(run_mc minio-test-bitnami anonymous get-json local/${bucket}/ 2>/dev/null | jq -r '.Statement[0].Effect // empty' 2>/dev/null || echo "none")
    our_policy=$(run_mc minio-test-ours anonymous get-json local/${bucket}/ 2>/dev/null | jq -r '.Statement[0].Effect // empty' 2>/dev/null || echo "none")
    if [[ "$bitnami_policy" == "$our_policy" ]]; then
        log_pass "${bucket} policy matches: ${our_policy}"
    else
        log_fail "${bucket} policy mismatch: bitnami='${bitnami_policy}' ours='${our_policy}'"
    fi
done

# Object upload/download (reuse same config dir as setup_mc)
docker exec minio-test-bitnami sh -c 'echo hello-bitnami > /tmp/testobj.txt && mc --config-dir /tmp/.mc-test cp /tmp/testobj.txt local/bucket-a/test.txt' >/dev/null 2>&1 || true
docker exec minio-test-ours sh -c 'echo hello-ours > /tmp/testobj.txt && mc --config-dir /tmp/.mc-test cp /tmp/testobj.txt local/bucket-a/test.txt' >/dev/null 2>&1 || true

bitnami_obj=$(run_mc minio-test-bitnami cat local/bucket-a/test.txt 2>/dev/null || true)
our_obj=$(run_mc minio-test-ours cat local/bucket-a/test.txt 2>/dev/null || true)

if [[ "$bitnami_obj" == *"hello-bitnami"* ]]; then
    log_pass "bitnami object read/write"
else
    log_fail "bitnami object read/write: got '${bitnami_obj}'"
fi

if [[ "$our_obj" == *"hello-ours"* ]]; then
    log_pass "ours object read/write"
else
    log_fail "ours object read/write: got '${our_obj}'"
fi

# Entrypoint: pass-through command
bitnami_ver=$(docker run --rm "$BITNAMI_IMAGE" minio --version 2>&1 | grep "minio version" | awk '{print $3}')
our_ver=$(docker run --rm "$OUR_IMAGE" minio --version 2>&1 | grep "minio version" | awk '{print $3}')

if [[ -n "$bitnami_ver" ]]; then
    log_pass "bitnami pass-through command works: ${bitnami_ver}"
else
    log_fail "bitnami pass-through command"
fi

if [[ -n "$our_ver" ]]; then
    log_pass "ours pass-through command works: ${our_ver}"
else
    log_fail "ours pass-through command"
fi

# Bundled tools
for tool in mc curl jq bash; do
    if docker exec minio-test-ours sh -c "command -v $tool" >/dev/null 2>&1; then
        log_pass "ours has $tool"
    else
        log_fail "ours missing $tool"
    fi
done

if docker exec minio-test-ours pgrep -f "minio server" >/dev/null 2>&1; then
    log_pass "ours has pgrep (procps)"
else
    log_fail "ours missing pgrep"
fi

cleanup

# ============================================================
echo ""
echo "=== Test 2: _FILE env var support ==="
# ============================================================
mkdir -p /tmp/minio-test-secrets
echo -n "fileuser" > /tmp/minio-test-secrets/user
echo -n "filepassword123" > /tmp/minio-test-secrets/pass

docker run -d --name minio-test-file \
    -v /tmp/minio-test-secrets:/secrets:ro \
    -e MINIO_ROOT_USER_FILE=/secrets/user \
    -e MINIO_ROOT_PASSWORD_FILE=/secrets/pass \
    -p ${OUR_PORT}:9000 \
    "$OUR_IMAGE" >/dev/null 2>&1

wait_healthy $OUR_PORT file || exit 1

# Verify file-based credentials work
if docker exec minio-test-file mc --config-dir /tmp/.mc-test alias set local http://localhost:9000 fileuser filepassword123 >/dev/null 2>&1; then
    if docker exec minio-test-file mc --config-dir /tmp/.mc-test admin info local >/dev/null 2>&1; then
        log_pass "_FILE credentials accepted"
    else
        log_fail "_FILE credentials: mc admin info failed"
    fi
else
    log_fail "_FILE credentials: mc alias set failed"
fi

# Verify wrong credentials are rejected
if docker exec minio-test-file mc --config-dir /tmp/.mc-test2 alias set local http://localhost:9000 wronguser wrongpass >/dev/null 2>&1 && \
   docker exec minio-test-file mc --config-dir /tmp/.mc-test2 admin info local >/dev/null 2>&1; then
    log_fail "_FILE credentials: wrong creds should be rejected"
else
    log_pass "_FILE credentials: wrong creds rejected"
fi

cleanup

# ============================================================
echo ""
echo "=== Test 3: Skip client mode ==="
# ============================================================
docker run -d --name minio-test-ours \
    -e MINIO_ROOT_USER=minioadmin \
    -e MINIO_ROOT_PASSWORD=minioadmin123 \
    -e MINIO_SKIP_CLIENT=yes \
    -p ${OUR_PORT}:9000 \
    "$OUR_IMAGE" >/dev/null 2>&1

wait_healthy $OUR_PORT ours || exit 1

# Should start without running mc setup
if curl -sf http://localhost:${OUR_PORT}/minio/health/live >/dev/null; then
    log_pass "MINIO_SKIP_CLIENT=yes starts successfully"
else
    log_fail "MINIO_SKIP_CLIENT=yes failed to start"
fi

cleanup

# ============================================================
echo ""
echo "=== Test 4: Custom ports ==="
# ============================================================
docker run -d --name minio-test-ours \
    -e MINIO_ROOT_USER=minioadmin \
    -e MINIO_ROOT_PASSWORD=minioadmin123 \
    -e MINIO_API_PORT_NUMBER=9010 \
    -e MINIO_CONSOLE_PORT_NUMBER=9011 \
    -e MINIO_SKIP_CLIENT=yes \
    -p 9010:9010 \
    "$OUR_IMAGE" >/dev/null 2>&1

sleep 10

if curl -sf http://localhost:9010/minio/health/live >/dev/null; then
    log_pass "custom API port (9010)"
else
    log_fail "custom API port (9010)"
fi

cleanup

# ============================================================
echo ""
echo "=== Test 5: Non-root user ==="
# ============================================================
docker run -d --name minio-test-ours \
    -e MINIO_ROOT_USER=minioadmin \
    -e MINIO_ROOT_PASSWORD=minioadmin123 \
    -e MINIO_SKIP_CLIENT=yes \
    -p ${OUR_PORT}:9000 \
    "$OUR_IMAGE" >/dev/null 2>&1

wait_healthy $OUR_PORT ours || exit 1

uid=$(docker exec minio-test-ours id -u)
if [[ "$uid" == "1001" ]]; then
    log_pass "runs as non-root user (uid=1001)"
else
    log_fail "unexpected uid: ${uid}"
fi

cleanup

# ============================================================
echo ""
echo "========================================="
echo "Results: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
echo "========================================="
[[ $FAIL -eq 0 ]]
