# F448 — A Story And An Issue Opened From The Board

**Status:** Rework: the story and the issue are read from the planner, the local app that now holds them, instead of the
machine's daemon, which knows them no more; an issue's screen also shows its sub-issues. The window's planning mock
(`lib/src/mock/planning_data.dart`, `planning_moves.dart` and what they serve) moves into the planner, which gets a mock
mode serving this board; the window's planning tests start the planner in that mode instead of a mock in the window, and
the Dart mock stays until the planner's mock mode exists. To be built once the planner's API is served.
**Size:** M - two screens with a breadcrumb, their reads of the contract, one issue moved alone, the web links opened,
and a feature file.

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
- A move of one issue to a waiting or closed state, as the board's move of a story.

## Plan

- `lib/src/app/shell_model.dart`: the planning place gains the story and the issue opened (`ShellPlace` with
  `story`/`issue`), so the breadcrumb, the back key and the finder reach them as other places.
- `lib/src/ui/planning_story_view.dart` (new): head (id, priority chip, state, *Open story*), *What it gains*, *Your
  test*, the issues as a table (issue, title, repository, size, state) with the share in Review or Finished, *No issues
  yet* where none; each issue row has a state menu that moves that issue alone, pending and saved as on the board.
- `lib/src/ui/planning_issue_view.dart` (new): state, repository, title, size, blocked by, story (a link back), *Who
  builds it* (the repository, and the task at work on it from the story's work, opening that task), *What must be
  true*, the reader's last findings (blocking ones first and marked, notes after, each with file and line where
  given), *Open issue*.
- *Open story* and *Open issue* go through `openLink` (`lib/src/app/links.dart`) with the link the machine gave, and
  only an `https` link is offered, as *How this login works* is.
- Kept current from the board's watch: a story or issue changed elsewhere changes on its open screen.
- `test/features/planning_story.feature`: open a story and one of its issues, the breadcrumb back, the web link offered
  and opened, an issue moved alone and saved. First red: a link the machine did not give offered as *Open issue*.

## Acceptance

- Story and issue screens show what the machine says of them, and a change elsewhere reaches an open screen.
- The breadcrumb leads back to the board at the place it was left (filter, folds and scroll kept).
- *Open story*/*Open issue* open exactly the machine's link, and are not offered without one.

## Open questions

- None.

## To be checked

- Nothing yet; the names once the daemon's part is served.
