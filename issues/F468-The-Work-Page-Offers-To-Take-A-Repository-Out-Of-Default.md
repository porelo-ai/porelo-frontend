# F468 — The Work Page Offers To Take A Repository Out Of Default

```json
{
  "$schema": "issue-1.json",
  "id": "F468",
  "title": "The Work Page Offers To Take A Repository Out Of Default",
  "state": "Review",
  "size": "S",
  "priority": "Medium",
  "rank": 16,
  "blockedBy": [],
  "covers": "The work page offers to take a repository out of `default` once a project of the organization names it."
}
```

**Why this size.** one offer on the work page where the daemon says a repository of `default` is named by a project of
the organization, its removal asked and said, and its test.

**Blocked by** Porelo's offer to remove a repository from the project `default` once a project of the organization names
it, and how the daemon says so.

**What must be true.** A repository in the project `default` that a project of the organization now names is offered
for removal from `default` on the work page: the person sees that its next task starts in that project, and removes
it from `default` in one step there. A running task keeps its project; `default` itself is never offered for removal.
- Serves porelo-project's *Work starts without a project* (story ST30): its shape's point 6, "a repository stays in
  `default` until removed there, or until a project of the organization names it; then that project takes new
  tasks, and the offer to remove it from `default` is made", for the window's part.

## Plan

- Read what the daemon says of a `default` repository that a project names (today `porelo project default list`
  says so in words; the window needs it as a field of its list of `default`'s repositories, Porelo's part).
- `lib/src/ui/work_page.dart`: beside such a repository, the line that its next task starts in the naming project,
  and *Take it out of default…*, which asks once and calls Porelo's removal; a refusal said in place.
- Red first: a widget test of the work page with a `default` repository the daemon says a project names; the offer is
  shown, the removal is asked once and sent; a running task's row keeps its project.

## How it stands

- Porelo's part stands: `DefaultRepositories` answers each repository's `claimedBy`, the project that names it, and
  `LeaveDefault` takes one out on the person's word, refused with `DefaultRepositoryInUse` while a task of `default`
  works on it.
- The work page (`lib/src/ui/work_page.dart`) shows, above the work, each repository of `default` a project names on
  each machine answering now (`ClaimedDefaultRows`, `lib/src/ui/claimed_default_rows.dart`): that its next task starts
  in that project, and *Take it out of Default…*, asked once, then sent as `LeaveDefault`
  (`FleetBackend.leaveDefault`); what came of it is said in place, a task still on it named. A Porelo without
  `LeaveDefault` is asked `RemoveFromDefault`. A running task keeps its project; `default` itself is never offered.
- The Default dialog keeps its own *Take it out of default* as before.
- Tests: test/ui/claimed_default_rows_test.dart (offered only where a project names it, asked once and sent once,
  a refusal said, nothing where none is named) and test/client/default_project_test.dart (LeaveDefault, and
  RemoveFromDefault for an older Porelo), each seen red first.

## Acceptance

- Against the mock: the offer shows only for a named repository, the removal reaches the daemon once, and a refusal
  is said; the test seen red first.
