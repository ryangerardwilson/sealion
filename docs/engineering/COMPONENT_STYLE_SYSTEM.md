# Component Style System

Sealion should give developers Tailwind-like styling ergonomics without making
Tailwind, Node, npm, or a frontend build chain mandatory.

## Product Decision

Sealion owns a small utility-style component styling system.

The system is Tailwind-inspired, not Tailwind-compatible by default. Developers
can describe component styles with compact utility strings, but Sealion parses,
validates, and compiles those strings through framework-owned C tooling.

## Goals

- Let C web apps author common layout, spacing, typography, color, and state
  styles without hand-writing CSS for every component.
- Keep styling deterministic and inspectable.
- Generate stable CSS artifacts from checked-in component source.
- Make style errors fail during build or CI, not at runtime in the browser.
- Keep Tailwind optional for apps that choose it, not required by the
  framework.

## Non-Goals

- Full Tailwind compatibility.
- Requiring Node, npm, PostCSS, or the Tailwind CLI.
- Runtime CSS-in-JS.
- Dynamic browser-side class generation.
- A general CSS preprocessor.

## Authoring Model

Starter app components live in `.scale` files:

```text
ui_components/
|-- l1/
|-- l2/
`-- l3/
```

`.skin` views import `.scale` components and pass data through variables:

```html
<s-l2.layout :passover=[
  title,
  app_name
]>
  <s-l3.dashboard-page :passover=[
    user_email
  ] />
</s-l2.layout>
```

Use `:passover=[...]` when the component prop names match the variable names
already in scope. Use explicit props only for aliases or literals, such as
`<s-l3.example :title="page_title" label="Save" />`.
`sealion format` expands passover arrays into this multiline style.

Components receive only props passed by their caller. Component composition is
level-checked:

- `.skin` files may use L2 and L3 components only;
- L1 primitives do not use other components;
- L2 pattern components may use L1 primitives only;
- L3 product/domain components may use L1 primitives and L2 patterns.

Dotted component names map to `.scale` paths, so `s-l3.dashboard-page` resolves
to `ui_components/l3/dashboard_page.scale`.

Components can attach a style specification to rendered markup:

```c
sl_component("button")
  .style("inline-flex items-center gap-2 rounded-md px-4 py-2 text-sm font-medium bg-primary text-on-primary hover:bg-primary-strong disabled:opacity-50")
  .render(ctx);
```

The utility vocabulary should stay intentionally small at first:

- display and layout;
- flex and grid primitives;
- spacing;
- border radius and border width;
- typography;
- color tokens;
- hover, focus, disabled, and active states;
- a small responsive variant set.

## Compilation Model

The Sealion build step scans component style specs, validates each utility, and
emits generated CSS.

```text
component source -> utility parser -> token resolver -> generated CSS artifact
```

The generated CSS is a build artifact. The component source and theme tokens are
the source of truth.

## Tokens

Raw arbitrary values should be rare. The default path should use named tokens:

- colors;
- spacing;
- font sizes;
- radius;
- shadows;
- breakpoints;
- z-index layers.

Tokens belong in checked-in app configuration and should be visible to CI.

## Escape Hatch

Plain app CSS remains allowed for cases the utility system does not cover. It is
an escape hatch, not the primary authoring path.

Apps may also opt into Tailwind themselves, but Sealion must not require
Tailwind for generated apps, framework examples, CI, or documentation.

## Regression Tests

The component style system needs dedicated regression coverage:

- view files stay import-only and do not own CSS;
- components use `.scale`, not `.html`;
- component calls obey the L1/L2/L3 hierarchy;
- `sealion format` is idempotent for `.skin` and `.scale` files;
- L1/L2/L3 component directories exist in generated apps;
- utility parser accepts valid specs and rejects unknown utilities;
- generated CSS is deterministic;
- token references fail when missing;
- conflicting utilities produce predictable output or actionable errors;
- variants generate scoped selectors;
- component examples compile without Tailwind installed;
- plain CSS escape hatch does not bypass unsafe HTML or asset rules.

## First Milestone

The first component-style milestone is a button component that:

1. renders server-side HTML,
2. accepts a utility-style spec,
3. compiles deterministic CSS,
4. uses theme tokens,
5. fails CI on an unknown utility,
6. does not require Tailwind or Node.
