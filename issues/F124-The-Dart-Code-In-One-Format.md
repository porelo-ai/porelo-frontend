# F124 — The Dart Code In One Format

**Status:** Implementing.
**Size:** S - one formatting commit over the Dart, the YAML, the `.feature` files and the shell
scripts, its hash in `.git-blame-ignore-revs`, the formatter's page width in `analysis_options.yaml`,
the checks in the build, and the parent moved to `0.2.1-SNAPSHOT`.

**What must be true.** Every Dart file in this repository is as `dart format` writes it, every other
text file is as the shared `.editorconfig` says, and the build refuses one that is not, so a change
shows only what it changes.

## Why

[PJ29](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj29) gives every
repository one code style, the shared `.editorconfig` beside each language's own formatter. Here the
Dart is formatted by hand to 120 columns in the formatter's older style: `dart format` at that width
changes 542 of 1,506 files, measured on `7c38e4e` with Dart 3.13.0.

## Plan

- **The width** comes from the shared `.editorconfig`'s, written as the formatter's `page_width` in
  `analysis_options.yaml`, so `dart format` needs no flag and an editor agrees with it.
- **The parent** moves from `porelo-parent` `0.2.0` to `0.2.1-SNAPSHOT`, which carries the shared
  `.editorconfig` that `check-shared` compares.
- **The other files** follow the shared `.editorconfig`: 4 spaces, never tabs, so the 12 YAML files
  and the 45 `.feature` files move from 2 spaces to 4, and the two shell scripts are as `shfmt`
  writes them, checked through Spotless from the parent. Dart is the one exception: the shared file's
  `[*.dart]` says `indent_size = 2` and `max_line_length = 120`, as `dart format` writes them.
- **One commit** runs `dart format lib test tool integration_test`, then `dart run build_runner build`,
  which must leave no diff, so the generated steps are written as formatted. Only whitespace and line
  breaks change. Its hash goes into `.git-blame-ignore-revs` in the commit after it.
- **The build** checks it in the step that runs `dart analyze`:
  `dart format --output=none --set-exit-if-changed lib test tool integration_test`.
- **Red first:** that step, run on the commit before the formatting, fails and names the files; after
  it, it passes.

## Acceptance

- **The check fails before the formatting and passes after**, run as the build runs it.
- **The formatting commit changes no token**: `dart analyze` is clean, the whole suite green and
  `build_runner` leaves no diff, on the commit.
- **`git blame` skips it** through `.git-blame-ignore-revs`.
