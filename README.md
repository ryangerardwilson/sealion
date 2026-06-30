# Sealion

Sealion is an experimental, Laravel-inspired full-stack framework with a React
frontend container, a C backend container, and a mandatory Postgres database.

The goal is not to copy Laravel line by line. The goal is to find the smallest
set of conventions, tools, and runtime guarantees that make building web apps in
C feel coherent, productive, and safe enough to be practical.

## Product Bet

C is a difficult language for high-level web application development, and
rebuilding the whole browser UI stack in C is not the best first product bet.
Sealion now keeps C where it is strongest and uses React for the default
frontend:

- one Bun/React/Tailwind frontend container
- one C backend/API container
- one mandatory Postgres service container
- one project layout
- one API request lifecycle
- one database migration path
- one checked-in infrastructure contract
- one Go CLI entry point
- one opinionated set of security defaults

Sealion should make the hard parts visible instead of hiding them behind magic.

## Core Principles

- **Container-first:** every app runs through generated containers, not host
  Bun, host compiler setup, or hidden local services.
- **Go CLI:** `sealion` is a compiled Go CLI. It owns scaffolding, upgrades,
  local port selection, and the Docker Compose development lifecycle.
- **React default frontend:** the browser UI lives in the frontend container.
  Bun, React, and Tailwind are required inside that container, not on the
  developer's host machine.
- **C backend:** auth, sessions, validation, API routes, and business logic
  live in the backend container.
- **Postgres-only:** Sealion targets Postgres as the mandatory database, not as
  one interchangeable adapter among many.
- **Separate runtime boundaries:** frontend, backend, and database containers
  are separate services with separate lifecycles, health checks, logs, and
  storage.
- **Infrastructure as code:** every supported runtime dependency, service
  boundary, volume, network, secret contract, environment variable, health
  check, and deploy target must be described in checked-in code.
- **Explicit ownership:** request memory, response memory, and database handles
  must have clear lifetimes.
- **Convention over configuration:** defaults should cover normal apps without
  requiring boilerplate.
- **Safe by default:** routing, sessions, cookies, CSRF, validation, SQL access,
  and uploads should have conservative defaults.
- **Inspectable runtime:** generated files, migrations, logs, and app state
  should be easy to inspect and reproduce.
- **Small ecosystem surface:** add extension points only after the core app loop
  is stable.

## Non-Goals

- Native host installs before the container contract is stable.
- Full Laravel API compatibility.
- Requiring host-installed Bun, Node, or npm.
- Rebuilding React, Bun, Tailwind, or Blade from scratch.
- A general-purpose C package manager.
- ORM magic that depends on runtime reflection C does not have.
- Supporting multiple databases, web servers, or deployment targets in the
  first versions.

## Runtime Topology

The default Sealion app runs as three containers:

1. the frontend container, which owns Bun, React, Tailwind, browser routing,
   the API proxy, and the public host port;
2. the backend container, which owns C API routes, auth, sessions, application
   code, migrations, logs, and framework tooling;
3. the Postgres database container, which owns durable relational state through
   a mounted volume or managed persistent storage.

The browser talks to the frontend on one origin. The frontend proxies `/api` and
`/health` to the backend over the private Compose network, which keeps cookies
same-origin and avoids CORS as the default development problem. The backend
depends on Postgres readiness, but each service remains independently
restartable, inspectable, and replaceable.

## Infrastructure As Code Contract

Sealion apps must be reproducible from the repository. Runtime behavior should
not depend on manual console setup, undocumented shell history, or hidden
machine state.

The first supported infrastructure target is a generated Docker Compose setup
for local development. Production targets come later, one at a time, after the
local app and Postgres contract is stable.

At minimum, each app must keep these contracts in version control:

- container definitions for the frontend, backend, database, and required
  services;
- service networking, health checks, restart policy, and readiness rules;
- Postgres image version, volume, backup, restore, and migration policy;
- environment variable schema with required, optional, and secret values;
- generated local Compose manifests first, then deployment manifests for each
  supported production target as those targets become official;
- framework and app version gates for infrastructure changes.

The Sealion CLI should generate and validate these files instead of asking
developers to maintain ad hoc infrastructure by hand. Infrastructure is part of
the application source, and changes to it must be reviewable, diffable, and
recoverable.

## Documentation And Automation

The public documentation site is published from `docs/site` to GitHub Pages at:

```text
https://sealion.ryangerardwilson.com
```

CI starts with repository contract checks and grows into the full framework
regression suite described in `docs/engineering/CI_CD_REGRESSION_TESTS.md`.
The planned repo layout lives in `docs/engineering/DIRECTORY_STRUCTURE.md`.
The frontend contract lives in `docs/engineering/COMPONENT_STYLE_SYSTEM.md`.

## Install And Start

