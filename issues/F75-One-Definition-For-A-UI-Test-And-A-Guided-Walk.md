# F75 — One Definition For A UI Test And A Guided Walk

**Status:** Analyzed; blocked by flutter-guided-walk: a scenario that is also a walk.
**Size:** XL - splits into the plugin's step that carries its walk steps (`flutter-guided-walk`,
L); the walks in `doc/walks/` generated from their scenarios and compared (M); and every other step
given walk steps or marked by hand, over the 1,107 files in `test/features/step/` (L). Blocked by
`flutter-guided-walk`.

**What must be true.** Each of the interface's scenarios is also a walk a person can run, so a walk
and its test never drift apart.

## The shape

Once `flutter-guided-walk` lets a Cucumber step carry its walk steps, the interface's step
definitions are given their walk steps (target key, condition, German text), the steps outside the
interface are marked as by hand, and `doc/walks/*.json` is made from the scenarios instead of kept
beside them. The mechanism is the plugin's; the backend is short of nothing.

## Plan

- **Today:** `doc/walks/*.json` are nine walks written by hand in German, each a `title` and
  `steps` with `say`, `at` and `then`. `test/walks_test.dart` only checks that each key they name is
  in `lib/`. The scenarios are `test/features/*.feature`, turned into `*_test.dart` by
  `bdd_widget_test` (`build.yaml`), one step function per file in `test/features/step/` (such as
  `aBackendWithNothingOnIt`), helpers in `test/features/support/`.
- **Each step function gains its walk steps** (target key, condition, German text) in the form the
  plugin gives, or a mark that it is done by hand. Steps outside the interface, such as
  `World.startBackend` in `a_backend_with_nothing_on_it.dart`, are by hand.
- **A generator in `tool/`** writes each walk file from its scenario, which a tag in its feature
  file names as a walk.
- **`test/walks_test.dart`** compares each file in `doc/walks/` with what its scenario generates,
  beside today's key check.
- **Red first:** `test/walks_test.dart` with `1-a-machine.json` against its scenario in
  `adding_a_machine.feature`. Then a new test listing every step with neither walk steps nor the
  by-hand mark, red for all of them at first and made green file by file.

## Acceptance

- Every walk in `doc/walks/` is generated from a scenario, and none is written by hand. Seen to fail:
  `test/walks_test.dart` goes red where a walk file differs from what its scenario generates.
- Every step of a scenario has walk steps or is marked as by hand. Seen to fail: a test that lists a
  step with neither.

## Open questions

- **Whether every scenario becomes a walk, or only those tagged as one.** The acceptance says
  every one. (the operator's)

## To be checked

- **Where a step's walk steps live**: in its Dart step function, in the feature's text, or in a
  table beside it. (the owner of `flutter-guided-walk`'s)
- **How a step written in English for a test gets the German a walk says**, and what a step says
  when it is used in several scenarios. (Agent Frontend's)
- **What becomes of `doc/walks/walked/`**: kept as walked, or generated too. (Agent Frontend's)
