# Bitnami MinIO Compatibility Status Report

Reference: https://hub.docker.com/r/bitnami/minio

## Environment Variables

### Customizable Variables

| Variable | Default | Who Implements | Our Status | Tested |
|----------|---------|---------------|------------|--------|
| `MINIO_ROOT_USER` | `minio` | MinIO native | Supported | Yes (Test 1, 2) |
| `MINIO_ROOT_PASSWORD` | `miniosecret` | MinIO native | Supported | Yes (Test 1, 2) |
| `MINIO_BROWSER` | `off` | MinIO native | Supported | No |
| `MINIO_SERVER_URL` | `$MINIO_SCHEME://localhost:$MINIO_API_PORT_NUMBER` | MinIO native | Supported | No |
| `MINIO_PROMETHEUS_AUTH_TYPE` | N/A | MinIO native | Supported (passthrough) | No |
| `MINIO_HTTP_TRACE` | N/A | MinIO native + validation by scripts | Supported | No |
| `MINIO_API_PORT_NUMBER` | `9000` | Bitnami scripts (`run.sh` `--address` flag) | Supported | Yes (Test 4) |
| `MINIO_CONSOLE_PORT_NUMBER` | `9001` | Bitnami scripts (`run.sh` `--console-address` flag) | Supported | Yes (Test 4) |
| `MINIO_DATA_DIR` | `/bitnami/minio/data` | Bitnami scripts (`run.sh` positional arg) | Supported | No |
| `MINIO_SCHEME` | `http` | Bitnami scripts (URL construction) | Supported | No |
| `MINIO_SKIP_CLIENT` | `no` | Bitnami scripts (`setup.sh` conditional) | Supported | Yes (Test 3) |
| `MINIO_DEFAULT_BUCKETS` | `nil` | Bitnami scripts (`minio_create_default_buckets`) | Supported | Yes (Test 1) |
| `MINIO_DISTRIBUTED_MODE_ENABLED` | `no` | Bitnami scripts (`run.sh` node args) | Supported | No |
| `MINIO_DISTRIBUTED_NODES` | N/A | Bitnami scripts (`run.sh` node args) | Supported | No |
| `MINIO_FORCE_NEW_KEYS` | `no` | Bitnami scripts (`minio_regenerate_keys`) | Supported | No |
| `MINIO_STARTUP_TIMEOUT` | `10` | Bitnami scripts (`wait_for_minio`) | Supported (default: 30) | No |
| `MINIO_APACHE_*` (4 vars) | various | Apache sidecar container | N/A (not applicable) | N/A |
| `OPENSSL_FIPS` | `yes` | BSI image variant only | N/A (not applicable) | N/A |

### Read-Only Variables (set by scripts, not user-configurable)

| Variable | Expected Value | Our Status |
|----------|---------------|------------|
| `MINIO_BASE_DIR` | `/opt/bitnami/minio` | Exported in `minio-env.sh` |
| `MINIO_BIN_DIR` | `${MINIO_BASE_DIR}/bin` | Exported as `/usr/bin` (where minio actually lives) |
| `MINIO_CERTS_DIR` | `/certs` | Exported in `minio-env.sh` |
| `MINIO_LOGS_DIR` | `${MINIO_BASE_DIR}/log` | Exported in `minio-env.sh` |
| `MINIO_TMP_DIR` | `${MINIO_BASE_DIR}/tmp` | Exported in `minio-env.sh` |
| `MINIO_SECRETS_DIR` | `${MINIO_BASE_DIR}/secrets` | Exported in `minio-env.sh` |
| `MINIO_LOG_FILE` | `${MINIO_LOGS_DIR}/minio.log` | Exported in `minio-env.sh` |
| `MINIO_PID_FILE` | `${MINIO_TMP_DIR}/minio.pid` | Exported in `minio-env.sh` |
| `MINIO_DAEMON_USER` | `minio` | Exported in `minio-env.sh` |
| `MINIO_DAEMON_GROUP` | `minio` | Exported in `minio-env.sh` |

### _FILE Env Var Expansion (Docker Secrets)

| Variable | In `_FILE` expansion list | Tested |
|----------|--------------------------|--------|
| `MINIO_ROOT_USER_FILE` | Yes | Yes (Test 2) |
| `MINIO_ROOT_PASSWORD_FILE` | Yes | Yes (Test 2) |
| `MINIO_DATA_DIR_FILE` | Yes | No |
| `MINIO_API_PORT_NUMBER_FILE` | Yes | No |
| `MINIO_BROWSER_FILE` | Yes | No |
| `MINIO_CONSOLE_PORT_NUMBER_FILE` | Yes | No |
| `MINIO_SCHEME_FILE` | Yes | No |
| `MINIO_SKIP_CLIENT_FILE` | Yes | No |
| `MINIO_DISTRIBUTED_MODE_ENABLED_FILE` | Yes | No |
| `MINIO_DEFAULT_BUCKETS_FILE` | Yes | No |
| `MINIO_STARTUP_TIMEOUT_FILE` | Yes | No |
| `MINIO_SERVER_URL_FILE` | Yes | No |
| `MINIO_FORCE_NEW_KEYS_FILE` | Yes | No |

