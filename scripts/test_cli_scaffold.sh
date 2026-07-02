#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

export CARBIDE_HOME="$repo_root"

"$repo_root/bin/carbide" > "$tmp_dir/no-args.out"
grep -q "________________________oo_______oo_______oo_________" "$tmp_dir/no-args.out"
grep -q "Carbide 0.1.0-dev" "$tmp_dir/no-args.out"
grep -q "Usage:" "$tmp_dir/no-args.out"
grep -q "Commands:" "$tmp_dir/no-args.out"
grep -q "carbide <command> \\[arguments\\]" "$tmp_dir/no-args.out"
grep -q "new <project-name>" "$tmp_dir/no-args.out"
grep -q "init" "$tmp_dir/no-args.out"
grep -q "help" "$tmp_dir/no-args.out"
! grep -q "Options:" "$tmp_dir/no-args.out"
! grep -q "Available commands:" "$tmp_dir/no-args.out"
! grep -q "run dev" "$tmp_dir/no-args.out"
! grep -q "status" "$tmp_dir/no-args.out"
! grep -q "stop dev" "$tmp_dir/no-args.out"
! grep -q "follow logs" "$tmp_dir/no-args.out"
! grep -q "upgrade" "$tmp_dir/no-args.out"
! grep -q "version" "$tmp_dir/no-args.out"
! grep -q "features:" "$tmp_dir/no-args.out"
! grep -q "raw.githubusercontent.com/ryangerardwilson/carbide" "$tmp_dir/no-args.out"

"$repo_root/bin/carbide" help > "$tmp_dir/help.out"
awk 'length($0) > 79 { print "help line exceeds 79 chars: " $0; exit 1 }' "$tmp_dir/help.out"
grep -q "^Usage:$" "$tmp_dir/help.out"
grep -q "^  carbide <command> \\[arguments\\]$" "$tmp_dir/help.out"
grep -q "^Available commands:$" "$tmp_dir/help.out"
grep -q "^  help " "$tmp_dir/help.out"
grep -q "^  init " "$tmp_dir/help.out"
grep -q "^  logs " "$tmp_dir/help.out"
grep -q "^  new <project-name> " "$tmp_dir/help.out"
grep -q "^  status " "$tmp_dir/help.out"
grep -q "^  upgrade " "$tmp_dir/help.out"
grep -q "^  version " "$tmp_dir/help.out"
grep -q "^follow$" "$tmp_dir/help.out"
grep -q "^  follow logs " "$tmp_dir/help.out"
grep -q "^  follow logs service backend " "$tmp_dir/help.out"
grep -q "^logs$" "$tmp_dir/help.out"
grep -q "^  logs containing \"/api/login\" json " "$tmp_dir/help.out"
grep -q "^run$" "$tmp_dir/help.out"
grep -q "^  run dev " "$tmp_dir/help.out"
grep -q "^stop$" "$tmp_dir/help.out"
grep -q "^  stop dev " "$tmp_dir/help.out"
! grep -q "^area" "$tmp_dir/help.out"
! grep -q "^command  .*purpose" "$tmp_dir/help.out"
! grep -q "carbide help" "$tmp_dir/help.out"
! grep -q "carbide run dev" "$tmp_dir/help.out"
! grep -q "^Carbide$" "$tmp_dir/help.out"
! grep -q "Containerized full-stack apps with React, Go, and Postgres." "$tmp_dir/help.out"
! grep -q "_____________________________________________________" "$tmp_dir/help.out"
! grep -q "________________________oo_______oo_______oo_________" "$tmp_dir/help.out"
! grep -q "install the CLI" "$tmp_dir/help.out"
! grep -q "<github-install-url>" "$tmp_dir/help.out"
! grep -q "curl -fsSL" "$tmp_dir/help.out"
! grep -q "raw.githubusercontent.com/ryangerardwilson/carbide" "$tmp_dir/help.out"
! grep -q "features:" "$tmp_dir/help.out"
! grep -q "global actions:" "$tmp_dir/help.out"
! grep -q "carbide logs follow" "$tmp_dir/help.out"
! grep -q "carbide format" "$tmp_dir/help.out"

if "$repo_root/bin/carbide" format >/tmp/carbide-format.out 2>/tmp/carbide-format.err; then
  printf 'carbide format should not exist\n' >&2
  exit 1
fi
grep -q "unknown command: format" /tmp/carbide-format.err

