#!/usr/bin/env bash
set -euo pipefail

domain="sealion.ryangerardwilson.com"

required_files=(
  "README.md"
  "install.sh"
  "bin/sealion"
  ".github/workflows/ci.yml"
  ".github/workflows/pages.yml"
  "docs/engineering/CI_CD_REGRESSION_TESTS.md"
  "docs/engineering/COMPONENT_STYLE_SYSTEM.md"
  "docs/engineering/DIRECTORY_STRUCTURE.md"
  "docs/engineering/INITIAL_USER_EXPERIENCE.md"
  "docs/site/CNAME"
  "docs/site/index.html"
  "docs/site/component-style-system.html"
  "docs/site/initial-user-experience.html"
  "docs/site/ci-cd-regression-tests.html"
  "docs/site/repo-structure.html"
  "docs/site/assets/styles.css"
  "scripts/test_cli_scaffold.sh"
  "scripts/test_starter_docker_flow.sh"
  "templates/default/Dockerfile"
  "templates/default/docker-compose.yml"
  "templates/default/sealion.toml"
  "templates/default/src/app.h"
  "templates/default/src/main.c"
  "templates/default/model/user.c"
  "templates/default/model/session.c"
  "templates/default/controller/auth_controller.c"
  "templates/default/controller/page_controller.c"
  "templates/default/view/home.skin"
  "templates/default/view/register.skin"
  "templates/default/view/login.skin"
  "templates/default/view/dashboard.skin"
  "templates/default/view/not_found.skin"
  "templates/default/ui_components/l1/.gitkeep"
  "templates/default/ui_components/l1/action_link.scale"
  "templates/default/ui_components/l1/button.scale"
  "templates/default/ui_components/l1/form_label.scale"
  "templates/default/ui_components/l1/heading.scale"
  "templates/default/ui_components/l1/muted_text.scale"
  "templates/default/ui_components/l1/text_input.scale"
  "templates/default/ui_components/l2/layout.scale"
  "templates/default/ui_components/l2/auth_form.scale"
  "templates/default/ui_components/l2/page_header.scale"
  "templates/default/ui_components/l3/home_page.scale"
  "templates/default/ui_components/l3/dashboard_page.scale"
  "templates/default/ui_components/l3/not_found_page.scale"
  "templates/default/migrations/001_auth.sql"
)

required_dirs=(
  "src"
  "src/ui"
  "include/sealion"
  "include/sealion/ui"
  "tests/unit"
  "tests/integration"
  "tests/regression"
  "tests/fixtures"
  "examples/hello"
  "infra/compose"
  "infra/schemas"
  "templates/default"
  "templates/default/src"
  "templates/default/model"
  "templates/default/controller"
  "templates/default/view"
  "templates/default/ui_components"
  "templates/default/ui_components/l1"
  "templates/default/ui_components/l2"
  "templates/default/ui_components/l3"
  "templates/default/migrations"
)

for path in "${required_files[@]}"; do
  test -f "$path" || {
    printf 'missing required file: %s\n' "$path" >&2
    exit 1
  }
done

for path in "${required_dirs[@]}"; do
  test -d "$path" || {
    printf 'missing required directory: %s\n' "$path" >&2
    exit 1
  }
done

grep -qx "$domain" docs/site/CNAME || {
  printf 'docs/site/CNAME must contain only %s\n' "$domain" >&2
  exit 1
}

