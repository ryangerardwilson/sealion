# Carbide

Carbide is an experimental, Laravel-inspired full-stack framework with a React
frontend container, a Go backend container, and a mandatory Postgres database.

The goal is not to copy Laravel line by line. The goal is to find the smallest
set of conventions, tools, and runtime guarantees that make building web apps in
containers feel coherent, productive, and safe enough to be practical.

## Product Bet

The product bet is Docker-first convention over host setup: React owns the
browser, Go owns the application API, and Postgres owns durable relational
state. Carbide should make that full-stack default feel boring, inspectable, and
fast to start:

- one Bun/React/Tailwind frontend container
- one Go backend/API container
- one mandatory Postgres service container
- one project layout
- one API request lifecycle
- one database migration path
- one checked-in infrastructure contract
- one Go CLI entry point
- one opinionated set of security defaults

Carbide should make the hard parts visible instead of hiding them behind magic.

## Core Principles

- **Container-first:** every app runs through generated containers, not host
  Bun, host backend toolchains, or hidden local services.
- **Go CLI:** `carbide` is a compiled Go CLI. It owns scaffolding, upgrades,
  local port selection, structured terminal output, queryable dev logs, and the
  Docker Compose development lifecycle.
- **React default frontend:** the browser UI lives in the frontend container.
  Bun, React, and Tailwind are required inside that container, not on the
  developer's host machine.
- **Go backend:** auth, sessions, validation, API routes, and business logic
  live in the backend container.
- **Postgres-only:** Carbide targets Postgres as the mandatory database, not as
  one interchangeable adapter among many.
- **Separate runtime boundaries:** frontend, backend, and database containers
  are separate services with separate lifecycles, health checks, logs, and
  storage.
- **Infrastructure as code:** every supported runtime dependency, service
  boundary, volume, network, secret contract, environment variable, health
  check, and deploy target must be described in checked-in code.
- **Explicit ownership:** requests, responses, sessions, and database handles
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
- A general-purpose language package manager.
- ORM magic that hides SQL, migrations, or operational behavior.
- Supporting multiple databases, web servers, or deployment targets in the
  first versions.

## Runtime Topology

The default Carbide app runs as three containers:

1. the frontend container, which owns Bun, React, Tailwind, browser routing,
   the API proxy, and the public host port;
2. the backend container, which owns Go API routes, auth, sessions, application
   code, migrations, logs, and framework tooling;
3. the Postgres database container, which owns durable relational state through
   a mounted volume or managed persistent storage.

The browser talks to the frontend on one origin. The frontend proxies `/api` and
`/health` to the backend over the private Compose network, which keeps cookies
same-origin and avoids CORS as the default development problem. The backend
depends on Postgres readiness, but each service remains independently
restartable, inspectable, and replaceable.

## Infrastructure As Code Contract

Carbide apps must be reproducible from the repository. Runtime behavior should
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

The Carbide CLI should generate and validate these files instead of asking
developers to maintain ad hoc infrastructure by hand. Infrastructure is part of
the application source, and changes to it must be reviewable, diffable, and
recoverable.

## Documentation And Automation

The public documentation site is published from `docs/site` to GitHub Pages at:

```text
https://carbide.ryangerardwilson.com
```

CI starts with repository contract checks and grows into the full framework
regression suite described in `docs/engineering/CI_CD_REGRESSION_TESTS.md`.
The planned repo layout lives in `docs/engineering/DIRECTORY_STRUCTURE.md`.
The frontend contract lives in `docs/engineering/COMPONENT_STYLE_SYSTEM.md`.

## Install And Start

```sh
curl -fsSL https://raw.githubusercontent.com/ryangerardwilson/carbide/main/install.sh | bash
carbide new demo
cd demo
carbide run dev
carbide status
carbide stop dev
```

The installer currently builds the `carbide` CLI with Go, so Go must be
available on the host machine. Generated apps still run Bun, the Go backend
build, and Postgres inside containers.

`carbide new <project-name>` creates a new project directory. `carbide init`
initializes the current directory only when it is empty. `carbide run dev`
starts the generated frontend, backend, and Postgres containers with register,
login, logout, and dashboard already wired. It prints the working app and API
URLs, preferring `http://localhost:8080` and silently selecting another local
port when 8080 is already in use. Set `CARBIDE_HTTP_PORT=<port>` to choose the
host port explicitly.

`Ctrl+C` in `carbide run dev` detaches from live log streaming and leaves the
containers running. `carbide follow logs` attaches to live container logs again.
`carbide status` prints a table of Compose services, container names, published
host ports, internal container ports, and status. `carbide stop dev` stops the
local development stack. `carbide help` prints the command reference.
`carbide upgrade` upgrades the installed CLI when a newer GitHub commit is
available. `carbide logs` reads the structured dev log file written by
`carbide run dev`; examples include `carbide logs service backend` and
`carbide logs containing "/api/login" json`.

When Docker Compose supports file watch, `carbide run dev` starts the stack with
quiet Compose output, watch enabled, and live logs streamed below the startup
summary. Edits under `view/web/src/`, `src/`, `model/`, `controller/`, view
package/config files, or `Dockerfile` rebuild and replace the relevant
container.

CLI output is rendered through a small Go output layer: headings, aligned
labels, compact tables, TTY-only color, full-width terminal-only
ILoveCandy-style per-container startup and shutdown animation, timestamped log
rows, and plain text when piped or captured by scripts. `carbide run dev`
prints only the working app/API URLs before the startup animation and log
stream. Logs begin only after Compose reports the stack ready. `NO_COLOR`
disables ANSI color without disabling the terminal startup or shutdown
animation. Every streamed frontend, backend, database, and watch event is also
written as JSONL to
`.carbide/log/dev.jsonl` so humans, scripts, and AI agents can inspect or query
the whole local system from one command.

Generated apps use an MVC shape. `view/web/` owns the Bun server, Tailwind
build, browser UI, and same-origin `/api` calls. `model/` owns
Postgres state, `controller/` owns request flow and JSON responses, and `src/`
owns the Go HTTP/API server.

## Roadmap

### Phase 0: Project Contract

- Define the official container image and supported Linux base.
- Define the official Postgres image, version policy, storage contract, and
  connection environment variables.
- Define the default three-container Compose topology for local development.
- Define the mandatory infrastructure-as-code file layout and validation rules.
- Choose Go version, build system, and test runner.
- Create the canonical app directory layout.
- Define the request, response, app, and service lifecycle contracts.
- Define the install URL, `carbide new`, `carbide init`, and `carbide run dev`
  command contracts.
- Publish a Bun-served React login/dashboard starter backed by Tailwind, a Go
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
- Proxy `/api` and `/health` to the Go backend to preserve same-origin cookies.
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
- Explore a constrained model layer without pretending every Eloquent pattern
  maps cleanly into a containerized Go backend.

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

- Harden the `carbide` Go CLI.
- Add project scaffolding.
- Add migration generation.
- Add infrastructure generation, validation, and diff commands.
- Add test helpers for HTTP requests and database state.
- Add containerized watch/rebuild workflow.
- Add debug tooling for request lifecycle and connection leaks.

### Phase 8: Production Contract

- Define the official production image.
- Define the first production infrastructure-as-code target after local Compose
  is stable.
- Add health checks and readiness checks.
- Extend the existing structured dev logs into the production container
  contract.
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
4. write one queryable dev log line,
5. connect to the required Postgres container,
6. shut down cleanly.

That milestone proves the core loop before the project adds migrations, auth,
queues, or higher-level database features.