cd "$tmp_dir"
"$repo_root/bin/carbide" new demo

test -f "$tmp_dir/demo/carbide.toml"
test -f "$tmp_dir/demo/.gitignore"
test -f "$tmp_dir/demo/docker-compose.yml"
test -f "$tmp_dir/demo/Dockerfile"
test -f "$tmp_dir/demo/view/web/Dockerfile"
test -f "$tmp_dir/demo/view/web/index.html"
test -f "$tmp_dir/demo/view/web/package.json"
test -f "$tmp_dir/demo/view/web/bun.lock"
test -f "$tmp_dir/demo/view/web/src/main.jsx"
test -f "$tmp_dir/demo/view/web/src/server.jsx"
test -f "$tmp_dir/demo/view/web/src/styles.css"
! test -d "$tmp_dir/demo/frontend"
! test -f "$tmp_dir/demo/view/web/package-lock.json"
! test -f "$tmp_dir/demo/view/web/vite.config.js"
test -f "$tmp_dir/demo/go.mod"
test -f "$tmp_dir/demo/go.sum"
test -f "$tmp_dir/demo/src/main.go"
test -f "$tmp_dir/demo/model/user.go"
test -f "$tmp_dir/demo/model/session.go"
test -f "$tmp_dir/demo/controller/auth_controller.go"
test -f "$tmp_dir/demo/controller/page_controller.go"
! test -f "$tmp_dir/demo/src/app.h"
! test -f "$tmp_dir/demo/src/main.c"
! test -f "$tmp_dir/demo/model/user.c"
! test -f "$tmp_dir/demo/model/session.c"
! test -f "$tmp_dir/demo/controller/auth_controller.c"
! test -f "$tmp_dir/demo/controller/page_controller.c"
test -f "$tmp_dir/demo/migrations/001_auth.sql"

grep -q 'name = "demo"' "$tmp_dir/demo/carbide.toml"
grep -q "default_port = 8080" "$tmp_dir/demo/carbide.toml"
! grep -q 'url = "http://localhost:8080"' "$tmp_dir/demo/carbide.toml"
grep -q 'name: demo' "$tmp_dir/demo/docker-compose.yml"
grep -q ".carbide/" "$tmp_dir/demo/.gitignore"
grep -q "frontend:" "$tmp_dir/demo/docker-compose.yml"
grep -q "backend:" "$tmp_dir/demo/docker-compose.yml"
grep -q "db:" "$tmp_dir/demo/docker-compose.yml"
grep -q 'PUBLIC_URL: "http://localhost:${CARBIDE_HTTP_PORT:-8080}"' "$tmp_dir/demo/docker-compose.yml"
test "$(grep -c 'PUBLIC_URL: "http://localhost:${CARBIDE_HTTP_PORT:-8080}"' "$tmp_dir/demo/docker-compose.yml")" -eq 2
grep -q "develop:" "$tmp_dir/demo/docker-compose.yml"
grep -q "watch:" "$tmp_dir/demo/docker-compose.yml"
grep -q "action: rebuild" "$tmp_dir/demo/docker-compose.yml"
grep -q "context: ./view/web" "$tmp_dir/demo/docker-compose.yml"
grep -q "path: ./view/web/src" "$tmp_dir/demo/docker-compose.yml"
grep -q "path: ./view/web/package.json" "$tmp_dir/demo/docker-compose.yml"
grep -q "path: ./view/web/bun.lock" "$tmp_dir/demo/docker-compose.yml"
grep -q "path: ./go.mod" "$tmp_dir/demo/docker-compose.yml"
grep -q "path: ./go.sum" "$tmp_dir/demo/docker-compose.yml"
grep -q "path: ./src" "$tmp_dir/demo/docker-compose.yml"
grep -q "path: ./model" "$tmp_dir/demo/docker-compose.yml"
grep -q "path: ./controller" "$tmp_dir/demo/docker-compose.yml"
grep -q "path: ./Dockerfile" "$tmp_dir/demo/docker-compose.yml"
! grep -R 'admin@carbide.local' "$tmp_dir/demo" >/dev/null
! grep -R 'Demo login' "$tmp_dir/demo" >/dev/null
grep -q "github.com/jackc/pgx/v5" "$tmp_dir/demo/go.mod"
grep -q "package main" "$tmp_dir/demo/src/main.go"
grep -q "/api/login" "$tmp_dir/demo/controller/page_controller.go"
grep -q "/api/me" "$tmp_dir/demo/controller/page_controller.go"
grep -q "handleDashboard" "$tmp_dir/demo/controller/page_controller.go"
grep -q "backend listening on container port" "$tmp_dir/demo/src/main.go"
grep -q "public API URL is" "$tmp_dir/demo/src/main.go"
! grep -q "API listening inside backend container" "$tmp_dir/demo/src/main.go"
! find "$tmp_dir/demo" -name '*.c' -o -name '*.h' | grep -q .
! grep -R "render_template_text" "$tmp_dir/demo" >/dev/null
! grep -R "respond_view" "$tmp_dir/demo" >/dev/null
grep -q "oven/bun:1.3.14-debian" "$tmp_dir/demo/view/web/Dockerfile"
grep -q "bun install --frozen-lockfile" "$tmp_dir/demo/view/web/Dockerfile"
grep -q '"@tailwindcss/cli": "4.3.2"' "$tmp_dir/demo/view/web/package.json"
grep -q '"tailwindcss": "4.3.2"' "$tmp_dir/demo/view/web/package.json"
grep -q '"react": "19.2.7"' "$tmp_dir/demo/view/web/package.json"
grep -q "Bun.serve" "$tmp_dir/demo/view/web/src/server.jsx"
grep -q "browser entrypoint" "$tmp_dir/demo/view/web/src/server.jsx"
grep -q "listening inside container" "$tmp_dir/demo/view/web/src/server.jsx"
grep -q "proxying /api and /health to backend service" "$tmp_dir/demo/view/web/src/server.jsx"
! grep -q "Bun frontend listening on http://localhost" "$tmp_dir/demo/view/web/src/server.jsx"
grep -q '@import "tailwindcss";' "$tmp_dir/demo/view/web/src/styles.css"
grep -q '/api/${mode}' "$tmp_dir/demo/view/web/src/main.jsx"
grep -q "Bun frontend + Go API + Postgres" "$tmp_dir/demo/view/web/src/main.jsx"
grep -q "React + Bun container" "$tmp_dir/demo/view/web/src/main.jsx"
grep -q "Containerized full stack development" "$tmp_dir/demo/view/web/src/main.jsx"
! find "$tmp_dir/demo" -path '*/ui_components/*' -print -quit | grep -q .
! grep -R "views/" "$tmp_dir/demo" >/dev/null
! grep -R "__PROJECT_" "$tmp_dir/demo" >/dev/null

