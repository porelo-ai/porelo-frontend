# F446 — The Stories Of A Project On A Planning Board

```json
{
  "$schema": "issue-1.json",
  "id": "F446",
  "title": "The Stories Of A Project On A Planning Board",
  "state": "Implementing",
  "size": "M",
  "priority": "Medium",
  "rank": 1,
  "blockedBy": [],
  "covers": "*Planning* shows a project's stories on a board, phases as columns with their states, read and watched from the planner."
}
```

**Why this size.** the board itself is the planner's package; the window's part is finding or starting the planner,
telling it each project's repository, the embedding and its words, and a test against the planner's mock mode.

**What must be true.** Under *Planning*, beside *Work* and *Needs you*, the operator sees every story of a project on a
board: one column per phase, the phase's states inside it, each story as a card in its state, the most important
first. The board is what porelo-planner says, read from it alone; the window works out no state of its own, and where
it reaches no planner it says why in words.

## What it builds against (in words)

- The board, a story, an issue and their screens are porelo-planner's Flutter package `porelo_planning` (path `screen`
  of its repository), embedded by a Git ref. Its `HttpPlanningSource` reads the board over the planner's REST API; an
  `application/problem+json` answer arrives as a `PlanningRefusal` named after the planner's refusal, and what the
  planner does not offer yet (moves, story work, reading rounds, the event stream) as `PlanningUnsupported`.
- The planner runs once per account on the loopback address, at a port it writes with a token to
  `porelo-planner/planner.json` in the account's runtime directory (`XDG_RUNTIME_DIR`), owner-only, beside a lock it
  holds while it runs; a second planner of the same account refuses to start. Its package installs it as
  `/usr/libexec/porelo/planner`, and a build of its own is called `porelo-planner`.
- Before a project's first read the planner is told the project's repository, `PUT /projects/{project}` with a clone
  URL; the package's source makes that call itself from what the window answers for the project, and the planner
  refuses a local path (`NotACloneUrl`).
- `porelo-planner --mock` serves a fixed board for the window's tests, only in a runtime directory other than the
  account's own, and `POST /mock/reset` restores it.

## Plan

- `lib/src/app/planner.dart`: `LocalPlanner`, the window's `PlanningClient` and its one provider. `reach()` reads the
  address file through `HttpPlanningSource.fromAddressFile`, which parses it. Only a missing address (`NoAddress`)
  means no planner runs: then it starts the planner from `/usr/libexec/porelo/planner` or `porelo-planner` on the path
  (only absolute path entries without a `..` segment), detached, with the runtime directory it reads, once per window,
  and polls for the address for at most 20 s. A candidate whose start fails with a `ProcessException` gives way to the
  next. Every other refusal, and any other failure while reading, is said and starts nothing; a relative runtime
  directory is refused before any start, and a blank one is none, for the start and the read alike. A reach that did
  not end in a planner can be tried again, and never starts a second planner. Its words for the place
  (`PlanningReach.notReached`): looking, not installed, cannot be reached (the package's refusal, such as an address
  file others may read), or started without an address in time. It lists the watched machines' projects but
  `default`, and answers each project's repository with the upstream of its own repository as a watched machine
  names it: the first remote clone URL, the machine shown first, else the first upstream at all; with none it
  refuses in words (`NoRepository`, its sentence also as the `detail` the board reads). `taskEvent` tells nothing:
  the planner takes no report of the window's tasks.
- `lib/src/ui/planning_embedding.dart`: `plannerPlanning` builds `EmbeddedPlanning` around the `LocalPlanner`; its
  start of story work answers `PlanningUnsupported` until the planner offers one.
- `lib/src/ui/shell.dart`: the planning place shows the planner's words while it is not reached, and the rail counts
  nothing until it is; *Refresh every machine now* tries `reach()` again while planning is not reached.
  `lib/main.dart` passes the planning into `PoreloApp` and reaches the planner after the first frame.
