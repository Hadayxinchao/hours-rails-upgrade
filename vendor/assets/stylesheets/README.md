# Vendored Sass libraries

Frozen copies of the Sass sources the app was built with, so the stylesheets
compile with Dart Sass without the unmaintained gems (which depend on the
removed Ruby Sass implementation):

- Bourbon 3.2.3 (MIT) — `_bourbon.scss`, `addons/`, `css3/`, `functions/`, `helpers/`, `settings/`
- Neat 1.5.1 (MIT) — `_neat.scss`, `_neat-helpers.scss`, `grid/`

Do not edit; replace with plain CSS when the UI is next redesigned.

## Local patch

Neat 1.5.1 targeted Sass 3.2, where assigning a variable inside a mixin
overwrote the global. Sass ≥ 3.4 (and Dart Sass) creates a local instead, which
silently turned `row(table)` / `media()` layouts into floats. The affected
assignments in `grid/` carry `!global`, matching what Neat 1.6 did upstream.
