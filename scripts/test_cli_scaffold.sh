#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

export SEALION_HOME="$repo_root"

"$repo_root/bin/sealion" help > "$tmp_dir/help.out"
grep -q "sealion help" "$tmp_dir/help.out"
grep -q "sealion upgrade" "$tmp_dir/help.out"
grep -q "sealion format" "$tmp_dir/help.out"
grep -q "sealion run dev" "$tmp_dir/help.out"

cd "$tmp_dir"
"$repo_root/bin/sealion" new demo

test -f "$tmp_dir/demo/sealion.toml"
test -f "$tmp_dir/demo/docker-compose.yml"
test -f "$tmp_dir/demo/Dockerfile"
test -f "$tmp_dir/demo/src/app.h"
test -f "$tmp_dir/demo/src/main.c"
test -f "$tmp_dir/demo/model/user.c"
test -f "$tmp_dir/demo/model/session.c"
test -f "$tmp_dir/demo/controller/auth_controller.c"
test -f "$tmp_dir/demo/controller/page_controller.c"
test -f "$tmp_dir/demo/view/home.skin"
test -f "$tmp_dir/demo/view/login.skin"
test -f "$tmp_dir/demo/view/register.skin"
test -f "$tmp_dir/demo/view/dashboard.skin"
test -f "$tmp_dir/demo/view/not_found.skin"
test -d "$tmp_dir/demo/ui_components/l1"
test -f "$tmp_dir/demo/ui_components/l1/action_link.scale"
test -f "$tmp_dir/demo/ui_components/l1/button.scale"
test -f "$tmp_dir/demo/ui_components/l1/form_label.scale"
test -f "$tmp_dir/demo/ui_components/l1/heading.scale"
test -f "$tmp_dir/demo/ui_components/l1/muted_text.scale"
test -f "$tmp_dir/demo/ui_components/l1/text_input.scale"
test -f "$tmp_dir/demo/ui_components/l2/layout.scale"
test -f "$tmp_dir/demo/ui_components/l2/auth_form.scale"
test -f "$tmp_dir/demo/ui_components/l2/page_header.scale"
test -f "$tmp_dir/demo/ui_components/l3/home_page.scale"
test -f "$tmp_dir/demo/ui_components/l3/dashboard_page.scale"
test -f "$tmp_dir/demo/ui_components/l3/not_found_page.scale"
test -f "$tmp_dir/demo/migrations/001_auth.sql"

