# Frontend Contract

Sealion's default app uses a React frontend, C API backend, and Postgres
database. The frontend is a mandatory container in the default local topology,
not a host-installed Node requirement.

## Product Decision

The default Sealion UI should be React, not a custom Blade-like C template
system.

This keeps frontend authoring inside a mature ecosystem while preserving the
core Sealion bet: C owns backend logic, auth, sessions, database access, and
the framework runtime contract.

## Runtime Model

```text
browser -> frontend container -> /api proxy -> backend C container -> Postgres
```

- `frontend` owns React, Vite, browser routes, forms, dashboard UI, and CSS.
- `backend` owns C API routes, auth, session cookies, validation, and JSON.
- `db` owns durable Postgres state.

The frontend is the public entrypoint. It proxies `/api` and `/health` to the
backend so browser requests stay same-origin.

## Authoring Model

Generated apps start with:

```text
frontend/
|-- Dockerfile
|-- index.html
|-- package.json
|-- package-lock.json
|-- vite.config.js
`-- src/
    |-- main.jsx
    `-- styles.css
```

The default UI is deliberately small: register, login, logout, and dashboard.
React components call same-origin `/api` endpoints with `credentials: "include"`
so the backend can own HttpOnly cookies.

## Styling

Generated apps use plain checked-in CSS first. Tailwind remains optional for
projects that choose it, but it is not required by the framework starter.

Future component conventions can still use L1/L2/L3 language:

- L1: primitive controls and text treatments;
- L2: reusable patterns such as form sections or page headers;
- L3: app-specific pages and product/domain sections.

The default React starter should keep those boundaries in component structure,
without requiring `.skin` or `.scale` files.

## Optional Server Rendering

The earlier `.skin` and `.scale` template work remains a possible future
server-rendered mode. It is no longer the default path. `sealion format` remains
available for projects that contain `.skin` and `.scale` files.

## Regression Tests

The frontend contract needs dedicated regression coverage:

- generated apps include a React frontend container;
- generated apps include a C backend/API container;
- generated apps include a Postgres database container;
- frontend proxies `/api` and `/health` to the backend;
- auth uses same-origin cookies without CORS setup;
- login returns JSON and sets a session cookie;
- `/api/me` reports authenticated and anonymous states correctly;
- `/dashboard` is served by the React app shell;
- frontend and backend watch paths are present in Compose;
- generated frontend builds from `npm ci` using a lockfile;
- `.skin`/`.scale` files are not required by the default starter.
