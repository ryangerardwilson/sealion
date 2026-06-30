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
the app URL printed by sealion run dev
```

If port 8080 is already in use, `sealion run dev` selects another local port.
To choose one explicitly:

```sh
SEALION_HTTP_PORT=18080 sealion run dev
```

The app listens on port 8080 inside the container. The browser URL is the host
URL printed by the CLI and app logs.

When Docker Compose supports file watch, `sealion run dev` starts the stack with
Compose watch enabled. Edits under `src/`, `model/`, `controller/`, `view/`,
`ui_components/`, or to `Dockerfile` rebuild and replace the app container.

Generated apps keep page flow in `view/*.skin`, but UI implementation belongs in
`.scale` components under `ui_components/l1`, `ui_components/l2`, and
`ui_components/l3`. The starter renderer supports escaped variables with
`{{ name }}`, trusted raw slots with `{!! content !!}`, and Blade-like Scale tags
with same-name passover, such as `<s-l3.dashboard-page :passover=[user_email] />`.
`sealion format` expands passover arrays into one variable per line for
readability.
Explicit props remain available for aliases or literals, such as
`<s-l3.example :title="page_title" label="Save" />`.
In this model, component composition is level-checked: `.skin` files may use L2
and L3 components, L2 components may use L1 primitives, L3 components may use
L1 primitives and L2 patterns, and L1 primitives stay primitive.

The generated app includes:

- a C app container;
- a Postgres service container;
- checked-in Docker Compose infrastructure;
- register, login, logout, and dashboard routes;
- MVC directories for model, view, and controller code;
- `.scale` components under `ui_components/`;
- a `layout.scale` component used from each `.skin` page;
- Postgres-backed users and sessions;
- a seeded demo account at `admin@sealion.local` with password `password`.

## Commands

### `sealion help`

Prints the command reference.

### `sealion upgrade`

Upgrades the installed CLI when a newer GitHub commit is available.

### `sealion format`

Formats `.skin` and `.scale` files in the current project.

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
