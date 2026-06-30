# CI/CD Regression Test Plan

Sealion's test strategy starts with repository contracts and grows toward full
C runtime, Postgres, container, and infrastructure regression coverage.

## Required Gates

### Pull Request Gate

Runs on every pull request:

- repository contract checks;
- shell syntax checks for repo-owned scripts;
- documentation site contract checks;
- generated Docker stack smoke test with Postgres-backed JSON login;
- future C format, compile, unit, sanitizer, and integration checks.

### Main Branch Gate

Runs after every push to `main`:

- the pull request gate;
- documentation deployment to GitHub Pages;
- future release candidate smoke checks.

### Release Gate

Runs before a tagged framework release:

- full compile matrix;
- sanitizer matrix;
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
- README keeps the core product contracts: React frontend container, C backend
  container, Postgres-only database, infrastructure as code, local Compose
  first, and Postgres-backed queues;
- install script, CLI, and default template files exist;
- documentation site files exist;
- custom Pages domain is present in `docs/site/CNAME`;
- workflow files exist.

### C Compile And ABI

Purpose: catch broken public headers, incompatible symbols, and build drift.

Future checks:

- compile `src/` with strict warnings;
- compile public examples against installed headers;
- verify exported symbols for public framework APIs;
- fail on accidental ABI changes outside release workflows.

### Unit Tests

Purpose: keep core C behavior deterministic.

Future checks:

- router matching;
- request parsing;
- response generation;
- middleware ordering;
- memory ownership helpers;
- configuration parsing;
- logging shape.

### Sanitizer Tests

Purpose: make C memory failures visible early.

Future checks:

- AddressSanitizer build;
- UndefinedBehaviorSanitizer build;
- leak detection for request lifecycle tests;
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
- frontend, backend, and Postgres run as separate services;
- health checks converge;
- generated backend logs the external frontend URL used for API proxying;
- demo login through `/api/login` sets a cookie and returns JSON;
- generated Compose config declares file-watch rebuilds for frontend source,
  frontend package/config files, backend source, model, controller, and
  Dockerfile changes;
- generated apps include a React frontend container, C backend/API container,
  and Postgres database container;
- frontend proxies `/api` and `/health` to the backend;
- `/api/me` reports anonymous and authenticated state correctly;
- `/dashboard` is served by the React app shell;
- `sealion format` rewrites compact passover arrays and is idempotent when
  optional `.skin` or `.scale` files exist;
- restart behavior preserves Postgres data;
- environment schema rejects missing required values.

### CLI Golden Tests

Purpose: protect developer experience and generated files.

Future checks:

- `sealion new` creates the canonical directory structure;
- `sealion init` succeeds only in an empty directory;
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

### Optional Server-Rendered UI Regression

Purpose: preserve the earlier `.skin` and `.scale` work if Sealion later adds
an optional server-rendered UI mode.

Future checks:

- `.skin` and `.scale` files format idempotently;
- component calls obey their documented hierarchy;
- unknown template directives fail with actionable errors;
- server-rendered examples compile without becoming the default starter path.

## Current Implemented Checks

The first implemented CI job is intentionally small:

```sh
bash -n scripts/*.sh bin/sealion install.sh
bash scripts/check_repo_contract.sh
bash scripts/test_cli_scaffold.sh
bash scripts/test_starter_docker_flow.sh
```

This protects the repo, generated starter, Docker dev topology, and
documentation deployment while the framework code is still being designed.
