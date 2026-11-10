# F471 — The Planning Screen Comes From The Planner's Package

**Status:** Implementing (the operator, 2026-11-10).
**Size:** M - the planning screen, its models and its tests cut out of the window into a Flutter package of
porelo-planner, with no change in behavior, and the window embedding it through a few hooks.

**What must be true.** The window's *Planning* place shows the same board, story and issue screens and *Start work*
as today, but their code comes from a Flutter package in porelo-planner. That package is tested there without
porelo, and the window only embeds it and tells it where the planner listens.
- The operator decided this on 2026-11-10: the package is a Maven module of porelo-planner of its own. Maven builds
  it only as part of the whole build, and Agent Planner owns it. Agent Frontend moves the code there, agreed with
  Agent Planner on the module's place and name, and hands it over once the window starts locally with the code from
  porelo-planner's checkout.
- It is the first step of the rework of [F446](README.md#f446), [F447](README.md#f447), [F448](README.md#f448) and
  [F449](README.md#f449): their new source, the planner over REST and Server-Sent Events, is then written once, in
  the package.

## Plan

Read in today's code (porelo-frontend 3b63f9a7):
- **What moves into the package:** about 5,100 lines of code and 6,400 lines of tests.
  - Moves as it is: `client/planning.dart`'s models (cut out of the `porelo_client` library), `app/planning_detail.dart`,
    `ui/planning_issue_view.dart` and `ui/planning_detail_widgets.dart`.
  - Moves with its hooks changed: `app/planning_board.dart`, `app/story_work.dart`, `ui/planning_view.dart`,
    `ui/planning_story_view.dart`, `ui/story_work_dialog.dart`, `ui/story_work_attention.dart`, and the planning
    parts of `app/commands.dart`.
- **What the window gives the package instead of its own parts:**
  - its theme, through `Theme.of(context)`; the spacing and `PlanningStyle` move into the package.
  - Its actions go out as plain objects that the window wraps in its own `Command`s, so the command menu and palette
    still list them.
  - The navigation between board, story and issue stays in the package; the window keeps its place in the rail and
    its history, and the guard against leaving with unsaved moves.
  - A `startTask` callback that the window answers with porelo's Start.
  - The agents and models a start may choose.
  - The ended tasks from Watch.
- **What goes away rather than becoming a hook:** today a board is read from each machine's daemon through
  `PlanningBoards`, `FleetBackend`, `FleetModel` and `Machines`. With one local planner that coupling goes; until the
  planner's API exists, the package reads through a client interface with today's models, and the window answers it
  from the daemon as now.
- **Embedding:** a git dependency with a fixed ref and `path: screen` into porelo-planner, as `guided_walk` is embedded.
  While the change is built, the window starts against the package in porelo-planner's checkout through an
  uncommitted `pubspec_overrides.yaml`.
- **Tests:** the planning unit and widget tests move with the code, against a fake of the package's client. The
  window keeps the feature files that walk the embedding: `planning_board.feature`, `planning_moves.feature`,
  `planning_story.feature` and `story_work.feature`.
- **Steps:**
  1. Agreed: the module's place and name, with Agent Planner (below).
  2. Cut the package out in porelo-planner, with every moved test green there.
  3. Embed it in the window and delete the moved code here.
  4. Every window test green, and the window started locally from porelo-planner's checkout.
  5. Hand it over to Agent Planner.

## Agreed with Agent Planner (2026-11-10)

- **Place and names:** the directory `screen/` at porelo-planner's root, a Maven module `porelo-planner-screen` built
  only under the profile `all`, the Dart package `porelo_planning`, with Flutter pinned as the window pins it.
  porelo-planner's CI gets a job with that Flutter beside its JDK. The window embeds it with `git:`, a tag and
  `path: screen`.
- **The package's face:** `PlanningScreen(client, startTask, taskChanges, agents)`.
  - `PlanningClient` is an interface of the package; `PlanningClient.http(baseUrl, token)` is the planner's
    REST/SSE one. Until that exists, the window passes a client that answers from today's daemon.
  - `PlanningAction` is what the window wraps in its command menu.
  - `hasPendingMoves` is for the leave guard.
  - A `Listenable` of Needs-you entries comes with their widget.
- **Address and token:** the planner writes them into a file only its user may read, in the user's runtime
  directory; the window reads it and builds the client.
- **Task changes:** the window reports each change of a task it started (started, ended, stopped) through
  `client.taskEvent`; `taskChanges` is only what the screen shows of a run.
- **The theme:** the package has none of its own; its colors come from the window's theme.

## Acceptance

- The window's *Planning* behaves as before the move: every planning test, moved or kept, green.
- The package's tests run in porelo-planner without porelo.
- The window starts locally with the package from porelo-planner's checkout, and no planning code stays in the window
  but the embedding.
