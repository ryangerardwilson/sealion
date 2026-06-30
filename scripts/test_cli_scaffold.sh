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

cd "$tmp_dir"
"$repo_root/bin/sealion" new demo

test -f "$tmp_dir/demo/sealion.toml"
test -f "$tmp_dir/demo/docker-compose.yml"
test -f "$tmp_dir/demo/Dockerfile"
test -f "$tmp_dir/demo/src/main.c"
test -f "$tmp_dir/demo/migrations/001_auth.sql"

grep -q 'name = "demo"' "$tmp_dir/demo/sealion.toml"
grep -q 'name: demo' "$tmp_dir/demo/docker-compose.yml"
grep -q 'admin@sealion.local' "$tmp_dir/demo/src/main.c"
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
  mkdir "$fake_bin"
  cat > "$fake_bin/docker" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "compose" ] && [ "${2:-}" = "version" ]; then
  printf 'Docker Compose fake\n'
  exit 0
fi

if [ "${1:-}" = "compose" ] && [ "${2:-}" = "up" ]; then
  printf '%s\n' "${SEALION_HTTP_PORT:-}" > "$FAKE_DOCKER_PORT_FILE"
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
  PATH="$fake_bin:$PATH" FAKE_DOCKER_PORT_FILE="$port_file" "$repo_root/bin/sealion" run dev > "$tmp_dir/run-dev.out"
  grep -q "app: http://localhost:" "$tmp_dir/run-dev.out"
  selected_port="$(cat "$port_file")"
  if [ "$selected_port" = "8080" ]; then
    printf 'sealion run dev should not select occupied port 8080\n' >&2
    exit 1
  fi

  if PATH="$fake_bin:$PATH" FAKE_DOCKER_PORT_FILE="$port_file" SEALION_HTTP_PORT=8080 "$repo_root/bin/sealion" run dev > "$tmp_dir/explicit-port.out" 2> "$tmp_dir/explicit-port.err"; then
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
git -C "$installed_repo" add bin/sealion
git -C "$installed_repo" -c user.name="Sealion Test" -c user.email="test@sealion.local" commit -m "Initial install" >/dev/null
git -C "$installed_repo" branch -M main
git -C "$installed_repo" remote add origin "$remote_repo"
git -C "$installed_repo" push -u origin main >/dev/null
git --git-dir="$remote_repo" symbolic-ref HEAD refs/heads/main

SEALION_HOME="$installed_repo" "$repo_root/bin/sealion" upgrade > "$tmp_dir/upgrade-current.out"
grep -q "already up to date" "$tmp_dir/upgrade-current.out"

git clone --branch main "$remote_repo" "$upgrade_work" >/dev/null
printf '# changed\n' >> "$upgrade_work/README.md"
git -C "$upgrade_work" add README.md
git -C "$upgrade_work" -c user.name="Sealion Test" -c user.email="test@sealion.local" commit -m "Remote update" >/dev/null
git -C "$upgrade_work" push >/dev/null

SEALION_HOME="$installed_repo" "$repo_root/bin/sealion" upgrade > "$tmp_dir/upgrade-new.out"
grep -q "upgraded sealion" "$tmp_dir/upgrade-new.out"

printf 'cli scaffold ok\n'
