# Directory Structure

Carbide uses a narrow structure at the start so future framework code,
generated apps, infrastructure, tests, and documentation have clear ownership.

```text
.
|-- .github/
|   `-- workflows/
|       |-- ci.yml
|       `-- pages.yml
|-- bin/
|   `-- carbide
|-- cmd/
|   `-- carbide/
|       `-- main.go
|-- internal/
|   `-- carbide/
|       |-- cli.go
|       `-- cli_test.go
|-- docs/
|   |-- engineering/
|   |   |-- COMPONENT_STYLE_SYSTEM.md
|   |   |-- CI_CD_REGRESSION_TESTS.md
|   |   |-- DIRECTORY_STRUCTURE.md
|   |   `-- INITIAL_USER_EXPERIENCE.md
|   `-- site/
|       |-- CNAME
|       |-- assets/
|       |   `-- styles.css
|       |-- ci-cd-regression-tests.html
|       |-- component-style-system.html
|       |-- index.html
|       |-- initial-user-experience.html
|       `-- repo-structure.html
|-- examples/
|   `-- hello/
|-- include/
|   `-- carbide/
|       `-- ui/
|-- infra/
|   |-- compose/
|   `-- schemas/
|-- scripts/
|   |-- check_repo_contract.sh
|   `-- test_cli_scaffold.sh
|-- src/
|   `-- ui/
|-- templates/
|   `-- default/
|       |-- Dockerfile
|       |-- docker-compose.yml
|       |-- go.mod
|       |-- go.sum
|       |-- controller/
|       |   |-- auth_controller.go
|       |   `-- page_controller.go
|       |-- migrations/
|       |   `-- 001_auth.sql
|       |-- model/
|       |   |-- session.go
|       |   `-- user.go
|       |-- carbide.toml
|       |-- src/
|       |   `-- main.go
|       `-- view/
|           `-- web/
|               |-- Dockerfile
|               |-- bun.lock
|               |-- index.html
|               |-- package.json
|               `-- src/
|                   |-- main.jsx
|                   |-- server.jsx
|                   `-- styles.css
|-- tests/
|   |-- fixtures/
|   |-- integration/
|   |-- regression/
|   `-- unit/
|-- go.mod
|-- install.sh
`-- README.md
```

## Ownership

- `.github/workflows/`: CI and documentation deployment.
- `bin/carbide`: source checkout launcher for the Go CLI.
- `cmd/carbide/`: installable CLI entrypoint.
- `internal/carbide/`: Go implementation of the CLI and its unit tests.
- `docs/engineering/`: source-of-truth engineering plans.
- `docs/site/`: static GitHub Pages artifact.
- `examples/`: generated or hand-written sample apps.
- `include/carbide/`: reserved public framework API surface.
- `include/carbide/ui/`: reserved public frontend helper API surface.
- `infra/compose/`: local Compose templates and generated examples.
- `infra/schemas/`: schemas for infrastructure, environment, and app metadata.
- `scripts/`: repo-owned checks and maintenance commands.
- `src/`: framework implementation.
- `src/ui/`: component rendering, utility parsing, token resolution, and CSS
  generation.
- `templates/default/`: generated starter app used by `carbide new` and
  `carbide init`.
- `templates/default/model/`: generated Postgres-backed model code.
- `templates/default/controller/`: generated request-flow handlers.
- `templates/default/src/`: generated Go HTTP/API server.
- `templates/default/view/web/`: generated Bun/React/Tailwind web app,
  frontend container source, browser UI, and same-origin API proxy.
- `tests/fixtures/`: shared test fixtures.
- `tests/integration/`: tests that use Postgres or containers.
- `tests/regression/`: tests created after a bug or broken contract.
- `tests/unit/`: small deterministic unit tests.
- `go.mod`: Go module definition for the CLI.
- `install.sh`: GitHub URL installer that builds the Go CLI and places
  `carbide` on the user's PATH.

## First Implementation Rule

Empty directories are placeholders until a real file belongs there. When a
directory gains behavior, its first file should make that behavior testable.
