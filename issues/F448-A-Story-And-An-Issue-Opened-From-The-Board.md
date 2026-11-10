# F448 — A Story And An Issue Opened From The Board

```json
{
  "$schema": "issue-1.json",
  "id": "F448",
  "title": "A Story And An Issue Opened From The Board",
  "state": "Implementing",
  "size": "M",
  "priority": "Medium",
  "rank": 3,
  "blockedBy": [],
  "covers": "A story's and an issue's screen with a breadcrumb and *Open story*/*Open issue*, an issue moved alone and its sub-issues shown."
}
```

**Why this size.** two screens with a breadcrumb, their reads of the contract, one issue moved alone, the web links opened,
and a feature file.

**Why it is in Rework.** The story and the issue are read from the planner, the local app that now holds them, instead
of the machine's daemon, which knows them no more; an issue's screen also shows its sub-issues. The window keeps no
planning mock of its own: its screen tests use the package's stand-in source
(`package:porelo_planning/planning_fake.dart`), and its test against the planner starts the planner's own mock mode
(`--mock`).

**What must be true.** A click on a card opens the story: its title, priority, state, what it gains, the operator's
test, its issues with their state and how many are in Review or Finished, and the work running on it; a click on an
issue opens it. Each screen has a breadcrumb back (*Planning › ST… › F…*) and *Open story* or *Open issue*, which shows
the item's own web page in the browser.

## What it builds against (in words)

- An issue in or after Reading carries the reader's last findings, each numbered, `blocking` or `note`, with its
  text and, where given, file and line.
- A story read alone, with its issues; an issue read alone: id, repository, title, state, size, blocked by, its story,
  what must be true, and its web link. Both carry the revision. Who builds an issue is its repository, and the task
  working on it where the story's work names one.
- An issue read alone also names its sub-issues by id.
- A move of one issue to a waiting or closed state, as the board's move of a story.

## How it stands

- The story's and the issue's screens are the planning package's (`PlanningStoryView` and `PlanningIssueView` in
  `porelo_planning`, pinned in `pubspec.yaml`), with their breadcrumb, *Open story*/*Open issue* offered only for an
  `https` link the planner gave, an issue moved alone and saved with the board's moves, the reader's findings blocking
  first, and the story's work opening its task. The window builds none of it.
- The window's part is in place and tested against the package's stand-in source: `ShellPlanningHost`
  (`lib/src/ui/planning_embedding.dart`) keeps the story and the issue opened as the window's own place (`ShellPlace`
  with `story`/`issue`, and the provider and project in `planningSource`/`project`), so Escape leads from the issue to
  its story and then to the board with its filter, folds and scroll kept, and the rail shows Planning; its `openLink`
  is the window's opener (`lib/src/app/links.dart`); a task named by the story's work opens in the window
  (`WindowTaskChanges`); the finder lists every story and issue (`planningCommands` in `lib/src/app/commands.dart`,
  from the package's `planningActions`) and opens them as the same place, and their web pages through the same opener.
- Through the window's planner (`LocalPlanner`, `lib/src/app/planner.dart`) a story, its issue list and an issue are
  read from the planner over HTTP by the package's `HttpPlanningSource`; the test against the planner's mock mode is
  skipped where the planner is not installed.
- Missing in the package, not built in the window: an issue's sub-issues, which the planner serves on an issue read
  alone (`subIssues`) but which the package neither reads nor shows; and an issue moved alone against the planner,
  since its HTTP source refuses saving moves as not offered yet (the planner's issue that brings moves and story work
  into the screen package). Both stand once the package is pinned at a version that has them.
- Also missing in the package and the planner, not built in the window: a story's work, which the planner answers as
  always absent (`work` is null) and the package's HTTP source refuses to read (`getStoryWork`); and an issue's last
  findings and sub-agents, which the planner's issue read does not carry and the HTTP source refuses to read
  (`getPlanningIssue`). Against the real planner the story screen shows no work and the issue screen no reading, until
  both are served and the package is pinned at a version that reads them.
- The planner's issue read names no story of its own; at this pin the package needs none, since it finds the issue's
  story on the board and otherwise keeps the story the issue was opened from, so the parent link and the breadcrumb
  stand. An issue row's web link is served: the planner's issue rows carry `link`.
- Escape on a story leads to the board however the story was reached, from Work, from its issue's breadcrumb or from
  another story through the finder, since the window steps to the parent place (`ShellModel.close`) rather than back
  through a history; `test/ui/planning_finder_test.dart` asserts the board shown in Planning, seen red with Escape
  leaving for Work and with Escape retracing the place before.
- The provider and the project stay with an open story (`ShellPlanningHost.place` and `go`), and the finder's places
  carry them through the package's actions; dropping them turns the planning story scenarios red, the provider
  fallback among them. *Open story*/*Open issue* go through the window's opener, so a replaced `openLink` is used;
  bypassing it turns the finder's and the screens' link tests red.
- `test/client/planner_mock_test.dart` asserts a story and one of its issues as the planner's mock board holds them:
  the story's title, priority, description, link and revision, the issue list complete with the issue's state and
  link, and the issue's repository, title, state, size, blockers, link and what must be true; a read stripped to the
  ids goes red. Run against a local planner build on the path; it stays skipped where no planner is installed.

## Plan

- No production code in the window: the screens, the breadcrumb, the links and the moves are the package's.
- `test/ui/planning_finder_test.dart` (new): from Work, the finder opens a story and the back key leads to the board
  shown in Planning; it opens an issue and the back key leads to its story, then the board; the back key on a story
  reached through its issue's breadcrumb, or found from another story, leads to the board; it opens an issue's web page
  through the window's opener at the machine's address.
- `test/client/planner_mock_test.dart`: a story, its issue list and one of its issues read alone through the window's
  planner in mock mode, with the fields the planner gives; bound to Linux, as the planner is.
- `test/features/planning_story.feature` keeps the screens as the window embeds them: a card opens its story, an issue
  its reading, the breadcrumb and Escape back with the board's place kept, the exact web links and none without one,
  the watch refreshing an open screen, refusals in their own words, and an issue moved alone and saved.
- Once the package shows sub-issues, saves moves, and reads story work and an issue's reading through the planner, the
  pin moves and a scenario per behavior is added here.

## Acceptance

- A story and an issue opened from the board, an unfolded card or the finder are the window's place: the breadcrumb and
  Escape lead back to the story and then to the board at the place it was left (filter, folds and scroll kept), and
  the rail shows Planning.
- *Open story*/*Open issue*, on the screen and in the finder, reach exactly the planner's link through the window's
  opener, and are not offered without an `https` one.
- Against the planner's mock mode, a story and an issue are read alone through the window's planner.
- An issue's sub-issues are shown, an issue moved alone is saved, a story shows its work and an issue its last reading
  through the planner, once the planner serves and the package reads them.

## Open questions

- None.

## To be checked

- The mock-mode test on a machine with the planner installed, and the screens against a live planner.
