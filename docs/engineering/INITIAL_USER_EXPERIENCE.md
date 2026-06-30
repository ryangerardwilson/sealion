# Initial User Experience

The first Sealion experience should feel close to Laravel's default product
loop: install one command, create an app, run one dev command, and land in a
working browser experience with auth already present.

## Happy Path

```sh
curl -fsSL https://raw.githubusercontent.com/ryangerardwilson/sealion/main/install.sh | bash
sealion new demo
cd demo
sealion run dev
```

Then open:

```text
http://localhost:8080
```

If port 8080 is already in use, `sealion run dev` selects another local port.
To choose one explicitly:

```sh
SEALION_HTTP_PORT=18080 sealion run dev
```

The generated app includes:

- a C app container;
- a Postgres service container;
- checked-in Docker Compose infrastructure;
- register, login, logout, and dashboard routes;
- Postgres-backed users and sessions;
- a seeded demo account at `admin@sealion.local` with password `password`.

## Commands

### `sealion new <project-name>`

Creates a new project directory from the default starter template. It fails if
the target already exists.

### `sealion init`

Initializes the current directory from the default starter template. It fails
unless the current directory is empty.

### `sealion run dev`

Runs the generated app through Docker Compose. The app and database are separate
services, matching the runtime topology contract.

## Product Principle

The first useful action is not "read docs." The first useful action is a running
app with a database-backed login flow.
