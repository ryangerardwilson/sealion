#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

export SEALION_HOME="$repo_root"

"$repo_root/bin/sealion" help > "$tmp_dir/help.out"
grep -q "sealion help" "$tmp_dir/help.out"
grep -q "sealion upgrade" "$tmp_dir/help.out"
grep -q "sealion run dev" "$tmp_dir/help.out"
! grep -q "sealion format" "$tmp_dir/help.out"

if "$repo_root/bin/sealion" format >/tmp/sealion-format.out 2>/tmp/sealion-format.err; then
  printf 'sealion format should not exist\n' >&2
  exit 1
fi
grep -q "unknown command: format" /tmp/sealion-format.err

cd "$tmp_dir"
"$repo_root/bin/sealion" new demo

test -f "$tmp_dir/demo/sealion.toml"
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
test -f "$tmp_dir/demo/src/app.h"
test -f "$tmp_dir/demo/src/main.c"
test -f "$tmp_dir/demo/model/user.c"
test -f "$tmp_dir/demo/model/session.c"
test -f "$tmp_dir/demo/controller/auth_controller.c"
test -f "$tmp_dir/demo/controller/page_controller.c"
test -f "$tmp_dir/demo/migrations/001_auth.sql"

grep -q 'name = "demo"' "$tmp_dir/demo/sealion.toml"
grep -q "default_port = 8080" "$tmp_dir/demo/sealion.toml"
! grep -q 'url = "http://localhost:8080"' "$tmp_dir/demo/sealion.toml"
grep -q 'name: demo' "$tmp_dir/demo/docker-compose.yml"
grep -q "frontend:" "$tmp_dir/demo/docker-compose.yml"
grep -q "backend:" "$tmp_dir/demo/docker-compose.yml"
grep -q "db:" "$tmp_dir/demo/docker-compose.yml"
grep -q 'PUBLIC_URL: "http://localhost:${SEALION_HTTP_PORT:-8080}"' "$tmp_dir/demo/docker-compose.yml"
grep -q "develop:" "$tmp_dir/demo/docker-compose.yml"
grep -q "watch:" "$tmp_dir/demo/docker-compose.yml"
grep -q "action: rebuild" "$tmp_dir/demo/docker-compose.yml"
grep -q "context: ./view/web" "$tmp_dir/demo/docker-compose.yml"
grep -q "path: ./view/web/src" "$tmp_dir/demo/docker-compose.yml"
grep -q "path: ./view/web/package.json" "$tmp_dir/demo/docker-compose.yml"
grep -q "path: ./view/web/bun.lock" "$tmp_dir/demo/docker-compose.yml"
grep -q "path: ./src" "$tmp_dir/demo/docker-compose.yml"
grep -q "path: ./model" "$tmp_dir/demo/docker-compose.yml"
grep -q "path: ./controller" "$tmp_dir/demo/docker-compose.yml"
grep -q "path: ./Dockerfile" "$tmp_dir/demo/docker-compose.yml"
grep -q 'admin@sealion.local' "$tmp_dir/demo/model/user.c"
grep -q "respond_json" "$tmp_dir/demo/src/main.c"
grep -q "/api/login" "$tmp_dir/demo/src/main.c"
grep -q "/api/me" "$tmp_dir/demo/src/main.c"
grep -q "handle_api_dashboard" "$tmp_dir/demo/src/main.c"
grep -q "API listening inside backend container" "$tmp_dir/demo/src/main.c"
! grep -q "render_template_text" "$tmp_dir/demo/src/main.c"
! grep -q "respond_view" "$tmp_dir/demo/src/main.c"
! grep -q "<style>" "$tmp_dir/demo/src/main.c"
grep -q "oven/bun:1.3.14-debian" "$tmp_dir/demo/view/web/Dockerfile"
grep -q "bun install --frozen-lockfile" "$tmp_dir/demo/view/web/Dockerfile"
grep -q '"@tailwindcss/cli": "4.3.2"' "$tmp_dir/demo/view/web/package.json"
grep -q '"tailwindcss": "4.3.2"' "$tmp_dir/demo/view/web/package.json"
grep -q '"react": "19.2.7"' "$tmp_dir/demo/view/web/package.json"
grep -q "Bun.serve" "$tmp_dir/demo/view/web/src/server.jsx"
grep -q "proxying /api and /health" "$tmp_dir/demo/view/web/src/server.jsx"
grep -q '@import "tailwindcss";' "$tmp_dir/demo/view/web/src/styles.css"
grep -q '/api/${mode}' "$tmp_dir/demo/view/web/src/main.jsx"
grep -q "Bun frontend + C API + Postgres" "$tmp_dir/demo/view/web/src/main.jsx"
grep -q "React + Bun container" "$tmp_dir/demo/view/web/src/main.jsx"
grep -q "Containerized full stack development" "$tmp_dir/demo/view/web/src/main.jsx"
! find "$tmp_dir/demo" -path '*/ui_components/*' -print -quit | grep -q .
! grep -R "views/" "$tmp_dir/demo" >/dev/null
! grep -R "__PROJECT_" "$tmp_dir/demo" >/dev/null

