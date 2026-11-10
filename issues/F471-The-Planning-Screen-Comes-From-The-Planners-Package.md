# F471 — The Planning Screen Comes From The Planner's Package

**Status:** Review.
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
- **The window keeps no planning code of its own** (the operator, 2026-11-10): `client/planning.dart`, the planning
  views and models, and the planning mock (`mock/planning_data.dart`, `mock/planning_moves.dart` and the planning
  parts of `mock/mock_daemon.dart` and `mock/machine.dart`) are deleted here; the window only embeds `porelo_planning`
  and implements its hooks. The mock's board goes into the package as its fake client, so the package's tests, its
  example and the window's tests read the same stories until the planner's mock mode serves them.
- **Tests:** the planning unit and widget tests move with the code, against that fake client. The window keeps the
  feature files that walk the embedding (`planning_board.feature`, `planning_moves.feature`,
  `planning_story.feature` and `story_work.feature`), run against the package's fake client and, once it exists,
  against the planner's mock mode.
- **Steps:**
  1. Agreed: the module's place and name, with Agent Planner (below).
  2. Cut the package out in porelo-planner, with every moved test green there.
  3. Embed it in the window and delete the window's planning code and its mock here.
  4. Every window test green, and the window started locally from porelo-planner's checkout.
  5. Hand it over to Agent Planner.

## How it stands

- **Step 1 was built inside this repository first.** The planning screen became the Flutter package
  `packages/porelo_planning` (Dart package `porelo_planning`), which the window embedded with
  `path: packages/porelo_planning`, as it embeds `packages/porelo_host`. The package imports only Flutter and
  Dart, so the directory can move as it is into porelo-planner's `screen/`.
- **What moved into the package:** the planning records (`lib/src/models.dart`), the board, its moves and the
  boards across providers (`planning_board.dart`), the detail reads, the Start work form and the reading decision
  (`story_work.dart`), and every planning view, the Start work dialog and the Needs-you entry under `lib/src/ui/`.
  `PlanningStyle` and a small `Space` moved too; colors come from the window's theme through `Theme.of(context)`.
- **The package's face** (`lib/porelo_planning.dart`): `PlanningScreen(boards, host, startTask, taskChanges,
  agents)`, with `PlanningBoards(client)` built by the window, since the rail count, Needs you, the command
  palette and the leave guard read the boards while another place is shown. `PlanningClient` lists the providers
  of planning, the current provider, the chosen project, and has `taskEvent`. `PlanningSource` is one provider's
  calls. A refusal reaches the package as `PlanningRefusal`, a call not offered as `PlanningUnsupported`.
  `PlanningAction` is what the window wraps in its own `Command`; `PlanningBoards.hasPendingMoves` is the leave
  guard's question; `PlanningBoards.needsYou` lists the Needs-you entries, and `StoryWorkAttentionView` shows one.
  `PlanningHost` is where the screen stands, how it moves and what it opens, kept in the window's history.
- **The package's stand-in** (`lib/planning_fake.dart`, apart from the screen's library): `MockPlanningSource`
  holds the mock's whole board per project with the moves, Start work and reading answers the mock daemon gave,
  refusing in the daemon's words (`mockRefusal`); `MockPlanningClient` lists providers a test supplies;
  `mockStartTask` starts work on the stand-in.
- **The package already meets the frame of porelo-planner's `screen/`:** the same `analysis_options.yaml`,
  `flutter_test` and `flutter_lints` as its only dev dependencies, `dart format --set-exit-if-changed lib test`,
  `dart analyze --fatal-infos` and `flutter test` all clean.
- **The window keeps no planning of its own.** The daemon's planning calls, `FleetBackend`'s planning methods,
  the daemon adapter and the mock daemon's planning are gone. `PoreloApp` takes an `EmbeddedPlanning` (a
  `PlanningClient` and how a start reaches it); `lib/src/ui/planning_embedding.dart` holds the window's place,
  task and agent hooks. A window given none, as the real window is until `PlanningClient.http` exists, says on
  its Planning place in one line that planning comes from porelo-planner and is not reached yet; the rail keeps
  the place without a count, and Needs you, the command palette and the leave guard ask nothing of planning.
- **Tests:** the feature files stay in the window and pass unchanged, against the package's stand-in, which the
  test world gives the window per machine. The board, detail, start, reading and screen tests run in the package
  against the stand-in. The window keeps its own: the placeholder, the Needs-you rows from planning, the planning
  place in its navigation, the started run it opens, and one stream lifecycle test that needs `fake_async`, which
  the frame's dev dependencies leave out.
- **Step 2: the package lives in porelo-planner.** The directory moved as it is into porelo-planner's `screen/`, on
  the module frame Agent Planner built (its `pom.xml` under the profile `all`, the CI job, the pinned Flutter); there
  `./mvnw -B -s settings.xml -Pall -pl screen verify` is green with the package's 133 tests, and its citation check
  names the stand-in's made-up stories as exempt. The window dropped `packages/porelo_planning` and its build steps
  and takes `porelo_planning` by `git:`, the commit's full id and `path: screen`. Against porelo-planner's checkout,
  through an uncommitted `pubspec_overrides.yaml` that keeps the `xterm` override beside it, the whole window suite
  passes (3,660 tests, 26 skipped), and the window started on a hidden display ran 30 seconds with no error.
- **Handed over:** porelo-planner's main carries the screen (its commit's id changed on the rebase, its content did
  not); the window pins that id, and `flutter pub get` from GitHub left the lock as committed. Agent Planner owns
  the package from here. The planner's
  own client over REST and Server-Sent Events is the rework of [F446](README.md#f446), not this issue.

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
