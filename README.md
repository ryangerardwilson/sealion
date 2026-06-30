# Sealion

Sealion is an experimental, Laravel-inspired full-stack web framework for C.

The goal is not to copy Laravel line by line. The goal is to find the smallest
set of conventions, tools, and runtime guarantees that make building web apps in
C feel coherent, productive, and safe enough to be practical.

## Product Bet

C is a difficult language for high-level web application development, but a
strict framework can remove many repeated decisions:

- one mandatory app container image
- one mandatory Postgres service container
- one project layout
- one request lifecycle
- one database migration path
- one checked-in infrastructure contract
- one CLI entry point
- one opinionated set of security defaults

Sealion should make the hard parts visible instead of hiding them behind magic.

## Core Principles

- **Container-first:** every app runs inside the official Sealion app
  container.
- **Postgres-only:** Sealion targets Postgres as the mandatory database, not as
  one interchangeable adapter among many.
- **Separate runtime boundaries:** the app container and database container are
  separate services with separate lifecycles, health checks, logs, and storage.
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
- A general-purpose C package manager.
- ORM magic that depends on runtime reflection C does not have.
- Supporting multiple databases, web servers, or deployment targets in the
  first versions.

## Runtime Topology

The default Sealion app runs as at least two containers:

1. the Sealion app container, which owns HTTP, routing, application code,
   migrations, workers, logs, and framework tooling;
2. the Postgres database container, which owns durable relational state through
   a mounted volume or managed persistent storage.

The containers communicate over a private container network. The app depends on
Postgres readiness, but Postgres must remain independently restartable,
backed-up, restored, and upgraded. Local development can use a generated Compose
file, but the architectural contract is service separation rather than a single
container running both processes.

## Infrastructure As Code Contract

Sealion apps must be reproducible from the repository. Runtime behavior should
not depend on manual console setup, undocumented shell history, or hidden
machine state.

The first supported infrastructure target is a generated Docker Compose setup
for local development. Production targets come later, one at a time, after the
local app and Postgres contract is stable.

At minimum, each app must keep these contracts in version control:

- container definitions for the app and required services;
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

## Roadmap

### Phase 0: Project Contract

- Define the official container image and supported Linux base.
- Define the official Postgres image, version policy, storage contract, and
  connection environment variables.
- Define the default two-container Compose topology for local development.
- Define the mandatory infrastructure-as-code file layout and validation rules.
- Choose compiler, libc, build system, formatter, and test runner.
- Create the canonical app directory layout.
- Define the request, response, app, and service lifecycle contracts.
- Publish a minimal "hello route" sample app.

### Phase 1: HTTP Core

- Implement routing for common HTTP methods.
- Add request parsing for headers, query params, path params, and forms.
- Add response helpers for text, JSON, redirects, files, and errors.
- Add middleware chaining with predictable ownership rules.
- Add structured error pages for development and safe production errors.

### Phase 2: Application Kernel

- Add controller-style handlers.
- Add configuration loading from environment and checked-in defaults.
- Add service registration without hidden reflection.
- Add logging with request IDs.
- Add graceful shutdown and worker lifecycle hooks.

### Phase 3: Views And Assets

- Decide whether templates are compiled, interpreted, or generated C.
- Add layouts, partials, escaping, and safe HTML helpers.
- Add static asset serving for local development.
- Add a production asset manifest contract.

### Phase 4: Database Layer

- Use Postgres as the required database.
- Add connection pooling.
- Add migrations with up/down support.
- Add a query builder with parameter binding by default.
- Add schema inspection helpers for Postgres-specific capabilities.
- Explore a constrained model layer without pretending C has Eloquent-style
  reflection.

### Phase 5: Web App Essentials

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

- Build the `sealion` CLI.
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
templates, queues, or higher-level database features.