mkdir "$tmp_dir/init-app"
cd "$tmp_dir/init-app"
"$repo_root/bin/sealion" init
test -f "$tmp_dir/init-app/sealion.toml"
grep -q 'name = "init-app"' "$tmp_dir/init-app/sealion.toml"

mkdir "$tmp_dir/not-empty"
touch "$tmp_dir/not-empty/file"
cd "$tmp_dir/not-empty"
if "$repo_root/bin/sealion" init >/tmp/sealion-init.out 2>/tmp/sealion-init.err; then
  printf 'sealion init should fail in a non-empty directory\n' >&2
  exit 1
fi
grep -q "requires an empty directory" /tmp/sealion-init.err

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

if [ "${1:-}" = "compose" ] && [ "${2:-}" = "up" ]; then
  printf '%s\n' "${SEALION_HTTP_PORT:-}" > "$FAKE_DOCKER_PORT_FILE"
  printf '%s\n' "$*" > "$FAKE_DOCKER_ARGS_FILE"
  exit 0
fi

if [ "${1:-}" = "compose" ] && [ "${2:-}" = "watch" ]; then
  printf '%s\n' "$*" >> "$FAKE_DOCKER_ARGS_FILE"
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
  PATH="$fake_bin:$PATH" FAKE_DOCKER_PORT_FILE="$port_file" FAKE_DOCKER_ARGS_FILE="$args_file" "$repo_root/bin/sealion" run dev > "$tmp_dir/run-dev.out"
  grep -q "Sealion dev" "$tmp_dir/run-dev.out"
  grep -Eq "^app[[:space:]]+http://localhost:" "$tmp_dir/run-dev.out"
  grep -Eq "^api[[:space:]]+http://localhost:" "$tmp_dir/run-dev.out"
  grep -Eq "^watch[[:space:]]+enabled" "$tmp_dir/run-dev.out"
  ! grep -q "^Watch enabled$" "$tmp_dir/run-dev.out"
  grep -q -- "--quiet-build" "$args_file"
  grep -q -- "--quiet-pull" "$args_file"
  grep -q "compose watch --no-up --quiet" "$args_file"
  selected_port="$(cat "$port_file")"
  if [ "$selected_port" = "8080" ]; then
    printf 'sealion run dev should not select occupied port 8080\n' >&2
    exit 1
  fi

  if PATH="$fake_bin:$PATH" FAKE_DOCKER_PORT_FILE="$port_file" FAKE_DOCKER_ARGS_FILE="$args_file" SEALION_HTTP_PORT=8080 "$repo_root/bin/sealion" run dev > "$tmp_dir/explicit-port.out" 2> "$tmp_dir/explicit-port.err"; then
    printf 'explicit occupied SEALION_HTTP_PORT should fail before compose starts\n' >&2
    exit 1
  fi
  grep -q "port 8080 is already in use" "$tmp_dir/explicit-port.err"

  kill "$listener_pid" >/dev/null 2>&1 || true
fi

remote_repo="$tmp_dir/sealion-origin.git"
installed_repo="$tmp_dir/installed-sealion"
upgrade_work="$tmp_dir/upgrade-work"

git init --bare "$remote_repo" >/dev/null
git init "$installed_repo" >/dev/null
mkdir -p "$installed_repo/bin"
cp "$repo_root/bin/sealion" "$installed_repo/bin/sealion"
cp "$repo_root/.gitignore" "$installed_repo/.gitignore"
cp "$repo_root/go.mod" "$installed_repo/go.mod"
cp -R "$repo_root/cmd" "$installed_repo/cmd"
git -C "$installed_repo" add .gitignore bin/sealion
git -C "$installed_repo" add go.mod cmd
git -C "$installed_repo" -c user.name="Sealion Test" -c user.email="test@sealion.local" commit -m "Initial install" >/dev/null
git -C "$installed_repo" branch -M main
git -C "$installed_repo" remote add origin "$remote_repo"
git -C "$installed_repo" push -u origin main >/dev/null
git --git-dir="$remote_repo" symbolic-ref HEAD refs/heads/main

SEALION_HOME="$installed_repo" "$repo_root/bin/sealion" upgrade > "$tmp_dir/upgrade-current.out"
grep -q "Sealion upgrade" "$tmp_dir/upgrade-current.out"
grep -Eq "^status[[:space:]]+up to date" "$tmp_dir/upgrade-current.out"

git clone --branch main "$remote_repo" "$upgrade_work" >/dev/null
printf '# changed\n' >> "$upgrade_work/README.md"
git -C "$upgrade_work" add README.md
git -C "$upgrade_work" -c user.name="Sealion Test" -c user.email="test@sealion.local" commit -m "Remote update" >/dev/null
git -C "$upgrade_work" push >/dev/null

SEALION_HOME="$installed_repo" "$repo_root/bin/sealion" upgrade > "$tmp_dir/upgrade-new.out"
grep -q "Sealion upgrade" "$tmp_dir/upgrade-new.out"
grep -Eq "^status[[:space:]]+upgraded" "$tmp_dir/upgrade-new.out"
test -x "$installed_repo/.bin/sealion"

printf 'cli scaffold ok\n'
