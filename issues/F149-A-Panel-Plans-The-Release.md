# F149 — A Panel Plans The Release

```json
{
  "$schema": "issue-1.json",
  "id": "F149",
  "title": "A Panel Plans The Release",
  "state": "Idea",
  "size": "-",
  "priority": "Low",
  "rank": 41,
  "blockedBy": [],
  "covers": "A panel that shows and edits a project's release plan by dragging issues into sprints and their functions, writing only the plan file."
}
```

**What must be true.** The interface has a panel that shows a project's release plan as
`porelo-project`'s plan page does for `plan/<release>/plan.yml` - each sprint's bar by its issues' states, each function tested or not - and lets the
person search every issue of every repository of the project (by state, size and repository, with
those in no sprint shown apart), and place an issue in a sprint and one of its functions, add and
order sprints and functions, by dragging. Saving writes only the plan file, as a commit in the
project's own repository; an issue's state is never written, since it stays its repository's.

## Why

A release is planned by grouping issues into sprints of functions to test, in the interface where the work is
started, rather than in a plan file edited apart. Built for any project whose repositories keep
issues in the same form, not only Porelo's own.
