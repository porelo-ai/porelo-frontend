# F64 — The Guided Walk as a Package of Its Own

**Status:** later.
**Size:** L - what is left is in another repository, `flutter-guided-walk`: a Semantics reader,
a WebSocket way, a versioned walk format, the waiting words and pub.dev; this repository's part is S.

**What must be true.** Any agent can lead a person through any Flutter app the way the guided walk
leads a person through this interface, from a package published on its own that the app only
depends on.

## Why

The plugin `guided_walk` is in the public repository `fuinorg/flutter-guided-walk` under
Apache-2.0, and this interface takes it by git at a version tag. The app gives it the variable that
names the folder, the theme of the panel's window, the panel's words and its own choice widgets; a
Linux part names and sizes the panel's window. An agent reaches the walk through its files or
through an MCP server over them, and the walk exists in development builds only. Sokar's backend
has no part in it.

## Plan

- **Read in the plugin as pinned.** `pubspec.lock` holds `guided_walk` v0.2.0 by git, with
  `publish_to: none`. Its `lib/src/window_state.dart` reads the window from widgets (`TextField`
  with `obscureText`, `WalkSecret`), not from the Semantics tree. The agent is reached through the
  folder or `lib/src/mcp/walk_mcp.dart`, with no WebSocket. A walk file has `title` and `steps` and
  no version. `WalkPanel` in `lib/src/walk_panel.dart` shows "…" while `view.waiting`, and nothing
  after it.
- **In `flutter-guided-walk`, in order:** the window state from the Semantics tree, with a package
  test over the example app; `Sensitive` beside `obscureText`; a seam for the way to the agent, with
  the folder, a WebSocket and MCP behind it; the walk format written down with a version, an
  unknown one refused, the example walks checked against it; after 15 seconds of "…" the words with
  the time passed, from `WalkPanelTexts`; then the release on pub.dev.
- **Here, after that release:** `pubspec.yaml` takes `guided_walk` from pub.dev. `WalkSecret`
  becomes `Sensitive` in `lib/src/ui/new_machine.dart`, `connection_wizard.dart`,
  `connections_view.dart`, `messages_view.dart` (`_secretIf`), `unlock_terminal.dart` and
  `session_view.dart`. `sokarWalkTexts` in `lib/src/ui/walk_texts.dart` gains the German waiting
  words. `doc/guided-walk.md` follows.
- **What else stays in `lib/`:** `walkWindowPath` and `_walk` in `lib/main.dart` (`SOKAR_WALK`,
  the `walkChoices` hook for `ChoiceField`), `WalkFrame` in `lib/src/app/sokar_app.dart`, the
  `walk-show` button in `lib/src/ui/shell.dart`. The first acceptance item has to be read against
  these.
- **Red first:** in the plugin, the Semantics test over the example app, which today's widget
  reader fails. Here nothing new is red: `flutter analyze` fails on `WalkSecret` once the release
  drops it, and `test/walks_test.dart` stays green.

## Acceptance

- **Published on pub.dev**, and this interface depends on it from there; the only Sokar-specific
  part left here is marking what is secret. Seen to fail: `pubspec.yaml` still takes it by git, or
  walk code other than secret marking remains in `lib/`.
- **The window's state is read from Flutter's Semantics tree**, so it describes any app, not this
  one's own widgets. Seen to fail: a test in the package describing its example app built from
  plain Material widgets with no knowledge of them.
- **Secrets are blanked generically**: every `obscureText` field, and anything an app wraps in a
  `Sensitive(child: …)` (this interface's terminals would use it). Seen to fail: a package test
  whose window state shows the content of either.
- **The way to the agent is pluggable**: a folder, a WebSocket, or an MCP server. Seen to fail: a
  package test that drives one walk over each.
- **The walk file's format is written down and versioned**, so an agent can write one without
  knowing the app's internals: steps, the keys or button words they point at, what moves them on,
  and what makes them go away. Seen to fail: a walk file with an unknown version is refused, and
  the example walks are checked against the written format.
- **The person is never left with dots alone.** While the panel waits for the agent's answer and
  shows "…", after 15 seconds it says so in words, in the panel's language, with the time that has
  passed: "Der Agent arbeitet daran - seit 1:20". The agent's next line replaces it. Seen to fail: a
  widget test that waits 15 seconds with no answer and then sends one. (Writing one line before any
  longer work is the leading agent's part, not the plugin's.)

## To be checked

- **Whether the wiring left in `lib/` counts as "secret marking only"**: the `SOKAR_WALK` variable,
  `WalkFrame`, the button that shows the walk again, the `ChoiceField` hook and the German words; or
  the first acceptance item is reworded to allow an app's wiring. (the operator's)
- **Whether the Semantics tree carries what `filled:<key>` reads today** from Sokar's own choice
  fields, so the `walkChoices` hook can go. Measured in the plugin. (Agent Frontend's)
- **Who publishes on pub.dev, and under which publisher.** (the operator's)