mkdir "$tmp_dir/init-app"
cd "$tmp_dir/init-app"
"$repo_root/bin/carbide" init
test -f "$tmp_dir/init-app/carbide.toml"
grep -q 'name = "init-app"' "$tmp_dir/init-app/carbide.toml"

mkdir "$tmp_dir/not-empty"
touch "$tmp_dir/not-empty/file"
cd "$tmp_dir/not-empty"
if "$repo_root/bin/carbide" init >/tmp/carbide-init.out 2>/tmp/carbide-init.err; then
  printf 'carbide init should fail in a non-empty directory\n' >&2
  exit 1
fi
grep -q "requires an empty directory" /tmp/carbide-init.err

if command -v python3 >/dev/null 2>&1; then
  fake_bin="$tmp_dir/fake-bin"
  port_file="$tmp_dir/selected-port"
  args_file="$tmp_dir/docker-args"
  mkdir "$fake_bin"
  cat > "$fake_bin/docker" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "compose" ] && [ "${2:-}" = "version" ]; then
  printf 'Docker Compose fake\n'
  exit 0
fi

if [ "${1:-}" = "compose" ] && [ "${2:-}" = "up" ] && [ "${3:-}" = "--help" ]; then
  printf 'Usage: docker compose up [OPTIONS]\n'
  printf '      --quiet-build    Suppress the build output\n'
  printf '      --quiet-pull     Pull without printing progress information\n'
  printf '      --wait           Wait for services to be running|healthy\n'
  printf '      --wait-timeout int\n'
  printf '      --watch    Watch source code and rebuild/refresh containers when files are updated.\n'
  exit 0
fi

if [ "${1:-}" = "compose" ] && [ "${2:-}" = "logs" ] && [ "${3:-}" = "--help" ]; then
  printf 'Usage: docker compose logs [OPTIONS]\n'
  printf '      --no-color    Produce monochrome output\n'
  printf '      --tail string Number of lines to show from the end of the logs\n'
  exit 0
