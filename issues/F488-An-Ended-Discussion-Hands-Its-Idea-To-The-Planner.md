# F488 — An Ended Discussion Hands Its Idea To The Planner

```json
{
  "$schema": "issue-1.json",
  "id": "F488",
  "title": "An Ended Discussion Hands Its Idea To The Planner",
  "state": "Review",
  "size": "M",
  "priority": "High",
  "rank": 10,
  "blockedBy": ["F487"],
  "covers": "When a discussion task ends, the window reads the idea file it named from the machine it ran on and sends its content to the planner once, with the offer it came from; a file missing, too large or not an idea is said to the person, and nothing is sent."
}
```

**Why this size.** The end of a planner's task already reaches the planner (`WindowTaskChanges`,
`plannedEndKey`), but a path alone is worth nothing to it: the file is on the machine the task ran on, a host as
often as not, and the planner runs on the person's computer. Core hands the file's content from the ended task; the
window takes it, with a bound, and passes it on with the offer it belongs to in the planner's contract; tests for the
end, a missing file and a refusal.

**How it stands.** Built, in Review, against a stand-in of the planner's contract for ideas.
- A discussion this window starts for a planner's offer is kept in the settings (`Settings.rememberDiscussion`,
  stored as `discussions`) with its machine, container, offer, provider and project, and the end its task showed as
  it started, which is an earlier run's; it is forgotten with its task, as a planned offer is.
- `WindowTaskReports` looks at the kept discussions on each change of a machine or the planner. A new end of the
  agent whose result file stands *handed* is asked of the machine with `Result`, bounded at 64 KiB, read as a JSON
  object and sent with the discussion's offer as `POST /projects/{project}/ideas` (`lib/src/app/planner_ideas.dart`),
  to the planner of this account at the address and with the token its `planner.json` names, loopback only and never
  through a proxy. A planner that was not given the project since it started (`NoSuchProject`, as after its restart
  before the board is read again) is given it with its repository (`PUT /projects/{project}`) and asked once more, as
  the board's reads do. The planner's answer names the story; it is said in the window's log.
- Each end is handed once, also across restarts: the end is kept once the idea is saved, once the planner refused it
  for its faults, and once the discussion left none (no result file, one not handed, past the bound, no JSON object).
  A planner not running, or not able to save now, is said once and the idea goes once it answers; any other failure
  is said once in this window's life, and the next start of the window tries again.
- What went wrong is said where the window shows planning problems, on the project's board, with the planner's
  faults whole; the result file stays in the task either way, nothing lost.
- Tests: test/app/planner_ideas_test.dart (a stand-in planner), test/ui/window_task_reports_test.dart.

**What must be true.** A person who ends a discussion finds the idea in the planner, made into a story, without
copying a file by hand, also when the task ran on a rented host.

## Why

- Serves porelo-project's *Discuss an idea with an agent in the planner* (story ST319, porelo-project 845d526).
- The operator wants the file's path to go back to the planner when the task ends. The path names a file on the
  task's machine; only the window reaches both that machine and the planner.

## Plan

- `AgentEnded` (`lib/src/client/models.dart`) reads the result path Core names at the end.
- On the end of a discussion the window takes the file's content as Core hands it from the ended task (bounded at
  64 KiB, the planner's own bound) and sends it to the planner as `POST /projects/{project}/ideas` with
  `{"offer": <the discussion's offer id>, "idea": <the file read as a JSON object>}`, keyed by `plannedEndKey` so one
  end is sent once, also after a restart of the window. The planner answers 201 with the new story, or 422 naming each
  fault; a 422 is shown to the person with its faults and the idea's content kept for them, nothing lost.
- A file not there, past the bound, not a JSON object, or refused by the machine: no idea is sent; the person is told
  why where the discussion's end is shown, and the window's log ([F483](README.md#f483)) says so.

## To be checked

- The content is asked of the ended task with `Result`; the task's end names the file and how it stood.
- Tested against a stand-in of the planner's `POST /projects/{project}/ideas`, and once against porelo-planner 4c3e9c9
  in its mock mode: an idea saved as a story in state Idea with its issues, the same offer again answered with the
  same story, a malformed idea refused with its faults.
