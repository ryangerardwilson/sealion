#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
tmp_dir="$(mktemp -d)"
port=""

cleanup() {
  if [ -n "$port" ] && [ -d "$tmp_dir/demo" ]; then
    (
      cd "$tmp_dir/demo"
      SEALION_HTTP_PORT="$port" docker compose down -v --remove-orphans >/dev/null 2>&1 || true
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

export SEALION_HOME="$repo_root"
cd "$tmp_dir"
"$repo_root/bin/sealion" new demo >/dev/null

cd "$tmp_dir/demo"
docker compose config > "$tmp_dir/compose.config"
grep -q "develop:" "$tmp_dir/compose.config"
grep -q "watch:" "$tmp_dir/compose.config"
grep -q "action: rebuild" "$tmp_dir/compose.config"
grep -q "/frontend/src" "$tmp_dir/compose.config"
grep -q "/frontend/package.json" "$tmp_dir/compose.config"
grep -q "/src" "$tmp_dir/compose.config"
grep -q "/model" "$tmp_dir/compose.config"
grep -q "/controller" "$tmp_dir/compose.config"
grep -q "/Dockerfile" "$tmp_dir/compose.config"
SEALION_HTTP_PORT="$port" docker compose up -d --build

for _ in $(seq 1 60); do
  if curl -fsS "http://localhost:$port/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

curl -fsS "http://localhost:$port/health" >/dev/null
curl -fsS "http://localhost:$port/" > "$tmp_dir/home.html"
grep -q '<div id="root"></div>' "$tmp_dir/home.html"
grep -q "/src/main.jsx" "$tmp_dir/home.html"
curl -fsS "http://localhost:$port/api/me" > "$tmp_dir/me-anon.json"
grep -q '"authenticated":false' "$tmp_dir/me-anon.json"
docker compose logs backend > "$tmp_dir/backend.log"
grep -q "API listening inside backend container on :8080" "$tmp_dir/backend.log"
grep -q "frontend proxies API calls from http://localhost:$port/api" "$tmp_dir/backend.log"
docker compose logs frontend > "$tmp_dir/frontend.log"
grep -q "Local:" "$tmp_dir/frontend.log"
if ! docker compose run --rm --no-deps frontend npm run build > "$tmp_dir/frontend-build.log" 2>&1; then
  cat "$tmp_dir/frontend-build.log" >&2
  exit 1
fi

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
  -D "$tmp_dir/login.headers" \
  -o "$tmp_dir/login.json" \
  -c "$tmp_dir/cookies" \
  -d "email=admin%40sealion.local&password=password" \
  "http://localhost:$port/api/login"
wait "$idle_pid" || true

grep -q "200 OK" "$tmp_dir/login.headers"
grep -qi "content-type: application/json" "$tmp_dir/login.headers"
grep -qi "cache-control: no-store" "$tmp_dir/login.headers"
grep -qi "set-cookie: sealion_session=" "$tmp_dir/login.headers"
grep -q "sealion_session" "$tmp_dir/cookies"
grep -q '"ok":true' "$tmp_dir/login.json"
grep -q 'admin@sealion.local' "$tmp_dir/login.json"

session_token="$(awk '$6 == "sealion_session" {print $7}' "$tmp_dir/cookies" | tail -n 1)"
long_cookie="$(
  python3 - <<'PY'
print("x" * 5000)
PY
)"
curl \
  -fsS \
  -H "Cookie: unrelated=${long_cookie}; sealion_session=${session_token}" \
  "http://localhost:$port/api/dashboard" > "$tmp_dir/dashboard-long-cookie.json"
grep -q '"ok":true' "$tmp_dir/dashboard-long-cookie.json"
grep -q 'admin@sealion.local' "$tmp_dir/dashboard-long-cookie.json"

curl -fsS -b "$tmp_dir/cookies" "http://localhost:$port/api/me" > "$tmp_dir/me-auth.json"
grep -q '"authenticated":true' "$tmp_dir/me-auth.json"
grep -q 'admin@sealion.local' "$tmp_dir/me-auth.json"

curl -fsS -b "$tmp_dir/cookies" "http://localhost:$port/dashboard" > "$tmp_dir/dashboard-shell.html"
grep -q '<div id="root"></div>' "$tmp_dir/dashboard-shell.html"

curl -fsS -b "$tmp_dir/cookies" -X POST "http://localhost:$port/api/logout" > "$tmp_dir/logout.json"
grep -q '"ok":true' "$tmp_dir/logout.json"
curl -fsS "http://localhost:$port/api/me" > "$tmp_dir/me-after-logout.json"
grep -q '"authenticated":false' "$tmp_dir/me-after-logout.json"

printf 'starter docker flow ok\n'