fi

if [ "${1:-}" = "compose" ] && [ "${2:-}" = "config" ] && [ "${3:-}" = "--services" ]; then
  printf 'frontend\nbackend\ndb\n'
  exit 0
fi

if [ "${1:-}" = "compose" ] && [ "${2:-}" = "ps" ] && [ "${3:-}" = "--format" ] && [ "${4:-}" = "json" ]; then
  status_port="8082"
  if [ -n "${FAKE_DOCKER_PORT_FILE:-}" ] && [ -s "$FAKE_DOCKER_PORT_FILE" ]; then
    status_port="$(cat "$FAKE_DOCKER_PORT_FILE")"
  fi
  printf '{"Service":"frontend","Name":"demo-frontend-1","State":"running","Health":"healthy","Publishers":[{"URL":"0.0.0.0","TargetPort":8080,"PublishedPort":%s,"Protocol":"tcp"},{"URL":"::","TargetPort":8080,"PublishedPort":%s,"Protocol":"tcp"}]}\n' "$status_port" "$status_port"
  printf '{"Service":"backend","Name":"demo-backend-1","State":"running","Health":"healthy","Publishers":[{"URL":"","TargetPort":8080,"PublishedPort":0,"Protocol":"tcp"}]}\n'
  printf '{"Service":"db","Name":"demo-db-1","State":"running","Health":"healthy","Publishers":[{"URL":"","TargetPort":5432,"PublishedPort":0,"Protocol":"tcp"}]}\n'
  exit 0
fi

if [ "${1:-}" = "compose" ] && [ "${2:-}" = "up" ]; then
  printf '%s\n' "${CARBIDE_HTTP_PORT:-}" > "$FAKE_DOCKER_PORT_FILE"
  printf '%s\n' "$*" > "$FAKE_DOCKER_ARGS_FILE"
  exit 0
fi

if [ "${1:-}" = "compose" ] && [ "${2:-}" = "logs" ]; then
  printf '%s\n' "$*" >> "$FAKE_DOCKER_ARGS_FILE"
  printf 'backend-1  | GET /health\n'
  printf 'frontend-1 | listening on :8080\n'
  if [ "${FAKE_DOCKER_STREAM_LONG:-}" = "1" ]; then
    trap 'exit 0' INT TERM
    while true; do sleep 1; done
  fi
  sleep 0.2
  exit 0
fi

if [ "${1:-}" = "compose" ] && [ "${2:-}" = "watch" ]; then
  printf '%s\n' "$*" >> "$FAKE_DOCKER_ARGS_FILE"
  printf 'Watch enabled\n'
  printf 'rebuilding backend\n'
  if [ "${FAKE_DOCKER_STREAM_LONG:-}" = "1" ]; then
    trap 'exit 0' INT TERM
    while true; do sleep 1; done
  fi
  exit 0
fi

if [ "${1:-}" = "compose" ] && [ "${2:-}" = "down" ]; then
  printf '%s\n' "$*" >> "$FAKE_DOCKER_ARGS_FILE"
  exit 0
fi

printf 'unexpected fake docker command: %s\n' "$*" >&2
exit 1
SH
  chmod +x "$fake_bin/docker"

  python3 - <<'PY' &
import socket
import sys
import time

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
try:
    sock.bind(("0.0.0.0", 8080))
    sock.listen(1)
except OSError:
    sys.exit(0)
