# CI/CD Regression Test Plan

Carbide's test strategy starts with repository contracts and grows toward full
Go backend, Postgres, container, and infrastructure regression coverage.

## Required Gates

### Pull Request Gate

Runs on every pull request:

- repository contract checks;
- Go CLI unit tests;
- shell syntax checks for repo-owned scripts;
- documentation site contract checks;
- generated Docker stack smoke test with registration-first, Postgres-backed
  JSON auth;
- future backend unit, integration, and compatibility checks.

### Main Branch Gate

Runs after every push to `main`:

- the pull request gate;
- documentation deployment to GitHub Pages;
- future release candidate smoke checks.

### Release Gate

Runs before a tagged framework release:

- supported Go version matrix;
- race and compatibility matrix;
- Postgres integration matrix;
- generated project smoke tests;
- migration up/down tests;
- container build and boot tests;
- documentation deploy preview or published docs verification.

## Regression Suites

### Repository Contract

Purpose: make the repo shape itself hard to accidentally break.

Initial checks:

- required directories exist;
- README keeps the core product contracts: Bun/React/Tailwind frontend
  container, Go backend container, Postgres-only database, infrastructure as
  code, local Compose first, and Postgres-backed queues;
- install script, CLI, and default template files exist;
- the Go CLI builds and its deterministic helpers and output renderer pass unit
  tests;
- documentation site files exist;
- custom Pages domain is present in `docs/site/CNAME`;
- workflow files exist.

### Backend Build And API

Purpose: catch broken backend builds, incompatible API behavior, and build
drift.

Future checks:

- build generated backend code with the pinned Go version;
- run backend unit tests with strict failure behavior;
- verify public API routes, cookies, and JSON response shapes;
- fail on accidental generated API contract changes outside release workflows.

### Unit Tests

Purpose: keep core backend behavior deterministic.

Future checks:

- router matching;
- request parsing;
- response generation;
- middleware ordering;
- configuration parsing;
- logging shape.

### Compatibility And Race Tests

Purpose: make concurrency and generated app compatibility failures visible
early.

Future checks:

- Go race detector for backend packages that can run without containers;
- generated app compatibility tests across supported Go versions;
- request lifecycle tests under concurrent auth and session traffic;
- failure artifacts for reproducible debugging.

### Postgres Integration

Purpose: enforce the mandatory database contract.

Future checks:

- backend connects only after Postgres readiness;
- connection pool opens and closes cleanly;
- migrations run up and down;
- query builder always parameterizes inputs;
- transactions roll back on handler failure;
- generated apps can reset test database state.

### Container And IaC

Purpose: keep local development close to production failure shapes.

Future checks:

- generated Compose file validates;
- frontend and backend containers build from a clean checkout;
- frontend installs with Bun from `bun.lock`;
- Tailwind is a required generated frontend dependency and build step;
- frontend, backend, and Postgres run as separate services;
- health checks converge;
- generated backend logs the external frontend URL used for API proxying;
- login fails before the first user is registered;
- registration through `/api/register` creates the first user, sets a cookie,
  and returns JSON;
- login through `/api/login` works after registration;
- generated Compose config declares file-watch rebuilds for `view/web` source,
  view web package/config files, backend source, model, controller, and
  Dockerfile changes;
- generated apps include a Bun/React/Tailwind frontend container, Go
  backend/API container, and Postgres database container;
- Bun frontend proxies `/api` and `/health` to the backend;
- `/api/me` reports anonymous and authenticated state correctly;
- `/dashboard` is served by the React app shell;
- restart behavior preserves Postgres data;
- environment schema rejects missing required values.

### CLI Golden Tests

Purpose: protect developer experience and generated files.

Future checks:

- `carbide new` creates the canonical directory structure;
- `carbide init` succeeds only in an empty directory;
- `carbide run dev` prints a compact startup summary and suppresses noisy
  Compose build output by default;
- `carbide run dev` prints only the working app/API URLs before the log stream,
  with no port-busy, demo-login, mode, status, stop, or watch-summary rows;
- `carbide run dev` shows full-width TTY-only per-container startup animation while
  Compose starts containers, without leaking progress control text into
  captured output, and without treating `NO_COLOR` as a request to disable
  terminal animation;
- `Ctrl+C` during `carbide run dev` detaches from live logs without running
  `docker compose down`;
- `carbide stop dev` is the explicit teardown path, runs `docker compose down`,
  and shows full-width TTY-only per-container shutdown animation;
- CLI success, error, version, upgrade, and dev-stack output use the shared
  aligned renderer instead of scattered raw prints;
- `carbide run dev` streams frontend, backend, database, and watch output
  through timestamped service-tagged rows after the stack is ready;
- `carbide status` prints a stable table of services, container names,
  published host ports, internal container ports, and status;
- `carbide follow logs` reattaches to live container logs and preserves
  timestamped, service-tagged rendering;
- `carbide run dev` writes `.carbide/log/dev.jsonl`, and `carbide logs` can
  query it by service, text, limit, and JSON output;
- generated apps contain no seeded demo account or demo credentials;
- generated files are deterministic;
- invalid commands print actionable errors;
- scaffolded apps pass the same CI checks as framework examples.

### Security Regression

Purpose: keep safe defaults from silently weakening.

Future checks:

- signed cookie tamper tests;
- CSRF token validation;
- secure cookie flags in production mode;
- upload size and type limits;
- SQL parameterization tests;
- secret values never printed in logs.

### Documentation Regression

Purpose: make the documentation site track framework behavior.

Initial checks:

- static docs site exists;
- custom domain is present;
- engineering plans are checked in.

Future checks:

- docs examples compile;
- generated command snippets are paste-ready;
- links resolve inside the docs site;
- release docs are versioned.

## Current Implemented Checks

The first implemented CI job is intentionally small:

```sh
bash -n scripts/*.sh bin/carbide bin/sealion install.sh
go test ./...
bash scripts/check_repo_contract.sh
bash scripts/test_cli_scaffold.sh
bash scripts/test_starter_docker_flow.sh
```

This protects the repo, generated starter, Docker dev topology, and
documentation deployment while the framework code is still being designed.
