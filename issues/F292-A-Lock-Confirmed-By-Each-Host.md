# F292 — A Lock Confirmed By Each Host

```json
{
  "$schema": "issue-1.json",
  "id": "F292",
  "title": "A Lock Confirmed By Each Host",
  "state": "Idea",
  "size": "M",
  "priority": "Low",
  "rank": 23,
  "blockedBy": [],
  "covers": "*Lock* and *Let back in* shown as under way on each host until `org status` there confirms them; adding counts as done once signed."
}
```

**Why this size.** the state of a *Lock* or a *Let back in* under way, per host, read from `org status` and kept on a
person's row; built after the foo test.

**Severity.** Medium.

**What must be true.** After *Lock* or *Let back in*, the window shows the change as under way on each host until
`org status` there confirms it, and says so if the confirmation stays out, also when the host is not running. Adding
a person counts as done once signed, with no confirmation by a host.

## Why

`_MemberRowState._lock` in `lib/src/ui/organization_project_pages.dart` writes the signed change to the organization
and shows the person as locked or not from the organization alone. The menu says *Lock* or *Unlock*; *Unlock* is the
*Let back in* meant here. A host follows the organization by itself, so a person can still reach a host that has not
followed yet, or is not running, while the window already says *locked*. A lock is what a person relies on, so its
state on each host is shown. An added person only gains an account at the next follow, which keeps nobody out.

## The shape

- After a signed *Lock* or *Let back in*, each host of the project shows the change as under way.
- `org status` on a host confirms the change there; `SshHostProgress` in `lib/src/app/host_progress.dart` reads it.
- Where the confirmation stays out, the window says so and names the host, also when the host is not running.
- *Add* counts as done once signed.

## Plan

- `HostProgress` (`lib/src/app/host_progress.dart`) answers a person's state per host; a project member's row in
  `lib/src/ui/organization_project_pages.dart` shows it.
- **Red first:** with a stand-in for `org status`, a *Lock* stays under way until the host names the person as locked,
  and a host that does not answer is said to be unconfirmed.

## Acceptance

- *Lock* and *Let back in* show as under way on a host until `org status` there confirms them, and never count as
  confirmed by the signed change alone. Seen to fail: a stand-in that does not yet name the person.
- A host that does not answer, or is not running, is named as not having confirmed. Seen to fail: a stand-in that
  refuses the connection.
- *Add* counts as done once signed, with no read of a host. Seen to fail: a test that an add reads `org status`.

## To be checked

- `org status` is read as root, which only a Machine Admin may. How does a Project Admin who is no Machine Admin learn
  the host's word? (Agent Frontend's)
- `HostProgress.locked` reads `persons` with `login` and `purge_on`, with no project. Does `org status` tell a person
  locked in one project from one locked in another, and a person let back in from one the host has not followed for
  yet? (Agent Frontend's)