time.sleep(60)
PY
  listener_pid="$!"
  sleep 0.5

  cd "$tmp_dir/demo"
  PATH="$fake_bin:$PATH" FAKE_DOCKER_PORT_FILE="$port_file" FAKE_DOCKER_ARGS_FILE="$args_file" "$repo_root/bin/carbide" run dev > "$tmp_dir/run-dev.out"
  grep -q "Carbide dev" "$tmp_dir/run-dev.out"
  grep -Eq "^app[[:space:]]+http://localhost:" "$tmp_dir/run-dev.out"
  grep -Eq "^api[[:space:]]+http://localhost:" "$tmp_dir/run-dev.out"
  ! grep -Eq "^port[[:space:]]+" "$tmp_dir/run-dev.out"
  ! grep -Eq "^login[[:space:]]+" "$tmp_dir/run-dev.out"
  ! grep -Eq "^mode[[:space:]]+" "$tmp_dir/run-dev.out"
  ! grep -Eq "^status[[:space:]]+" "$tmp_dir/run-dev.out"
  ! grep -Eq "^containers[[:space:]]+" "$tmp_dir/run-dev.out"
  ! grep -Eq "^logs[[:space:]]+" "$tmp_dir/run-dev.out"
  ! grep -Eq "^stop[[:space:]]+" "$tmp_dir/run-dev.out"
  ! grep -Eq "^watch[[:space:]]+enabled" "$tmp_dir/run-dev.out"
  ! grep -q "busy, using" "$tmp_dir/run-dev.out"
  ! grep -q "^Watch enabled$" "$tmp_dir/run-dev.out"
  grep -Eq "^[0-9]{2}:[0-9]{2}:[0-9]{2}[[:space:]]+backend[[:space:]]+GET /health" "$tmp_dir/run-dev.out"
  grep -Eq "^[0-9]{2}:[0-9]{2}:[0-9]{2}[[:space:]]+frontend[[:space:]]+listening on :8080" "$tmp_dir/run-dev.out"
  grep -Eq "^[0-9]{2}:[0-9]{2}:[0-9]{2}[[:space:]]+watch[[:space:]]+rebuilding backend" "$tmp_dir/run-dev.out"
  test -f "$tmp_dir/demo/.carbide/log/dev.jsonl"
  grep -q '"service":"backend"' "$tmp_dir/demo/.carbide/log/dev.jsonl"
  grep -q '"message":"GET /health"' "$tmp_dir/demo/.carbide/log/dev.jsonl"
  PATH="$fake_bin:$PATH" "$repo_root/bin/carbide" logs service backend > "$tmp_dir/logs-backend.out"
  grep -Eq "^[0-9]{2}:[0-9]{2}:[0-9]{2}[[:space:]]+backend[[:space:]]+GET /health" "$tmp_dir/logs-backend.out"
  PATH="$fake_bin:$PATH" "$repo_root/bin/carbide" logs json containing listening > "$tmp_dir/logs-json.out"
  grep -q '"service":"frontend"' "$tmp_dir/logs-json.out"
  grep -q '"message":"listening on :8080"' "$tmp_dir/logs-json.out"
  PATH="$fake_bin:$PATH" FAKE_DOCKER_PORT_FILE="$port_file" "$repo_root/bin/carbide" status > "$tmp_dir/status.out"
  grep -q "Carbide status" "$tmp_dir/status.out"
  grep -Eq "^service[[:space:]]+container[[:space:]]+ports[[:space:]]+internal[[:space:]]+status" "$tmp_dir/status.out"
  grep -Eq "^frontend[[:space:]]+demo-frontend-1[[:space:]]+localhost:[0-9]+[[:space:]]+8080/tcp[[:space:]]+running \\(healthy\\)" "$tmp_dir/status.out"
  grep -Eq "^backend[[:space:]]+demo-backend-1[[:space:]]+-[[:space:]]+8080/tcp[[:space:]]+running \\(healthy\\)" "$tmp_dir/status.out"
  grep -Eq "^db[[:space:]]+demo-db-1[[:space:]]+-[[:space:]]+5432/tcp[[:space:]]+running \\(healthy\\)" "$tmp_dir/status.out"
  grep -q -- "--quiet-build" "$args_file"
  grep -q -- "--quiet-pull" "$args_file"
  grep -q "compose logs -f --tail 80 --no-color" "$args_file"
  grep -q "compose watch --no-up --quiet" "$args_file"
  ! grep -q "compose down" "$args_file"
  PATH="$fake_bin:$PATH" FAKE_DOCKER_ARGS_FILE="$args_file" "$repo_root/bin/carbide" stop dev > "$tmp_dir/stop-dev.out"
  grep -q "Carbide stop dev" "$tmp_dir/stop-dev.out"
  grep -Eq "^dev[[:space:]]+stopped" "$tmp_dir/stop-dev.out"
  grep -q "compose down --remove-orphans" "$args_file"
  PATH="$fake_bin:$PATH" FAKE_DOCKER_ARGS_FILE="$args_file" "$repo_root/bin/carbide" follow logs service backend > "$tmp_dir/logs-follow.out"
  grep -Eq "^[0-9]{2}:[0-9]{2}:[0-9]{2}[[:space:]]+backend[[:space:]]+GET /health" "$tmp_dir/logs-follow.out"
  ! grep -q "frontend" "$tmp_dir/logs-follow.out"
  selected_port="$(cat "$port_file")"
  if [ "$selected_port" = "8080" ]; then
    printf 'carbide run dev should not select occupied port 8080\n' >&2
    exit 1
  fi

  if PATH="$fake_bin:$PATH" FAKE_DOCKER_PORT_FILE="$port_file" FAKE_DOCKER_ARGS_FILE="$args_file" CARBIDE_HTTP_PORT=8080 "$repo_root/bin/carbide" run dev > "$tmp_dir/explicit-port.out" 2> "$tmp_dir/explicit-port.err"; then
    printf 'explicit occupied CARBIDE_HTTP_PORT should fail before compose starts\n' >&2
    exit 1
  fi
  grep -q "port 8080 is already in use" "$tmp_dir/explicit-port.err"

  : > "$args_file"
  PATH="$fake_bin:$PATH" FAKE_DOCKER_STREAM_LONG=1 FAKE_DOCKER_PORT_FILE="$port_file" FAKE_DOCKER_ARGS_FILE="$args_file" "$repo_root/bin/carbide" run dev > "$tmp_dir/run-dev-detach.out" &
  run_dev_pid="$!"
  for _ in $(seq 1 50); do
    if grep -q "GET /health" "$tmp_dir/run-dev-detach.out" 2>/dev/null; then
      break
    fi
    sleep 0.1
  done
  kill -INT "$run_dev_pid"
  wait "$run_dev_pid"
  grep -Eq "^logs[[:space:]]+detached" "$tmp_dir/run-dev-detach.out"
  grep -Eq "^dev[[:space:]]+running" "$tmp_dir/run-dev-detach.out"
  grep -Eq "^follow[[:space:]]+carbide follow logs" "$tmp_dir/run-dev-detach.out"
  grep -Eq "^stop[[:space:]]+carbide stop dev" "$tmp_dir/run-dev-detach.out"
  ! grep -q "compose down" "$args_file"

  kill "$listener_pid" >/dev/null 2>&1 || true
