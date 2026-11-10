# F460 — The Host's Finished Work Brought To Central From The Window

```json
{
  "$schema": "issue-1.json",
  "id": "F460",
  "title": "The Host's Finished Work Brought To Central From The Window",
  "state": "Review",
  "size": "M",
  "priority": "Medium",
  "rank": 11,
  "blockedBy": [],
  "covers": "*Bring it to central…* brings a host's finished `main` to the central forge from the project's page, refusals in the backend's words."
}
```

**Why this size.** a release action for a project carried on a host, its question, its run through the backend, and its
answer, refused in the backend's words.

**How it stands.** The backend's gathered push of a host's `main` to the central forge, taking repository names and
naming a refused login, is on Porelo's main (2026-11-10), in its review.
- Built against the mock and the feature world: a project's page on its host offers *Bring it to central…* as a
  button and in its menu once the host says a repository's approved `main` is ahead; the question names the commits,
  Tasks1 `PushToCentral` streams the stages, and the page says what reached central or why not.
- A refused token reads as refused, with the forge and its status; a missing central token offers the machine's own
  store command in a terminal on it; the window never sees a token.
- *Push the approved main…*, the older terminal transfer through the secrets file, still stands beside it in the
  project menu.
- Reading fixed: forgetting a machine and closing the window cancel its push and end the wait on it; a second press
  while the question is open or the push runs starts nothing, and an empty list pushes nothing; a repository the
  machine does not carry, the host's placement leaves out or the host has not taken is never named, nor one this
  window just saw reach central on the host's older word, and the host is asked again after the answer; the menu and
  the page's button read the same word of the host; an answer naming nothing reads as refused; an unfilled `<host>`,
  an empty credential or an empty reason leaves no hole in the words. Declined: cancelling the push when the page is
  left, because a cut stream stops Git mid-transfer and leaves a write that may have reached central (Porelo's
  `CentralPushUncertain`); a release the person agreed to runs to its answer, which the page says when opened again.
- Not yet run against a host: central's `main` at the host's commit after one press, and whether the row then says
  at central before the host's follow answers again.

**What must be true.** A person brings a host's finished `main` of a project to the central forge from the window, by
a button where they expect a release, without a command line or a pasted token.
- The project's page on its host offers *Bring it to central…* once the host's `main` is ahead of central, naming the
  commits it brings.
- It runs the backend's gathered push and says what reached central, or refuses in the backend's words (a token
  refused by the forge said as refused, never as a prompt that could not be shown).
- In class `guarded` the gate's release stays as it is; this is the step after it, for any class.

## Plan

- `CentralReleases` and `bringToCentralCommand` in `lib/src/app/central_release.dart`: the command is homed on the
  project menu (`Home.projectMenu`) and shown on the page (`ProjectHeader` in `lib/src/ui/machine_tree.dart`) while it
  can run; hidden where nothing says how the project stands at central. Which repositories it brings is the daemon's
  `Repository.central`/`ahead`, or, where the daemon says nothing or up to date, the host's own `org status` read
  (`host_progress.dart`), as the repository's row words it.
- `confirmBringToCentral` (`lib/src/ui/central_release_view.dart`) asks first, naming the commits; then
  `PoreloClient.pushToCentral` streams `PushToCentral(project, repositories)` with the repositories named, read
  leniently, its eight answers typed as `CentralPushRefusal` and worded from their parts; `NothingToPush` reads as
  central having them already. The machine is read again after the answer.
- Red first: `test/features/bringing_to_central.feature` (offered and brought after yes; nothing without yes; not
  offered at central; a refused token said as refused), `test/client/central_push_test.dart`,
  `test/client/mock_central_push_test.dart` and `test/app/central_release_test.dart`.

## Acceptance

- Against the mock: the button brings the commits and the page then says up to date; a refused token is said as
  refused. Against a host: central's `main` at the host's commit after one press.