- `pubspec.yaml`: `porelo_planning` pinned to the planner's commit that brings its HTTP client.
- Tests: `test/app/planner_test.dart` (finding the address, telling the repository, the start once, the bounded wait,
  not installed, an address others may read or that is not JSON, a relative or blank runtime directory, a failure
  other than a refusal, a reach tried again, the next candidate, where the planner is looked for, the project's own
  upstream and a remote one preferred, the refusal's words on the board, and the watched machines through
  `plannedProjects`, `plannerProjectOf` and `LocalPlanner.of`); `test/ui/planning_placeholder_test.dart` (the place's
  words and the screen once reached, wired into `PoreloApp`, and the refresh that tries again);
  `test/client/planner_mock_test.dart` against `porelo-planner --mock` in a runtime directory of its own, counting
  every start and stopping each, skipped with its reason where no planner is installed.

## Acceptance

- With a planner running, the place shows its board, read through the planner's own client after the planner was told
  the project's own repository. Seen to fail: the read through a stand-in planner with the repository changed.
- With none running, the window starts one, once per window whatever asks, in the runtime directory it reads, and
  finds it by its address. Seen to fail: two starts when the reach is not kept.
- A started planner that writes no address within the bound is said, and never started again. Seen to fail: the
  reach that never ends.
- With no planner installed, nothing is started, and the place says so in words with no board and no count. Seen to
  fail: a candidate taken without its execute bit; the place without the reach's words; the rail counting.
- An address file other accounts may read, or one that is not the planner's, is refused in the package's words, and
  nothing is started. Seen to fail: every refusal taken for a planner that is not running.
- A project the planner refuses (`NotACloneUrl`) shows the refusal on the board; one the window cannot name a
  repository for (`NoRepository`) shows the window's sentence; nothing hangs.
- A remote clone URL any watched machine names is told before a local path. Seen to fail: the shown machine's local
  path told first.
- Against `porelo-planner --mock`, the window starts it, reads the mock board, and keeps the planner's refusal of a
  local path. Seen to fail: the start without the window's runtime directory.

## How it stands

- Built on the branch: the window finds or starts the planner, tells it each project's repository and embeds its
  screen; unit and widget tests and the test against the mock mode pass here, the last against the planner's own build
  of the commit pinned.
- The planner's package offers no event stream yet, so a change made elsewhere shows on the next read, not by itself;
  watching for changes and the lost-connection backoff come with the package.
- Moving stories, starting their work and deciding a reading round are refused until the planner offers them; the
  window's start of story work is the planner's to answer, then.
- A task on the board is opened only through a watched machine that is its provider; the planner names no machine for
  its tasks, so opening one from the board says the window does not know its machine.
- The window's own Dart planning mock was removed before this work; nothing of it is left.
- The reading of the window's part was taken: a refused address file starts nothing and keeps its words; the
  window's `NoRepository` carries its sentence where the board reads it; a remote clone URL is preferred; a blank
  runtime directory is none, for start and read alike; a failure other than a refusal is said; a failed reach can be
  tried again, also from the refresh, without a second start; a candidate that fails to start gives way to the next;
  path entries with `..` are skipped; and the tests count starts, assert the refusal's words and cover the watched
  machines. Three findings belong to the planner's package and went to it: the board's words ignore a refusal's
  description, so the planner's own refusals (`NotACloneUrl`, unreachable, timed out) still show by name; a failed
  board is never read again when the project's repository becomes known or changes; and the address file's
  directories, their owner and an absolute runtime directory are not checked when the address is read.
- The first build's tests were written after the code and shown red by breaking it; this round's tests were red
  first, except those for behavior that already held (a refused address file starting nothing, the watched
  machines' projects and their order), which were shown red by breaking the code.
- The planner's answers: it installs as `/usr/libexec/porelo/planner`; its live stream comes in the package after
  the planner's events work; starting story work comes later, so until then "does not offer starting story work
  yet" is right; a task's machine is to be reported by the window and kept by the planner, and until then the window
  is to use the machine it is connected to, which this branch does not do yet (see the bullet on opening a task).

## To be checked

- On the laptop with the planner's package installed: the window starts `/usr/libexec/porelo/planner` with the real
  runtime directory, and a project whose machine names a clone URL shows its board.
