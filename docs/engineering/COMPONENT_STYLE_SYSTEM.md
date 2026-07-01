# Frontend Contract

Carbide's default app uses a Bun/React/Tailwind frontend, Go API backend, and
Postgres database. The frontend is a mandatory Bun container in the default
local topology, not a host-installed JavaScript tooling requirement.

## Product Decision

The default Carbide UI should be React served by Bun, not a custom Blade-like
template system.

This keeps frontend authoring inside a mature ecosystem while preserving the
core Carbide bet: Go owns backend logic, auth, sessions, database access, and
the framework runtime contract.

## Runtime Model

```text
browser -> frontend container -> /api proxy -> backend Go container -> Postgres
```

- `frontend` owns Bun, React, Tailwind, browser routes, forms, dashboard UI,
  and the same-origin proxy.
- `backend` owns Go API routes, auth, session cookies, validation, and JSON.
- `db` owns durable Postgres state.

The frontend is the public entrypoint. It proxies `/api` and `/health` to the
backend so browser requests stay same-origin.

## Authoring Model

Generated apps start with:

```text
view/
`-- web/
    |-- Dockerfile
    |-- bun.lock
    |-- index.html
    |-- package.json
    `-- src/
        |-- main.jsx
        |-- server.jsx
        `-- styles.css
```

Generated apps place the web app under `view/web/` so the project keeps the
MVC directory shape: `model/`, `view/`, and `controller/`.

The default UI is deliberately small: register, login, logout, and dashboard.
React components call same-origin `/api` endpoints with `credentials: "include"`
so the backend can own HttpOnly cookies.

## Styling

Generated apps use Tailwind as the mandatory styling path. `styles.css` is the
Tailwind input file, and the container builds generated CSS with the checked-in
Bun lockfile.

Future component conventions can still use L1/L2/L3 language:

- L1: primitive controls and text treatments;
- L2: reusable patterns such as form sections or page headers;
- L3: app-specific pages and product/domain sections.

The default React starter should keep those boundaries in component structure.

## Regression Tests

The frontend contract needs dedicated regression coverage:

- generated apps include a Bun/React/Tailwind frontend container;
- generated apps include a Go backend/API container;
- generated apps include a Postgres database container;
- Bun frontend proxies `/api` and `/health` to the backend;
- auth uses same-origin cookies without CORS setup;
- login returns JSON and sets a session cookie;
- `/api/me` reports authenticated and anonymous states correctly;
- `/dashboard` is served by the React app shell;
- frontend and backend watch paths are present in Compose;
- generated frontend installs with `bun install --frozen-lockfile` and builds
  with `bun run build`;
- Tailwind is present and required in the generated frontend.