fi

remote_repo="$tmp_dir/carbide-origin.git"
installed_repo="$tmp_dir/installed-carbide"
upgrade_work="$tmp_dir/upgrade-work"

git init --bare "$remote_repo" >/dev/null
git init "$installed_repo" >/dev/null
mkdir -p "$installed_repo/bin"
cp "$repo_root/bin/carbide" "$installed_repo/bin/carbide"
cp "$repo_root/.gitignore" "$installed_repo/.gitignore"
cp "$repo_root/go.mod" "$installed_repo/go.mod"
cp -R "$repo_root/cmd" "$installed_repo/cmd"
cp -R "$repo_root/internal" "$installed_repo/internal"
git -C "$installed_repo" add .gitignore bin/carbide
git -C "$installed_repo" add go.mod cmd internal
git -C "$installed_repo" -c user.name="Carbide Test" -c user.email="test@carbide.local" commit -m "Initial install" >/dev/null
git -C "$installed_repo" branch -M main
git -C "$installed_repo" remote add origin "$remote_repo"
git -C "$installed_repo" push -u origin main >/dev/null
git --git-dir="$remote_repo" symbolic-ref HEAD refs/heads/main

CARBIDE_HOME="$installed_repo" "$repo_root/bin/carbide" upgrade > "$tmp_dir/upgrade-current.out"
grep -q "Carbide upgrade" "$tmp_dir/upgrade-current.out"
grep -Eq "^status[[:space:]]+up to date" "$tmp_dir/upgrade-current.out"

git clone --branch main "$remote_repo" "$upgrade_work" >/dev/null
printf '# changed\n' >> "$upgrade_work/README.md"
git -C "$upgrade_work" add README.md
git -C "$upgrade_work" -c user.name="Carbide Test" -c user.email="test@carbide.local" commit -m "Remote update" >/dev/null
git -C "$upgrade_work" push >/dev/null

CARBIDE_HOME="$installed_repo" "$repo_root/bin/carbide" upgrade > "$tmp_dir/upgrade-new.out"
grep -q "Carbide upgrade" "$tmp_dir/upgrade-new.out"
grep -Eq "^status[[:space:]]+upgraded" "$tmp_dir/upgrade-new.out"
test -x "$installed_repo/.bin/carbide"

printf 'cli scaffold ok\n'
