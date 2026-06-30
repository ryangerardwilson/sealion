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
grep -q "/src" "$tmp_dir/compose.config"
grep -q "/model" "$tmp_dir/compose.config"
grep -q "/controller" "$tmp_dir/compose.config"
grep -q "/view" "$tmp_dir/compose.config"
grep -q "/ui_components" "$tmp_dir/compose.config"
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
grep -q "<h1>demo</h1>" "$tmp_dir/home.html"
! grep -q "{{" "$tmp_dir/home.html"
! grep -q "{!!" "$tmp_dir/home.html"
docker compose logs app > "$tmp_dir/app.log"
grep -q "listening inside container on :8080" "$tmp_dir/app.log"
grep -q "open http://localhost:$port" "$tmp_dir/app.log"

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
  -o "$tmp_dir/login.body" \
  -c "$tmp_dir/cookies" \
  -d "email=admin%40sealion.local&password=password" \
  "http://localhost:$port/login"
wait "$idle_pid" || true

grep -q "302 Found" "$tmp_dir/login.headers"
grep -q "Location: /dashboard" "$tmp_dir/login.headers"
grep -q "Cache-Control: no-store" "$tmp_dir/login.headers"
grep -q "Set-Cookie: sealion_session=" "$tmp_dir/login.headers"
grep -q "sealion_session" "$tmp_dir/cookies"
grep -q "window.location.replace('/dashboard')" "$tmp_dir/login.body"
grep -q 'href="/dashboard"' "$tmp_dir/login.body"

session_token="$(awk '$6 == "sealion_session" {print $7}' "$tmp_dir/cookies" | tail -n 1)"
long_cookie="$(
  python3 - <<'PY'
print("x" * 5000)
PY
)"
curl \
  -fsS \
  -H "Cookie: unrelated=${long_cookie}; sealion_session=${session_token}" \
  "http://localhost:$port/dashboard" > "$tmp_dir/dashboard-long-cookie.html"
grep -q "<h1>Dashboard</h1>" "$tmp_dir/dashboard-long-cookie.html"

curl -fsS -b "$tmp_dir/cookies" "http://localhost:$port/dashboard" > "$tmp_dir/dashboard.html"
grep -q "<h1>Dashboard</h1>" "$tmp_dir/dashboard.html"
grep -q "You are logged in as" "$tmp_dir/dashboard.html"
! grep -q "{{" "$tmp_dir/dashboard.html"
! grep -q "{!!" "$tmp_dir/dashboard.html"

printf '<s-l1.heading text="Bad skin use" />\n' > view/home.skin
printf '<s-l2.page-header title="Bad l2 use" />\n' > ui_components/l2/auth_form.scale
SEALION_HTTP_PORT="$port" docker compose up -d --build app

for _ in $(seq 1 60); do
  if curl -fsS "http://localhost:$port/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

curl -sS -D "$tmp_dir/invalid-home.headers" -o "$tmp_dir/invalid-home.body" "http://localhost:$port/"
grep -q "500 Internal Server Error" "$tmp_dir/invalid-home.headers"
grep -q "Could not render the requested view" "$tmp_dir/invalid-home.body"

curl -sS -D "$tmp_dir/invalid-login.headers" -o "$tmp_dir/invalid-login.body" "http://localhost:$port/login"
grep -q "500 Internal Server Error" "$tmp_dir/invalid-login.headers"
grep -q "Could not render the requested view" "$tmp_dir/invalid-login.body"

docker compose logs app > "$tmp_dir/invalid-app.log"
grep -q "skin templates cannot use s-l1/heading components" "$tmp_dir/invalid-app.log"
grep -q "l2 templates cannot use s-l2/page_header components" "$tmp_dir/invalid-app.log"

printf 'starter docker flow ok\n'
