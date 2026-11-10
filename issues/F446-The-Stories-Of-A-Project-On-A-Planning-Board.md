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
  address file through `HttpPlanningSource.fromAddressFile`, which parses it; where none is there it starts the
  planner from `/usr/libexec/porelo/planner` or `porelo-planner` on the path (never a relative path entry), detached,
  with the runtime directory it reads, once per window, and polls for the address for at most 20 s. Its words for the
  place (`PlanningReach.notReached`): looking, not installed, cannot be reached (the package's refusal, such as an
  address file others may read), or started without an address in time. It lists the watched machines' projects but
  `default`, and answers each project's repository with the upstream of its own repository as a watched machine
  names it, the machine shown first; with none it refuses in words (`NoRepository`), shown on the board.
  `taskEvent` tells nothing: the planner takes no report of the window's tasks.
- `lib/src/ui/planning_embedding.dart`: `plannerPlanning` builds `EmbeddedPlanning` around the `LocalPlanner`; its
  start of story work answers `PlanningUnsupported` until the planner offers one.
- `lib/src/ui/shell.dart`: the planning place shows the planner's words while it is not reached, and the rail counts
  nothing until it is; `lib/main.dart` passes the planning into `PoreloApp` and reaches the planner after the first
  frame.
- `pubspec.yaml`: `porelo_planning` pinned to the planner's commit that brings its HTTP client.
- Tests: `test/app/planner_test.dart` (finding the address, telling the repository, the start once, the bounded wait,
  not installed, an address others may read, where the planner is looked for, the project's own upstream);
  `test/ui/planning_placeholder_test.dart` (the place's words and the screen once reached, wired into `PoreloApp`);
  `test/client/planner_mock_test.dart` against `porelo-planner --mock` in a runtime directory of its own, skipped with
  its reason where no planner is installed.

## Acceptance

- With a planner running, the place shows its board, read through the planner's own client after the planner was told
  the project's own repository. Seen to fail: the read through a stand-in planner with the repository changed.
- With none running, the window starts one, once per window whatever asks, in the runtime directory it reads, and
  finds it by its address. Seen to fail: two starts when the reach is not kept.
- A started planner that writes no address within the bound is said, and never started again. Seen to fail: the
  reach that never ends.
- With no planner installed, nothing is started, and the place says so in words with no board and no count. Seen to
  fail: a candidate taken without its execute bit; the place without the reach's words; the rail counting.
- An address file other accounts may read is refused in the package's words, and nothing is started.
- A project the planner refuses (`NotACloneUrl`) or the window cannot name a repository for (`NoRepository`) shows the
  refusal by name on the board; nothing hangs.
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

## To be checked

- On the laptop with the planner's package installed: the window starts `/usr/libexec/porelo/planner` with the real
  runtime directory, and a project whose machine names a clone URL shows its board.