grep -q 'name = "demo"' "$tmp_dir/demo/sealion.toml"
grep -q "default_port = 8080" "$tmp_dir/demo/sealion.toml"
! grep -q 'url = "http://localhost:8080"' "$tmp_dir/demo/sealion.toml"
grep -q 'name: demo' "$tmp_dir/demo/docker-compose.yml"
grep -q 'PUBLIC_URL: "http://localhost:${SEALION_HTTP_PORT:-8080}"' "$tmp_dir/demo/docker-compose.yml"
grep -q "develop:" "$tmp_dir/demo/docker-compose.yml"
grep -q "watch:" "$tmp_dir/demo/docker-compose.yml"
grep -q "action: rebuild" "$tmp_dir/demo/docker-compose.yml"
grep -q "path: ./src" "$tmp_dir/demo/docker-compose.yml"
grep -q "path: ./model" "$tmp_dir/demo/docker-compose.yml"
grep -q "path: ./controller" "$tmp_dir/demo/docker-compose.yml"
grep -q "path: ./view" "$tmp_dir/demo/docker-compose.yml"
grep -q "path: ./ui_components" "$tmp_dir/demo/docker-compose.yml"
grep -q "path: ./Dockerfile" "$tmp_dir/demo/docker-compose.yml"
grep -q 'admin@sealion.local' "$tmp_dir/demo/controller/auth_controller.c"
grep -q "render_template_text" "$tmp_dir/demo/src/main.c"
grep -q "respond_view" "$tmp_dir/demo/src/main.c"
grep -q "view/%s.skin" "$tmp_dir/demo/src/main.c"
grep -q "component_level_from_name" "$tmp_dir/demo/src/main.c"
grep -q "component_allowed_in_context" "$tmp_dir/demo/src/main.c"
grep -q "parse_passover_props" "$tmp_dir/demo/src/main.c"
grep -q "find_component_close" "$tmp_dir/demo/src/main.c"
! grep -q "view/%s.html" "$tmp_dir/demo/src/main.c"
! grep -q "view/layout.skin" "$tmp_dir/demo/src/main.c"
grep -q "ui_components/%s.scale" "$tmp_dir/demo/src/main.c"
! grep -q "ui_components/%s.scales" "$tmp_dir/demo/src/main.c"
grep -q "listening inside container" "$tmp_dir/demo/src/main.c"
! grep -q "<style>" "$tmp_dir/demo/src/main.c"
! grep -R "<style>" "$tmp_dir/demo/view" >/dev/null
test ! -e "$tmp_dir/demo/view/layout.skin"
grep -q "{{ title }}" "$tmp_dir/demo/ui_components/l2/layout.scale"
grep -q "<style>" "$tmp_dir/demo/ui_components/l2/layout.scale"
grep -q "{!! content !!}" "$tmp_dir/demo/ui_components/l2/layout.scale"
grep -Fxq '<s-l2.layout :passover=[' "$tmp_dir/demo/view/home.skin"
grep -Fxq '  title,' "$tmp_dir/demo/view/home.skin"
grep -Fxq '  app_name' "$tmp_dir/demo/view/home.skin"
grep -Fxq ']>' "$tmp_dir/demo/view/home.skin"
grep -Fq '</s-l2.layout>' "$tmp_dir/demo/view/home.skin"
grep -Fxq '  <s-l3.home-page :passover=[' "$tmp_dir/demo/view/home.skin"
grep -Fxq '    app_name' "$tmp_dir/demo/view/home.skin"
grep -Fxq '  ] />' "$tmp_dir/demo/view/home.skin"
grep -Fxq '  <s-l2.auth-form :passover=[' "$tmp_dir/demo/view/login.skin"
grep -Fxq '    auth_title,' "$tmp_dir/demo/view/login.skin"
grep -Fxq '    auth_footer' "$tmp_dir/demo/view/login.skin"
grep -Fxq '  <s-l2.auth-form :passover=[' "$tmp_dir/demo/view/register.skin"
grep -Fxq '  <s-l3.dashboard-page :passover=[' "$tmp_dir/demo/view/dashboard.skin"
grep -Fxq '    user_email' "$tmp_dir/demo/view/dashboard.skin"
grep -q '<s-l3.not-found-page />' "$tmp_dir/demo/view/not_found.skin"
grep -q "{{ user_email }}" "$tmp_dir/demo/ui_components/l3/dashboard_page.scale"
grep -q '<s-l1.heading' "$tmp_dir/demo/ui_components/l2/page_header.scale"
grep -q '<s-l1.text-input' "$tmp_dir/demo/ui_components/l2/auth_form.scale"
grep -q '<s-l2.page-header' "$tmp_dir/demo/ui_components/l3/home_page.scale"
grep -q '<s-l1.action-link' "$tmp_dir/demo/ui_components/l3/home_page.scale"
! grep -R "{% component" "$tmp_dir/demo/view" "$tmp_dir/demo/ui_components" >/dev/null
! grep -R ':auth-title=' "$tmp_dir/demo/view" "$tmp_dir/demo/ui_components/l3" >/dev/null
! grep -R '<s-l1' "$tmp_dir/demo/view" >/dev/null
! grep -R '<s-' "$tmp_dir/demo/ui_components/l1" >/dev/null
! grep -R -E '<s-l[23]' "$tmp_dir/demo/ui_components/l2" >/dev/null
! grep -R '<s-l3' "$tmp_dir/demo/ui_components/l3" >/dev/null
! find "$tmp_dir/demo/view" -name '*.html' -print -quit | grep -q .
! find "$tmp_dir/demo/ui_components" -name '*.html' -print -quit | grep -q .
! find "$tmp_dir/demo/ui_components" -name '*.scales' -print -quit | grep -q .
! grep -R "views/" "$tmp_dir/demo" >/dev/null
! grep -R "__PROJECT_" "$tmp_dir/demo" >/dev/null

cp "$tmp_dir/demo/view/login.skin" "$tmp_dir/login.formatted"
printf '<s-l2.layout :passover=[title,app_name]>\n  <s-l2.auth-form :passover=[auth_title,auth_action,email_value,password_autocomplete,submit_label,error,auth_footer] />\n</s-l2.layout>\n' > "$tmp_dir/demo/view/login.skin"
(
  cd "$tmp_dir/demo"
  "$repo_root/bin/sealion" format > "$tmp_dir/format.out"
)
grep -q "formatted 1 file(s)" "$tmp_dir/format.out"
cmp -s "$tmp_dir/login.formatted" "$tmp_dir/demo/view/login.skin"
"$repo_root/bin/sealion" format "$tmp_dir/demo/view/login.skin" > "$tmp_dir/format-idempotent.out"
grep -q "formatted 0 file(s)" "$tmp_dir/format-idempotent.out"

printf '<s-l1.badge :passover=[label,tone] />\n' > "$tmp_dir/loose.scale"
"$repo_root/bin/sealion" format "$tmp_dir/loose.scale" > "$tmp_dir/format-scale.out"
grep -q "formatted 1 file(s)" "$tmp_dir/format-scale.out"
grep -Fxq '<s-l1.badge :passover=[' "$tmp_dir/loose.scale"
grep -Fxq '  label,' "$tmp_dir/loose.scale"
grep -Fxq '  tone' "$tmp_dir/loose.scale"
grep -Fxq '] />' "$tmp_dir/loose.scale"
"$repo_root/bin/sealion" format "$tmp_dir/loose.scale" > "$tmp_dir/format-scale-idempotent.out"
grep -q "formatted 0 file(s)" "$tmp_dir/format-scale-idempotent.out"

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
  printf '      --watch    Watch source code and rebuild/refresh containers when files are updated.\n'
  exit 0
fi

if [ "${1:-}" = "compose" ] && [ "${2:-}" = "up" ]; then
  printf '%s\n' "${SEALION_HTTP_PORT:-}" > "$FAKE_DOCKER_PORT_FILE"
  printf '%s\n' "$*" > "$FAKE_DOCKER_ARGS_FILE"
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
  grep -q "app: http://localhost:" "$tmp_dir/run-dev.out"
  grep -q "watch: enabled" "$tmp_dir/run-dev.out"
  grep -q -- "--watch" "$args_file"
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
