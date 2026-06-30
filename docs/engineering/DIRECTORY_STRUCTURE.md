# Directory Structure

Sealion uses a narrow structure at the start so future framework code,
generated apps, infrastructure, tests, and documentation have clear ownership.

```text
.
|-- .github/
|   `-- workflows/
|       |-- ci.yml
|       `-- pages.yml
|-- docs/
|   |-- engineering/
|   |   |-- CI_CD_REGRESSION_TESTS.md
|   |   `-- DIRECTORY_STRUCTURE.md
|   `-- site/
|       |-- CNAME
|       |-- assets/
|       |   `-- styles.css
|       |-- ci-cd-regression-tests.html
|       |-- index.html
|       `-- repo-structure.html
|-- examples/
|   `-- hello/
|-- include/
|   `-- sealion/
|-- infra/
|   |-- compose/
|   `-- schemas/
|-- scripts/
|   `-- check_repo_contract.sh
|-- src/
|-- tests/
|   |-- fixtures/
|   |-- integration/
|   |-- regression/
|   `-- unit/
`-- README.md
```

## Ownership

- `.github/workflows/`: CI and documentation deployment.
- `docs/engineering/`: source-of-truth engineering plans.
- `docs/site/`: static GitHub Pages artifact.
- `examples/`: generated or hand-written sample apps.
- `include/sealion/`: public C headers.
- `infra/compose/`: local Compose templates and generated examples.
- `infra/schemas/`: schemas for infrastructure, environment, and app metadata.
- `scripts/`: repo-owned checks and maintenance commands.
- `src/`: framework implementation.
- `tests/fixtures/`: shared test fixtures.
- `tests/integration/`: tests that use Postgres or containers.
- `tests/regression/`: tests created after a bug or broken contract.
- `tests/unit/`: small deterministic C tests.

## First Implementation Rule

Empty directories are placeholders until a real file belongs there. When a
directory gains behavior, its first file should make that behavior testable.

