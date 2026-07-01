#!/usr/bin/env bash
set -euo pipefail

domain="carbide.ryangerardwilson.com"

required_files=(
  ".gitignore"
  "README.md"
  "install.sh"
  "go.mod"
  "bin/carbide"
  "bin/sealion"
  "cmd/carbide/main.go"
  "cmd/sealion/main.go"
  "internal/carbide/cli.go"
  "internal/carbide/cli_test.go"
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
  "templates/default/.gitignore"
  "templates/default/docker-compose.yml"
  "templates/default/view/web/Dockerfile"
  "templates/default/view/web/index.html"
  "templates/default/view/web/package.json"
  "templates/default/view/web/bun.lock"
  "templates/default/view/web/src/main.jsx"
  "templates/default/view/web/src/server.jsx"
  "templates/default/view/web/src/styles.css"
  "templates/default/carbide.toml"
  "templates/default/go.mod"
  "templates/default/go.sum"
  "templates/default/src/main.go"
  "templates/default/model/user.go"
  "templates/default/model/session.go"
  "templates/default/controller/auth_controller.go"
  "templates/default/controller/page_controller.go"
  "templates/default/migrations/001_auth.sql"
)

required_dirs=(
  "cmd"
  "cmd/carbide"
  "cmd/sealion"
  "internal/carbide"
  "src"
  "src/ui"
  "include/carbide"
  "include/carbide/ui"
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
grep -q "carbide new" README.md
grep -q "carbide run dev" README.md
grep -q "carbide status" README.md
grep -q "carbide stop dev" README.md
grep -q "carbide follow logs" README.md
grep -q "carbide logs" README.md
! grep -q "command_format" bin/carbide
! grep -q "carbide format" bin/carbide
grep -q "module github.com/ryangerardwilson/carbide" go.mod
grep -q "package main" cmd/carbide/main.go
grep -q "package main" cmd/sealion/main.go
grep -q "package carbide" internal/carbide/cli.go
grep -q "composeUpDetached" internal/carbide/cli.go
grep -q "runDevStreams" internal/carbide/cli.go
grep -q -- "--quiet-build" internal/carbide/cli.go
grep -q "Carbide dev" internal/carbide/cli.go
grep -q "Go is required to build the Carbide CLI" install.sh
grep -q ".bin/carbide" install.sh
grep -q "default_port = 8080" templates/default/carbide.toml
grep -q ".carbide/" templates/default/.gitignore
! grep -q 'url = "http://localhost:8080"' templates/default/carbide.toml
grep -q "frontend:" templates/default/docker-compose.yml
grep -q "backend:" templates/default/docker-compose.yml
grep -q "db:" templates/default/docker-compose.yml
grep -q 'PUBLIC_URL: "http://localhost:${CARBIDE_HTTP_PORT:-8080}"' templates/default/docker-compose.yml
test "$(grep -c 'PUBLIC_URL: "http://localhost:${CARBIDE_HTTP_PORT:-8080}"' templates/default/docker-compose.yml)" -eq 2
grep -q "develop:" templates/default/docker-compose.yml
grep -q "watch:" templates/default/docker-compose.yml
grep -q "action: rebuild" templates/default/docker-compose.yml
grep -q "context: ./view/web" templates/default/docker-compose.yml
grep -q "path: ./view/web/src" templates/default/docker-compose.yml
grep -q "path: ./view/web/package.json" templates/default/docker-compose.yml
grep -q "path: ./view/web/bun.lock" templates/default/docker-compose.yml
grep -q "path: ./go.mod" templates/default/docker-compose.yml
grep -q "path: ./go.sum" templates/default/docker-compose.yml
grep -q "path: ./src" templates/default/docker-compose.yml
grep -q "path: ./model" templates/default/docker-compose.yml
grep -q "path: ./controller" templates/default/docker-compose.yml
grep -q "path: ./Dockerfile" templates/default/docker-compose.yml
grep -q "FROM golang:" templates/default/Dockerfile
grep -q "go mod download" templates/default/Dockerfile
grep -q "go build" templates/default/Dockerfile
grep -q "COPY model ./model" templates/default/Dockerfile
grep -q "COPY controller ./controller" templates/default/Dockerfile
! grep -q "COPY view ./view" templates/default/Dockerfile
! grep -q "COPY ui_components ./ui_components" templates/default/Dockerfile
! grep -q "gcc" templates/default/Dockerfile
! grep -q "libpq-dev" templates/default/Dockerfile
! test -d templates/default/frontend
! test -f templates/default/view/web/package-lock.json
! test -f templates/default/view/web/vite.config.js
grep -q "oven/bun:1.3.14-debian" templates/default/view/web/Dockerfile
grep -q "bun install --frozen-lockfile" templates/default/view/web/Dockerfile
grep -q '"@tailwindcss/cli": "4.3.2"' templates/default/view/web/package.json
grep -q '"tailwindcss": "4.3.2"' templates/default/view/web/package.json
grep -q '"react": "19.2.7"' templates/default/view/web/package.json
grep -q "Bun.serve" templates/default/view/web/src/server.jsx
grep -q "browser entrypoint" templates/default/view/web/src/server.jsx
grep -q "listening inside container" templates/default/view/web/src/server.jsx
grep -q "proxying /api and /health to backend service" templates/default/view/web/src/server.jsx
! grep -q "Bun frontend listening on http://localhost" templates/default/view/web/src/server.jsx
grep -q '@import "tailwindcss";' templates/default/view/web/src/styles.css
grep -q '/api/${mode}' templates/default/view/web/src/main.jsx
grep -q "Bun frontend + Go API + Postgres" templates/default/view/web/src/main.jsx
grep -q "React + Bun container" templates/default/view/web/src/main.jsx
grep -q "github.com/jackc/pgx/v5" templates/default/go.mod
grep -q "package main" templates/default/src/main.go
grep -q "/api/login" templates/default/controller/page_controller.go
grep -q "/api/me" templates/default/controller/page_controller.go
grep -q "handleDashboard" templates/default/controller/page_controller.go
grep -q "CreateUser" templates/default/model/user.go
grep -q "CreateSession" templates/default/model/session.go
! grep -R "admin@carbide.local" templates/default README.md docs >/dev/null
! grep -R "Demo login" templates/default README.md docs >/dev/null
! find templates/default -name '*.c' -o -name '*.h' | grep -q .
! grep -R "seed_admin" templates/default >/dev/null
! grep -R "render_template_text" templates/default >/dev/null
! grep -R "respond_view" templates/default >/dev/null
! find templates/default -path '*/ui_components/*' -print -quit | grep -q .
! grep -R "views/" templates/default README.md docs >/dev/null
grep -q "backend listening on container port" templates/default/src/main.go
grep -q "public API URL is" templates/default/src/main.go
! grep -q "API listening inside backend container" templates/default/src/main.go
! grep -q "frontend proxies API calls" templates/default/src/main.go
grep -q "compose.supports(\"--watch\")" internal/carbide/cli.go
grep -q "newRenderer" internal/carbide/cli.go
grep -q "func (r renderer) Table" internal/carbide/cli.go
grep -q "runDevStreams" internal/carbide/cli.go
grep -q "commandStatus" internal/carbide/cli.go
grep -q "commandStopDev" internal/carbide/cli.go
grep -q "RunServiceProgress" internal/carbide/cli.go
grep -q "RunServiceStopProgress" internal/carbide/cli.go
grep -q "serviceProgressFrameWidth" internal/carbide/cli.go
grep -q "serviceProgressFrame" internal/carbide/cli.go
grep -q "terminalColumns" internal/carbide/cli.go
grep -q "composeServiceStatuses" internal/carbide/cli.go
grep -q "composeServiceSnapshots" internal/carbide/cli.go
grep -q "composePublishedPorts" internal/carbide/cli.go
grep -q "composeInternalPorts" internal/carbide/cli.go
grep -q "streamLogOutput" internal/carbide/cli.go
grep -q "parseComposeLogLine" internal/carbide/cli.go
grep -q "composeLogsArgs" internal/carbide/cli.go
grep -q "openDevLogSink" internal/carbide/cli.go
grep -q "openAppendDevLogSink" internal/carbide/cli.go
grep -q "commandLogs" internal/carbide/cli.go
grep -q "commandFollowLogs" internal/carbide/cli.go
grep -q ".carbide/log/dev.jsonl" internal/carbide/cli.go
grep -q "carbide follow logs" internal/carbide/cli.go
grep -q "carbide status" internal/carbide/cli.go
! grep -q "carbide logs follow" internal/carbide/cli.go
! grep -q 'outputRow{"login"' internal/carbide/cli.go
! grep -q 'outputRow{"mode"' internal/carbide/cli.go

grep -q "$domain" docs/site/index.html
grep -q "Bun frontend" docs/site/index.html
grep -q "Initial user experience" docs/site/index.html
grep -q "Bun frontend, Go API backend, Postgres database" docs/site/component-style-system.html
grep -q "Tailwind is required" docs/site/component-style-system.html
grep -q "carbide follow logs" docs/site/initial-user-experience.html
grep -q "carbide status" docs/site/initial-user-experience.html
grep -q "Install, create, run, register" docs/site/initial-user-experience.html
grep -q "CI/CD regression plan" docs/site/ci-cd-regression-tests.html
grep -q "Directory structure" docs/site/repo-structure.html

printf 'repo contract ok\n'
