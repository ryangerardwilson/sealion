#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
tmp_dir="$(mktemp -d)"
port=""

cleanup() {
  if [ -n "$port" ] && [ -d "$tmp_dir/demo" ]; then
    (
      cd "$tmp_dir/demo"
      CARBIDE_HTTP_PORT="$port" docker compose down -v --remove-orphans >/dev/null 2>&1 || true
    )
  fi
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

command -v docker >/dev/null 2>&1 || {
  printf 'docker is required for starter docker flow tests\n' >&2
  exit 1
}
docker compose version >/dev/null
command -v curl >/dev/null 2>&1 || {
  printf 'curl is required for starter docker flow tests\n' >&2
  exit 1
}
command -v python3 >/dev/null 2>&1 || {
  printf 'python3 is required for starter docker flow tests\n' >&2
  exit 1
}

port="$(
  python3 - <<'PY'
import socket
import sys

for port in range(19080, 19140):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        sock.bind(("127.0.0.1", port))
    except OSError:
        sock.close()
        continue
    sock.close()
    print(port)
    sys.exit(0)

sys.exit(1)
PY
)"

export CARBIDE_HOME="$repo_root"
cd "$tmp_dir"
"$repo_root/bin/carbide" new demo >/dev/null

cd "$tmp_dir/demo"
docker compose config > "$tmp_dir/compose.config"
grep -q "develop:" "$tmp_dir/compose.config"
grep -q "watch:" "$tmp_dir/compose.config"
grep -q "action: rebuild" "$tmp_dir/compose.config"
grep -q "/view/web/src" "$tmp_dir/compose.config"
grep -q "/view/web/package.json" "$tmp_dir/compose.config"
grep -q "/view/web/bun.lock" "$tmp_dir/compose.config"
grep -q "/go.mod" "$tmp_dir/compose.config"
grep -q "/go.sum" "$tmp_dir/compose.config"
grep -q "/src" "$tmp_dir/compose.config"
grep -q "/model" "$tmp_dir/compose.config"
grep -q "/controller" "$tmp_dir/compose.config"
grep -q "/Dockerfile" "$tmp_dir/compose.config"
CARBIDE_HTTP_PORT="$port" docker compose up -d --build

for _ in $(seq 1 60); do
  if curl -fsS "http://localhost:$port/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

curl -fsS "http://localhost:$port/health" >/dev/null
curl -fsS "http://localhost:$port/" > "$tmp_dir/home.html"
grep -q '<div id="root"></div>' "$tmp_dir/home.html"
grep -q "/_bun/client/" "$tmp_dir/home.html"
curl -fsS "http://localhost:$port/api/me" > "$tmp_dir/me-anon.json"
grep -q '"authenticated":false' "$tmp_dir/me-anon.json"
docker compose logs backend > "$tmp_dir/backend.log"
grep -q "backend listening on container port 8080" "$tmp_dir/backend.log"
grep -q "public API URL is http://localhost:$port/api" "$tmp_dir/backend.log"
docker compose logs frontend > "$tmp_dir/frontend.log"
grep -q "Carbide Bun frontend listening inside container on :8080" "$tmp_dir/frontend.log"
grep -q "browser entrypoint http://localhost:$port" "$tmp_dir/frontend.log"
grep -q "proxying /api and /health to backend service http://backend:8080" "$tmp_dir/frontend.log"
! grep -q "Bun frontend listening on http://localhost:8080" "$tmp_dir/frontend.log"
CARBIDE_HOME="$repo_root" "$repo_root/bin/carbide" status > "$tmp_dir/status.out"
grep -q "Carbide status" "$tmp_dir/status.out"
grep -Eq "^service[[:space:]]+container[[:space:]]+ports[[:space:]]+internal[[:space:]]+status" "$tmp_dir/status.out"
grep -Eq "^frontend[[:space:]]+demo-frontend-1[[:space:]]+localhost:$port[[:space:]]+8080/tcp[[:space:]]+running" "$tmp_dir/status.out"
grep -Eq "^backend[[:space:]]+demo-backend-1[[:space:]]+-[[:space:]]+8080/tcp[[:space:]]+running \\(healthy\\)" "$tmp_dir/status.out"
grep -Eq "^db[[:space:]]+demo-db-1[[:space:]]+-[[:space:]]+5432/tcp[[:space:]]+running \\(healthy\\)" "$tmp_dir/status.out"
if ! docker compose run --rm --no-deps frontend bun run build > "$tmp_dir/frontend-build.log" 2>&1; then
  cat "$tmp_dir/frontend-build.log" >&2
  exit 1