## Filesystem Layout

| Path | Purpose | Our Status |
|------|---------|------------|
| `/opt/bitnami/minio/log/` | Log directory | Created in Dockerfile |
| `/opt/bitnami/minio/tmp/` | PID file, temp files | Created in Dockerfile |
| `/opt/bitnami/minio/secrets/` | Mounted secrets (Helm chart) | Created in Dockerfile |
| `/opt/bitnami/minio/bin/` | Bitnami binary location | **Missing** (minio at `/usr/bin/minio`) |
| `/bitnami/minio/data/` | Default data directory | Created in Dockerfile |
| `/certs/` | TLS certificates | Created in Dockerfile |
| `/.mc/` | mc client config | Created in Dockerfile |
| `/opt/bitnami/minio/log/minio-http.log` | HTTP trace log (symlink to stdout) | Symlinked in Dockerfile |

## Container Behavior

| Feature | Documented Behavior | Our Status | Tested |
|---------|-------------------|------------|--------|
| Non-root execution | UID 1001, user `minio` | Supported | Yes (Test 5) |
| Health endpoint | `/minio/health/live` on API port | Supported | Yes (Test 1) |
| Pass-through commands | `docker run IMAGE minio --version` | Supported | Yes (Test 1) |
| Bundled `mc` client | Pre-installed for admin tasks | Supported | Yes (Test 1) |
| Bundled `curl` | Available in container | Supported | Yes (Test 1) |
| Bundled `jq` | Available in container | Supported | Yes (Test 1) |
| Bundled `bash` | Available in container | Supported | Yes (Test 1) |
| `pgrep` / `procps` | Used by `is_minio_running` | Supported | Yes (Test 1) |
| Data persistence | Volume at `/bitnami/minio/data` | Supported | No (not tested across restarts) |
| TLS/HTTPS | Certs at `/certs`, `MINIO_SCHEME=https` | Supported (code path exists) | No |
| Distributed mode | Multi-node with ellipsis syntax | Supported (code path exists) | No |
| Bucket policies | `:download` and `:public` suffixes | Supported | Yes (Test 1) |
| Password min length | 8 characters enforced | **Missing** (no validation in scripts) |
| `BITNAMI_DEBUG` | Verbose logging | Supported | No |
| Log symlink to stdout | `/opt/bitnami/minio/log/minio-http.log -> /dev/stdout` | Supported | No |

## Gaps

| Item | Severity | Notes |
|------|----------|-------|
| Password minimum length not validated | Medium | MinIO itself enforces this at startup and exits with an error, so behavior is the same (startup fails) but the error message differs |
| `MINIO_STARTUP_TIMEOUT` default is 30 vs bitnami's 10 | Low | Intentional for reliability; compatible (user can override) |

## Test Coverage Summary

| Test | What it covers |
|------|---------------|
| Test 1: Basic startup | Health, `MINIO_DEFAULT_BUCKETS` (creation + policies), object I/O, pass-through commands, bundled tools |
| Test 2: _FILE env vars | `MINIO_ROOT_USER_FILE`, `MINIO_ROOT_PASSWORD_FILE`, credential rejection |
| Test 3: Skip client | `MINIO_SKIP_CLIENT=yes` |
| Test 4: Custom ports | `MINIO_API_PORT_NUMBER`, `MINIO_CONSOLE_PORT_NUMBER` |
| Test 5: Non-root | UID 1001 verification |

### Not tested

- `MINIO_DATA_DIR` (custom path)
- `MINIO_SCHEME=https` (needs TLS certs)
- `MINIO_BROWSER=on` (console enabled)
- `MINIO_FORCE_NEW_KEYS=yes` (key regeneration across restarts)
- `MINIO_DISTRIBUTED_MODE_ENABLED=yes` (needs multi-node)
- `MINIO_SERVER_URL` (custom external URL)
- `MINIO_STARTUP_TIMEOUT` (custom timeout)
- `MINIO_HTTP_TRACE` (trace logging)
- `MINIO_PROMETHEUS_AUTH_TYPE` (metrics auth)
- `BITNAMI_DEBUG=true` (verbose logging)
- Data persistence across container restarts
- TLS certificate mounting and HTTPS operation
