# F378 — Waits Said In Needs You

**Status:** Review; the time left is built, and a review's wait and files wait on the daemon.
**Size:** S - two facts on rows and a note, if the daemon gives them.

**What must be true.** A review in *Needs you* says how long it has waited and how many files it holds, and the waits-on-you note under *Running* says the time left on a question.

## Plan

- `test/ui/running_question_time_test.dart` exercises the Running note against `FakeBackend`, with
  `Attention`'s injected clock: a finite deadline counts down without another daemon event, an expired
  question stays visible without being decided, unlimited and unknown deadlines stay distinct, and
  a repeated question keeps its deadline until its verdict arrives. All five were seen to fail on the
  view before the change.
- `lib/src/ui/running_view.dart` adds the question's time left to its waits-on-you note using
  `Prompt.expiresAt`, `Prompt.neverRunsOut`, `Attention.now` and `howLongUntil`. A timer refreshes only
  while the selected tab has an unexpired question, and is canceled when the countdown ends or the
  view leaves. No decision is inferred from time passing.
- Review-row facts require a reliable task association and a reported changed-file count; the
  current task-row contract provides neither. No client contract changes are made here.

## Acceptance

- Each said where the design shows it, seen to fail first.

## Decided while building

- Build only the Running question note with the existing contract. Its words distinguish time left,
  out of time, an explicitly unlimited question, and a machine that does not report a usable deadline.
  The existing link still leads to Needs you for the answer.
- `Task.waiting` reports whether that task has work at the gate, not its age or changed-file count.
  `Task.since` is the current runtime state's start; `Task.files` lists handed-in files. Neither is
  substituted for a review fact.
- `PendingPush.waiting` and `PendingPush.at` do report a push's wait, and `Review` returns ranked
  files. The client documents that pending refs cannot reliably be joined to task container names;
  several containers can share a ref. An empty ranked-file list also means an older daemon without
  ranked review. `FakeBackend.theGate` and `theRanking` reflect these separate replies, rather than
  establish a task-row association or an always-known file count. Review-row wait and file facts
  therefore remain unbuilt; a daemon-served association and trustworthy count are still needed.
- Written by a builder whose sandbox could not run Flutter; the five tests were run afterwards, red on the view before the change and green on the change.
- The repository's named Dart and Flutter skills are unavailable in the local skill catalogs; the
  no-network constraint prevents loading them.
- A read-only review by another model finds no confirmed correctness defect in the countdown and
  tests.

## To be checked

- A review's wait and its files in *Needs you*: not built, as above.