fi
grep -q "tailwind:build" "$tmp_dir/frontend-build.log"

python3 - "$port" <<'PY' &
import socket
import sys
import time

sock = socket.create_connection(("127.0.0.1", int(sys.argv[1])))
time.sleep(3)
sock.close()
PY
idle_pid="$!"
sleep 0.1

curl \
  -sS \
  --max-time 5 \
  -D "$tmp_dir/login-before-register.headers" \
  -o "$tmp_dir/login-before-register.json" \
  -d "email=first%40carbide.local&password=password" \
  "http://localhost:$port/api/login"
grep -q "422 Unprocessable Entity" "$tmp_dir/login-before-register.headers"
grep -q '"ok":false' "$tmp_dir/login-before-register.json"

curl \
  -sS \
  --max-time 5 \
  -D "$tmp_dir/register.headers" \
  -o "$tmp_dir/register.json" \
  -c "$tmp_dir/cookies" \
  -d "email=first%40carbide.local&password=password" \
  "http://localhost:$port/api/register"
wait "$idle_pid" || true

grep -q "200 OK" "$tmp_dir/register.headers"
grep -qi "content-type: application/json" "$tmp_dir/register.headers"
grep -qi "cache-control: no-store" "$tmp_dir/register.headers"
grep -qi "set-cookie: carbide_session=" "$tmp_dir/register.headers"
grep -q "carbide_session" "$tmp_dir/cookies"
grep -q '"ok":true' "$tmp_dir/register.json"
grep -q 'first@carbide.local' "$tmp_dir/register.json"

session_token="$(awk '$6 == "carbide_session" {print $7}' "$tmp_dir/cookies" | tail -n 1)"
long_cookie="$(
  python3 - <<'PY'
print("x" * 5000)
PY
)"
curl \
  -fsS \
  -H "Cookie: unrelated=${long_cookie}; carbide_session=${session_token}" \
  "http://localhost:$port/api/dashboard" > "$tmp_dir/dashboard-long-cookie.json"
grep -q '"ok":true' "$tmp_dir/dashboard-long-cookie.json"
grep -q 'first@carbide.local' "$tmp_dir/dashboard-long-cookie.json"

curl -fsS -b "$tmp_dir/cookies" "http://localhost:$port/api/me" > "$tmp_dir/me-auth.json"
grep -q '"authenticated":true' "$tmp_dir/me-auth.json"
grep -q 'first@carbide.local' "$tmp_dir/me-auth.json"

curl -fsS -b "$tmp_dir/cookies" "http://localhost:$port/dashboard" > "$tmp_dir/dashboard-shell.html"
grep -q '<div id="root"></div>' "$tmp_dir/dashboard-shell.html"
grep -q "/_bun/client/" "$tmp_dir/dashboard-shell.html"

curl -fsS -b "$tmp_dir/cookies" -X POST "http://localhost:$port/api/logout" > "$tmp_dir/logout.json"
grep -q '"ok":true' "$tmp_dir/logout.json"
curl -fsS "http://localhost:$port/api/me" > "$tmp_dir/me-after-logout.json"
grep -q '"authenticated":false' "$tmp_dir/me-after-logout.json"

curl \
  -sS \
  --max-time 5 \
  -D "$tmp_dir/login.headers" \
  -o "$tmp_dir/login.json" \
  -c "$tmp_dir/cookies-after-login" \
  -d "email=first%40carbide.local&password=password" \
  "http://localhost:$port/api/login"
grep -q "200 OK" "$tmp_dir/login.headers"
grep -qi "set-cookie: carbide_session=" "$tmp_dir/login.headers"
grep -q '"ok":true' "$tmp_dir/login.json"
grep -q 'first@carbide.local' "$tmp_dir/login.json"

printf 'starter docker flow ok\n'
