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
  "templates/default/view/layout.skin"
  "templates/default/view/home.skin"
  "templates/default/view/register.skin"
  "templates/default/view/login.skin"
  "templates/default/view/dashboard.skin"
  "templates/default/view/not_found.skin"
  "templates/default/ui_components/l1/base_styles.scales"
  "templates/default/ui_components/l2/page_shell.scales"
  "templates/default/ui_components/l2/auth_form.scales"
  "templates/default/ui_components/l3/home_page.scales"
  "templates/default/ui_components/l3/login_page.scales"
  "templates/default/ui_components/l3/register_page.scales"
  "templates/default/ui_components/l3/dashboard_page.scales"
  "templates/default/ui_components/l3/not_found_page.scales"
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
grep -q "sealion run dev" README.md
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
grep -q "{{ title }}" templates/default/view/layout.skin
grep -q '<s-l1.base-styles />' templates/default/view/layout.skin
grep -q '<s-l2.page-shell :content="content" />' templates/default/view/layout.skin
grep -q "{!! content !!}" templates/default/ui_components/l2/page_shell.scales
grep -q '<s-l3.home-page :app-name="app_name" />' templates/default/view/home.skin
grep -q '<s-l3.login-page :auth-title="auth_title" :auth-action="auth_action" :email-value="email_value" :password-autocomplete="password_autocomplete" :submit-label="submit_label" :error="error" :auth-footer="auth_footer" />' templates/default/view/login.skin
grep -q '<s-l3.register-page :auth-title="auth_title" :auth-action="auth_action" :email-value="email_value" :password-autocomplete="password_autocomplete" :submit-label="submit_label" :error="error" :auth-footer="auth_footer" />' templates/default/view/register.skin
grep -q '<s-l3.dashboard-page :user-email="user_email" />' templates/default/view/dashboard.skin
grep -q '<s-l3.not-found-page />' templates/default/view/not_found.skin
grep -q "{{ user_email }}" templates/default/ui_components/l3/dashboard_page.scales
grep -q '<s-l2.auth-form :auth-title="auth_title" :auth-action="auth_action" :email-value="email_value" :password-autocomplete="password_autocomplete" :submit-label="submit_label" :error="error" :auth-footer="auth_footer" />' templates/default/ui_components/l3/login_page.scales
grep -q '<s-l2.auth-form :auth-title="auth_title" :auth-action="auth_action" :email-value="email_value" :password-autocomplete="password_autocomplete" :submit-label="submit_label" :error="error" :auth-footer="auth_footer" />' templates/default/ui_components/l3/register_page.scales
! grep -R "{% component" templates/default/view templates/default/ui_components README.md docs >/dev/null
grep -q "render_template_text" templates/default/src/main.c
grep -q "respond_view" templates/default/src/main.c
grep -q "view/%s.skin" templates/default/src/main.c
grep -q "view/layout.skin" templates/default/src/main.c
! grep -q "view/%s.html" templates/default/src/main.c
grep -q "ui_components/%s.scales" templates/default/src/main.c
! grep -q "<style>" templates/default/src/main.c
! grep -R "<style>" templates/default/view >/dev/null
! find templates/default/view -name '*.html' -print -quit | grep -q .
! find templates/default/ui_components -name '*.html' -print -quit | grep -q .
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
