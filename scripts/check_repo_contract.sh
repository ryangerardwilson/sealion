#!/usr/bin/env bash
set -euo pipefail

domain="sealion.ryangerardwilson.com"

required_files=(
  ".gitignore"
  "README.md"
  "install.sh"
  "go.mod"
  "bin/sealion"
  "cmd/sealion/main.go"
  "cmd/sealion/main_test.go"
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
  "templates/default/view/web/Dockerfile"
  "templates/default/view/web/index.html"
  "templates/default/view/web/package.json"
  "templates/default/view/web/bun.lock"
  "templates/default/view/web/src/main.jsx"
  "templates/default/view/web/src/server.jsx"
  "templates/default/view/web/src/styles.css"
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
  "cmd"
  "cmd/sealion"
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
  "templates/default/view"
  "templates/default/view/web"
  "templates/default/view/web/src"
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

grep -q "Bun/React/Tailwind frontend container" README.md
grep -q "Postgres-only" README.md
grep -q "Separate runtime boundaries" README.md
grep -q "Infrastructure as code" README.md
grep -q "generated Docker Compose setup" README.md
grep -q "Postgres-backed queues" README.md
grep -q "sealion new" README.md
grep -q "sealion run dev" README.md
! grep -q "command_format" bin/sealion
! grep -q "sealion format" bin/sealion
grep -q "module github.com/ryangerardwilson/sealion" go.mod
grep -q "package main" cmd/sealion/main.go
grep -q "composeUpDetached" cmd/sealion/main.go
grep -q "runComposeWatch" cmd/sealion/main.go
grep -q -- "--quiet-build" cmd/sealion/main.go
grep -q "Sealion dev" cmd/sealion/main.go
grep -q "Go is required to build the Sealion CLI" install.sh
grep -q ".bin/sealion" install.sh
grep -q "default_port = 8080" templates/default/sealion.toml
! grep -q 'url = "http://localhost:8080"' templates/default/sealion.toml
grep -q "frontend:" templates/default/docker-compose.yml
grep -q "backend:" templates/default/docker-compose.yml
grep -q "db:" templates/default/docker-compose.yml
grep -q 'PUBLIC_URL: "http://localhost:${SEALION_HTTP_PORT:-8080}"' templates/default/docker-compose.yml
grep -q "develop:" templates/default/docker-compose.yml
grep -q "watch:" templates/default/docker-compose.yml
grep -q "action: rebuild" templates/default/docker-compose.yml
grep -q "context: ./view/web" templates/default/docker-compose.yml
grep -q "path: ./view/web/src" templates/default/docker-compose.yml
grep -q "path: ./view/web/package.json" templates/default/docker-compose.yml
grep -q "path: ./view/web/bun.lock" templates/default/docker-compose.yml
grep -q "path: ./src" templates/default/docker-compose.yml
grep -q "path: ./model" templates/default/docker-compose.yml
grep -q "path: ./controller" templates/default/docker-compose.yml
grep -q "path: ./Dockerfile" templates/default/docker-compose.yml
grep -q "COPY model ./model" templates/default/Dockerfile
grep -q "COPY controller ./controller" templates/default/Dockerfile
! grep -q "COPY view ./view" templates/default/Dockerfile
! grep -q "COPY ui_components ./ui_components" templates/default/Dockerfile
! test -d templates/default/frontend
! test -f templates/default/view/web/package-lock.json
! test -f templates/default/view/web/vite.config.js
grep -q "oven/bun:1.3.14-debian" templates/default/view/web/Dockerfile
grep -q "bun install --frozen-lockfile" templates/default/view/web/Dockerfile
grep -q '"@tailwindcss/cli": "4.3.2"' templates/default/view/web/package.json
grep -q '"tailwindcss": "4.3.2"' templates/default/view/web/package.json
grep -q '"react": "19.2.7"' templates/default/view/web/package.json
grep -q "Bun.serve" templates/default/view/web/src/server.jsx
grep -q "proxying /api and /health" templates/default/view/web/src/server.jsx
grep -q '@import "tailwindcss";' templates/default/view/web/src/styles.css
grep -q '/api/${mode}' templates/default/view/web/src/main.jsx
grep -q "Bun frontend + C API + Postgres" templates/default/view/web/src/main.jsx
grep -q "React + Bun container" templates/default/view/web/src/main.jsx
grep -q "respond_json" templates/default/src/main.c
grep -q "/api/login" templates/default/src/main.c
grep -q "/api/me" templates/default/src/main.c
grep -q "handle_api_dashboard" templates/default/src/main.c
! grep -q "render_template_text" templates/default/src/main.c
! grep -q "respond_view" templates/default/src/main.c
! grep -q "<style>" templates/default/src/main.c
! find templates/default -path '*/ui_components/*' -print -quit | grep -q .
! grep -R "views/" templates/default README.md docs >/dev/null
grep -q "API listening inside backend container" templates/default/src/main.c
grep -q "frontend proxies API calls" templates/default/src/main.c
grep -q "compose.supports(\"--watch\")" cmd/sealion/main.go
grep -q "newRenderer" cmd/sealion/main.go
grep -q "streamComposeOutput" cmd/sealion/main.go
grep -q 'outputRow{"watch", "enabled"}' cmd/sealion/main.go

grep -q "$domain" docs/site/index.html
grep -q "Bun frontend" docs/site/index.html
grep -q "Initial user experience" docs/site/index.html
grep -q "Bun frontend, C API backend, Postgres database" docs/site/component-style-system.html
grep -q "Tailwind is required" docs/site/component-style-system.html
grep -q "Install, create, run, log in" docs/site/initial-user-experience.html
grep -q "CI/CD regression plan" docs/site/ci-cd-regression-tests.html
grep -q "Directory structure" docs/site/repo-structure.html

printf 'repo contract ok\n'
