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
  "templates/default/frontend/Dockerfile"
  "templates/default/frontend/index.html"
  "templates/default/frontend/package.json"
  "templates/default/frontend/package-lock.json"
  "templates/default/frontend/vite.config.js"
  "templates/default/frontend/src/main.jsx"
  "templates/default/frontend/src/styles.css"
  "templates/default/sealion.toml"
  "templates/default/src/app.h"
  "templates/default/src/main.c"
  "templates/default/model/user.c"
  "templates/default/model/session.c"
  "templates/default/controller/auth_controller.c"
  "templates/default/controller/page_controller.c"
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
  "templates/default/frontend"
  "templates/default/frontend/src"
  "templates/default/src"
  "templates/default/model"
  "templates/default/controller"
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

grep -q "React frontend container" README.md
grep -q "Postgres-only" README.md
grep -q "Separate runtime boundaries" README.md
grep -q "Infrastructure as code" README.md
grep -q "generated Docker Compose setup" README.md
grep -q "Postgres-backed queues" README.md
grep -q "sealion new" README.md
grep -q "sealion format" README.md
grep -q "sealion run dev" README.md
grep -q "command_format" bin/sealion
grep -q "default_port = 8080" templates/default/sealion.toml
! grep -q 'url = "http://localhost:8080"' templates/default/sealion.toml
grep -q "frontend:" templates/default/docker-compose.yml
grep -q "backend:" templates/default/docker-compose.yml
grep -q "db:" templates/default/docker-compose.yml
grep -q 'PUBLIC_URL: "http://localhost:${SEALION_HTTP_PORT:-8080}"' templates/default/docker-compose.yml
grep -q "develop:" templates/default/docker-compose.yml
grep -q "watch:" templates/default/docker-compose.yml
grep -q "action: rebuild" templates/default/docker-compose.yml
grep -q "path: ./frontend/src" templates/default/docker-compose.yml
grep -q "path: ./frontend/package.json" templates/default/docker-compose.yml
grep -q "path: ./src" templates/default/docker-compose.yml
grep -q "path: ./model" templates/default/docker-compose.yml
grep -q "path: ./controller" templates/default/docker-compose.yml
grep -q "path: ./Dockerfile" templates/default/docker-compose.yml
grep -q "COPY model ./model" templates/default/Dockerfile
grep -q "COPY controller ./controller" templates/default/Dockerfile
! grep -q "COPY view ./view" templates/default/Dockerfile
! grep -q "COPY ui_components ./ui_components" templates/default/Dockerfile
grep -q "npm ci" templates/default/frontend/Dockerfile
grep -q "@vitejs/plugin-react" templates/default/frontend/package.json
grep -q '"react": "19.2.7"' templates/default/frontend/package.json
grep -q "target: 'http://backend:8080'" templates/default/frontend/vite.config.js
grep -q '/api/${mode}' templates/default/frontend/src/main.jsx
grep -q "React frontend + C API + Postgres" templates/default/frontend/src/main.jsx
grep -q "respond_json" templates/default/src/main.c
grep -q "/api/login" templates/default/src/main.c
grep -q "/api/me" templates/default/src/main.c
grep -q "handle_api_dashboard" templates/default/src/main.c
! grep -q "render_template_text" templates/default/src/main.c
! grep -q "respond_view" templates/default/src/main.c
! grep -q "<style>" templates/default/src/main.c
! find templates/default -path '*/view/*' -print -quit | grep -q .
! find templates/default -path '*/ui_components/*' -print -quit | grep -q .
! grep -R "views/" templates/default README.md docs >/dev/null
grep -q "API listening inside backend container" templates/default/src/main.c
grep -q "frontend proxies API calls" templates/default/src/main.c
grep -q "compose_supports_watch" bin/sealion
grep -q -- "--watch" bin/sealion

grep -q "$domain" docs/site/index.html
grep -q "React frontend" docs/site/index.html
grep -q "Initial user experience" docs/site/index.html
grep -q "React frontend, C API backend, Postgres database" docs/site/component-style-system.html
grep -q "Install, create, run, log in" docs/site/initial-user-experience.html
grep -q "CI/CD regression plan" docs/site/ci-cd-regression-tests.html
grep -q "Directory structure" docs/site/repo-structure.html

printf 'repo contract ok\n'
