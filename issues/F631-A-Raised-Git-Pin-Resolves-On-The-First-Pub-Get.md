# F631 — A Raised Git Pin Resolves On The First Pub Get

```json
{
  "$schema": "issue-1.json",
  "id": "F631",
  "title": "A Raised Git Pin Resolves On The First Pub Get",
  "state": "Backlog",
  "size": "S",
  "priority": "High",
  "rank": 1,
  "blockedBy": [],
  "covers": "The first flutter pub get after a git dependency's pin moved, on a machine whose pub cache already mirrors that repository, drops a transitive package and fails; reproduced on the build box, cause inside pub still to be read"
}
```

**Why this size.** S: one step before `pub get` in the Maven build and the walk's preparation, and a script that
reproduces the failure; no contract, no change to the window's code.

**What must be true.** Moving the pin of a git dependency (`porelo_planning`) never breaks the first build, walk or
test run on a machine that built the earlier pin: the first `flutter pub get` resolves what `pubspec.lock` names, as
every later one does.

## Plan

- Measured: with a pub cache whose mirror of `porelo-planner` holds the earlier pinned commit but not the new one, a
  fresh checkout of the pin raise runs `flutter pub get` (Flutter 3.47.0) and gets *"These packages are no longer
  being depended on: markdown 7.3.1 / Changed 1 dependency!"*, then *"Failed to parse .dart_tool/package_graph.json:
  dependencies for `markdown` missing"*, exit 1. The second `pub get` in a fresh checkout on the same cache is green.
  It happened twice on real runs: the build box's `./mvnw verify` and the walk VM's walk preparation, each at the
  minute that machine first fetched the new commit. A cache without the mirror, or with the commit already in it,
  does not fail. Both pinned commits name `markdown: ^7.3.1` in `screen/pubspec.yaml`.
- First, read in the SDK's pub source which pubspec the resolution reads for a git package whose commit is not yet in
  the mirror (inferred, not measured: one read before the mirror is fetched), and whether a newer Flutter fixes it.
- Then the fix at its cause, never a second `pub get` alone: before the first `pub get`, each pinned git dependency's
  commit is brought into the pub cache's mirror, or the resolution is made to read the pinned commit; in `pom.xml`'s
  `flutter-pub-get`, the walk's preparation in `tool/walk_idea.sh`, and the Build's `flutter pub get` steps if the
  runner's cache can hold an older mirror.
- Red first: the reproduction script, run on the build box against a cache prepared as above, fails before the fix
  and passes after; it is a test script and gets no tests of its own.

## Acceptance

- On a pub cache whose mirror lacks the pinned commit, the first `./mvnw verify` and the walk's preparation are green,
  seen on the build box after being seen red there.