```sh
curl -fsSL https://raw.githubusercontent.com/ryangerardwilson/sealion/main/install.sh | bash
sealion new demo
cd demo
sealion run dev
```

The installer currently builds the `sealion` CLI with Go, so Go must be
available on the host machine. Generated apps still run Bun, C compilation, and
Postgres inside containers.

`sealion new <project-name>` creates a new project directory. `sealion init`
initializes the current directory only when it is empty. `sealion run dev`
starts the generated frontend, backend, and Postgres containers with register,
login, logout, and dashboard already wired. It prefers
`http://localhost:8080`, but automatically selects another local port when 8080
is already in use. Set `SEALION_HTTP_PORT=<port>` to choose the host port
explicitly.

`sealion help` prints the command reference. `sealion upgrade` upgrades the
installed CLI when a newer GitHub commit is available.

When Docker Compose supports file watch, `sealion run dev` starts the stack with
quiet Compose output and watch enabled. Edits under `view/web/src/`, `src/`,
`model/`, `controller/`, view package/config files, or `Dockerfile` rebuild and
replace the relevant container. Use `docker compose logs -f` when you want raw
container logs.

Generated apps use an MVC shape. `view/web/` owns the Bun server, Tailwind
build, browser UI, and same-origin `/api` calls. `model/` owns
Postgres state, `controller/` owns request flow and JSON responses, and `src/`
owns the C HTTP/API server.

## Roadmap

### Phase 0: Project Contract

- Define the official container image and supported Linux base.
- Define the official Postgres image, version policy, storage contract, and
  connection environment variables.
- Define the default three-container Compose topology for local development.
- Define the mandatory infrastructure-as-code file layout and validation rules.
- Choose compiler, libc, build system, and test runner.
- Create the canonical app directory layout.
- Define the request, response, app, and service lifecycle contracts.
- Define the install URL, `sealion new`, `sealion init`, and `sealion run dev`
  command contracts.
- Publish a Bun-served React login/dashboard starter backed by Tailwind, a C
  API, and Postgres.
- Replace the prototype shell CLI with a compiled Go CLI.

### Phase 1: HTTP Core

- Implement routing for common HTTP methods.
- Add request parsing for headers, query params, path params, and forms.
- Add response helpers for text, JSON, redirects, files, and errors.
- Add middleware chaining with predictable ownership rules.
- Add structured error pages for development and safe production errors.

### Phase 2: Application Kernel

- Harden the generated MVC directory contract.
- Add configuration loading from environment and checked-in defaults.
- Add service registration without hidden reflection.
- Add logging with request IDs.
- Add graceful shutdown and worker lifecycle hooks.

### Phase 3: Frontend And Assets

- Keep the Bun/React frontend container as the public local-development
  entrypoint.
- Proxy `/api` and `/health` to the C backend to preserve same-origin cookies.
- Define the frontend component layout for app screens, reusable patterns, and
  primitives.
- Make Tailwind the mandatory generated styling path.
- Add a production frontend build/serve contract after the dev loop is stable.

### Phase 4: Database Layer

- Use Postgres as the required database.
- Add connection pooling.
- Add migrations with up/down support.
- Add a query builder with parameter binding by default.
- Add schema inspection helpers for Postgres-specific capabilities.
- Explore a constrained model layer without pretending C has Eloquent-style
  reflection.

### Phase 5: Web App Essentials

- Ship the default generated auth experience: register, login, logout, and
  dashboard.
- Add signed cookies and encrypted session storage.
- Add CSRF protection.
- Add validation primitives.
- Add password hashing and auth scaffolding.
- Add file upload handling with size and type controls.

### Phase 6: Background Work

- Add Postgres-backed queues.
- Add scheduled jobs.
- Add mail driver contracts.
- Add cache contracts.
- Add retries, dead-letter behavior, and job inspection commands.

### Phase 7: Developer Experience

- Harden the `sealion` Go CLI.
- Add project scaffolding.
- Add migration generation.
- Add infrastructure generation, validation, and diff commands.
- Add test helpers for HTTP requests and database state.
- Add containerized watch/rebuild workflow.
- Add debug tooling for memory ownership and request leaks.

### Phase 8: Production Contract

- Define the official production image.
- Define the first production infrastructure-as-code target after local Compose
  is stable.
- Add health checks and readiness checks.
- Add structured logs suitable for container platforms.
- Add deployment examples for a single-node app and a worker process.
- Add backup, restore, and migration rollback guidance.

### Phase 9: Ecosystem

- Stabilize extension points.
- Add first-party packages only where the core framework has repeated evidence.
- Document compatibility rules.
- Publish upgrade guides between framework versions.

## First Milestone

The first milestone is a containerized app that can:

1. boot with one command,
2. serve a route,
3. return JSON,
4. write one structured request log line,
5. connect to the required Postgres container,
6. shut down cleanly.

That milestone proves the core loop before the project adds migrations, auth,
queues, or higher-level database features.