grep -q "one mandatory app container image" README.md
grep -q "Postgres-only" README.md
grep -q "Separate runtime boundaries" README.md
grep -q "Infrastructure as code" README.md
grep -q "Framework-owned component styling" README.md
grep -q "generated Docker Compose setup" README.md
grep -q "Postgres-backed queues" README.md
grep -q "sealion new" README.md
grep -q "sealion format" README.md
grep -q "sealion run dev" README.md
grep -q "command_format" bin/sealion
grep -q "default_port = 8080" templates/default/sealion.toml
! grep -q 'url = "http://localhost:8080"' templates/default/sealion.toml
grep -q 'PUBLIC_URL: "http://localhost:${SEALION_HTTP_PORT:-8080}"' templates/default/docker-compose.yml
grep -q "develop:" templates/default/docker-compose.yml
grep -q "watch:" templates/default/docker-compose.yml
grep -q "action: rebuild" templates/default/docker-compose.yml
grep -q "path: ./src" templates/default/docker-compose.yml
grep -q "path: ./model" templates/default/docker-compose.yml
grep -q "path: ./controller" templates/default/docker-compose.yml
grep -q "path: ./view" templates/default/docker-compose.yml
grep -q "path: ./ui_components" templates/default/docker-compose.yml
grep -q "path: ./Dockerfile" templates/default/docker-compose.yml
grep -q "COPY model ./model" templates/default/Dockerfile
grep -q "COPY controller ./controller" templates/default/Dockerfile
grep -q "COPY view ./view" templates/default/Dockerfile
grep -q "COPY ui_components ./ui_components" templates/default/Dockerfile
test ! -e templates/default/view/layout.skin
grep -q "{{ title }}" templates/default/ui_components/l2/layout.scale
grep -q "<style>" templates/default/ui_components/l2/layout.scale
grep -q "{!! content !!}" templates/default/ui_components/l2/layout.scale
grep -Fxq '<s-l2.layout :passover=[' templates/default/view/home.skin
grep -Fxq '  title,' templates/default/view/home.skin
grep -Fxq '  app_name' templates/default/view/home.skin
grep -Fxq ']>' templates/default/view/home.skin
grep -Fq '</s-l2.layout>' templates/default/view/home.skin
grep -Fxq '  <s-l3.home-page :passover=[' templates/default/view/home.skin
grep -Fxq '    app_name' templates/default/view/home.skin
grep -Fxq '  ] />' templates/default/view/home.skin
grep -Fxq '  <s-l2.auth-form :passover=[' templates/default/view/login.skin
grep -Fxq '    auth_title,' templates/default/view/login.skin
grep -Fxq '    auth_footer' templates/default/view/login.skin
grep -Fxq '  <s-l2.auth-form :passover=[' templates/default/view/register.skin
grep -Fxq '  <s-l3.dashboard-page :passover=[' templates/default/view/dashboard.skin
grep -Fxq '    user_email' templates/default/view/dashboard.skin
grep -q '<s-l3.not-found-page />' templates/default/view/not_found.skin
grep -q "{{ user_email }}" templates/default/ui_components/l3/dashboard_page.scale
! grep -R "{% component" templates/default/view templates/default/ui_components README.md docs >/dev/null
! grep -R ':auth-title=' templates/default/view templates/default/ui_components/l3 >/dev/null
grep -q "render_template_text" templates/default/src/main.c
grep -q "respond_view" templates/default/src/main.c
grep -q "view/%s.skin" templates/default/src/main.c
grep -q "component_level_from_name" templates/default/src/main.c
grep -q "component_allowed_in_context" templates/default/src/main.c
grep -q "parse_passover_props" templates/default/src/main.c
grep -q "find_component_close" templates/default/src/main.c
! grep -q "view/%s.html" templates/default/src/main.c
! grep -q "view/layout.skin" templates/default/src/main.c
grep -q "ui_components/%s.scale" templates/default/src/main.c
! grep -q "ui_components/%s.scales" templates/default/src/main.c
! grep -q "<style>" templates/default/src/main.c
! grep -R "<style>" templates/default/view >/dev/null
grep -q '<s-l1.heading' templates/default/ui_components/l2/page_header.scale
grep -q '<s-l1.text-input' templates/default/ui_components/l2/auth_form.scale
grep -q '<s-l2.page-header' templates/default/ui_components/l3/home_page.scale
grep -q '<s-l1.action-link' templates/default/ui_components/l3/home_page.scale
! grep -R '<s-l1' templates/default/view >/dev/null
! grep -R '<s-' templates/default/ui_components/l1 >/dev/null
! grep -R -E '<s-l[23]' templates/default/ui_components/l2 >/dev/null
! grep -R '<s-l3' templates/default/ui_components/l3 >/dev/null
! find templates/default/view -name '*.html' -print -quit | grep -q .
! find templates/default/ui_components -name '*.html' -print -quit | grep -q .
! find templates/default/ui_components -name '*.scales' -print -quit | grep -q .
! grep -R "views/" templates/default README.md docs >/dev/null
grep -q "listening inside container" templates/default/src/main.c
grep -q "open %s" templates/default/src/main.c
grep -q "compose_supports_watch" bin/sealion
grep -q -- "--watch" bin/sealion

grep -q "$domain" docs/site/index.html
grep -q "Component styling" docs/site/index.html
grep -q "Initial user experience" docs/site/index.html
grep -q "Tailwind-like ergonomics without the Tailwind dependency" docs/site/component-style-system.html
grep -q "Install, create, run, log in" docs/site/initial-user-experience.html
grep -q "CI/CD regression plan" docs/site/ci-cd-regression-tests.html
grep -q "Directory structure" docs/site/repo-structure.html

printf 'repo contract ok\n'
