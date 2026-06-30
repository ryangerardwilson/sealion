# Initial User Experience

The first Sealion experience should feel close to Laravel's default product
loop: install one command, create an app, run one dev command, and land in a
working browser experience with auth already present. The default UI is now a
React frontend container backed by a C API container and Postgres.

## Happy Path

```sh
curl -fsSL https://raw.githubusercontent.com/ryangerardwilson/sealion/main/install.sh | bash
sealion new demo
cd demo
sealion run dev
```

Then open:

```text
the app URL printed by sealion run dev
```

If port 8080 is already in use, `sealion run dev` selects another local port.
To choose one explicitly:

```sh
SEALION_HTTP_PORT=18080 sealion run dev
```

The frontend listens on port 8080 inside its container. The browser URL is the
host URL printed by the CLI. API calls use the same origin under `/api`.

When Docker Compose supports file watch, `sealion run dev` starts the stack with
Compose watch enabled. Edits under `frontend/src/`, `src/`, `model/`,
`controller/`, frontend package/config files, or to `Dockerfile` rebuild and
replace the relevant container.

Generated apps keep browser UI in `frontend/src/`. React owns page flow, forms,
and dashboard rendering. The C backend owns `/api` routes, auth, sessions,
validation, and Postgres access. The frontend proxies `/api` and `/health` to
the backend so cookies remain same-origin.

The generated app includes:

- a React frontend container;
- a C backend/API container;
- a Postgres service container;
- checked-in Docker Compose infrastructure;
- register, login, logout, and dashboard routes;
- model and controller directories for backend code;
- Postgres-backed users and sessions;
- a seeded demo account at `admin@sealion.local` with password `password`.

## Commands

### `sealion help`

Prints the command reference.

### `sealion upgrade`

Upgrades the installed CLI when a newer GitHub commit is available.

### `sealion format`

Formats `.skin` and `.scale` files when a project contains them. In the default
React starter, it is a harmless no-op.

### `sealion new <project-name>`

Creates a new project directory from the default starter template. It fails if
the target already exists.

### `sealion init`

Initializes the current directory from the default starter template. It fails
unless the current directory is empty.

### `sealion run dev`

Runs the generated app through Docker Compose. The frontend, backend, and
database are separate services, matching the runtime topology contract.

## Product Principle

The first useful action is not "read docs." The first useful action is a running
app with a database-backed login flow.
