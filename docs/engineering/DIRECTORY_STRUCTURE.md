# Directory Structure

Sealion uses a narrow structure at the start so future framework code,
generated apps, infrastructure, tests, and documentation have clear ownership.

```text
.
|-- .github/
|   `-- workflows/
|       |-- ci.yml
|       `-- pages.yml
|-- bin/
|   `-- sealion
|-- docs/
|   |-- engineering/
|   |   |-- COMPONENT_STYLE_SYSTEM.md
|   |   |-- CI_CD_REGRESSION_TESTS.md
|   |   |-- DIRECTORY_STRUCTURE.md
|   |   `-- INITIAL_USER_EXPERIENCE.md
|   `-- site/
|       |-- CNAME
|       |-- assets/
|       |   `-- styles.css
|       |-- ci-cd-regression-tests.html
|       |-- component-style-system.html
|       |-- index.html
|       |-- initial-user-experience.html
|       `-- repo-structure.html
|-- examples/
|   `-- hello/
|-- include/
|   `-- sealion/
|       `-- ui/
|-- infra/
|   |-- compose/
|   `-- schemas/
|-- scripts/
|   |-- check_repo_contract.sh
|   `-- test_cli_scaffold.sh
|-- src/
|   `-- ui/
|-- templates/
|   `-- default/
|       |-- Dockerfile
|       |-- docker-compose.yml
|       |-- controller/
|       |   |-- auth_controller.c
|       |   `-- page_controller.c
|       |-- migrations/
|       |   `-- 001_auth.sql
|       |-- model/
|       |   |-- session.c
|       |   `-- user.c
|       |-- sealion.toml
|       |-- src/
|       |   |-- app.h
|       |   `-- main.c
|       |-- ui_components/
|       |   |-- l1/
|       |   |   |-- .gitkeep
|       |   |   |-- action_link.scale
|       |   |   |-- button.scale
|       |   |   |-- form_label.scale
|       |   |   |-- heading.scale
|       |   |   |-- muted_text.scale
|       |   |   `-- text_input.scale
|       |   |-- l2/
|       |   |   |-- auth_form.scale
|       |   |   |-- layout.scale
|       |   |   `-- page_header.scale
|       |   `-- l3/
|       |       |-- dashboard_page.scale
|       |       |-- home_page.scale
|       |       `-- not_found_page.scale
|       `-- view/
|           |-- dashboard.skin
|           |-- home.skin
|           |-- login.skin
|           |-- not_found.skin
|           `-- register.skin
|-- tests/
|   |-- fixtures/
|   |-- integration/
|   |-- regression/
|   `-- unit/
|-- install.sh
`-- README.md
```

## Ownership

- `.github/workflows/`: CI and documentation deployment.
- `bin/sealion`: installable CLI entry point.
- `docs/engineering/`: source-of-truth engineering plans.
- `docs/site/`: static GitHub Pages artifact.
- `examples/`: generated or hand-written sample apps.
- `include/sealion/`: public C headers.
- `include/sealion/ui/`: public component and style-system APIs.
- `infra/compose/`: local Compose templates and generated examples.
- `infra/schemas/`: schemas for infrastructure, environment, and app metadata.
- `scripts/`: repo-owned checks and maintenance commands.
- `src/`: framework implementation.
- `src/ui/`: component rendering, utility parsing, token resolution, and CSS
  generation.
- `templates/default/`: generated starter app used by `sealion new` and
  `sealion init`.
- `templates/default/model/`: generated Postgres-backed model code.
- `templates/default/controller/`: generated request-flow handlers.
- `templates/default/view/`: thin `.skin` starter templates that compose
  `.scale` components and pass data into them.
- `templates/default/ui_components/`: generated `.scale` components organized
  into `l1`, `l2`, and `l3`; skins may use L2/L3, L2 may use L1, L3 may use
  L1/L2, and L1 stays primitive.
- `tests/fixtures/`: shared test fixtures.
- `tests/integration/`: tests that use Postgres or containers.
- `tests/regression/`: tests created after a bug or broken contract.
- `tests/unit/`: small deterministic C tests.
- `install.sh`: GitHub URL installer that places `sealion` on the user's PATH.

## First Implementation Rule

Empty directories are placeholders until a real file belongs there. When a
directory gains behavior, its first file should make that behavior testable.
