# F488 — An Ended Discussion Hands Its Idea To The Planner

```json
{
  "$schema": "issue-1.json",
  "id": "F488",
  "title": "An Ended Discussion Hands Its Idea To The Planner",
  "state": "Idea",
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

- Core: whether the content travels in the task's end or is asked of the ended task, and its bound.
