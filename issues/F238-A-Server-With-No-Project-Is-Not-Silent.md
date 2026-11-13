# F238 — A Server With No Project Is Not Silent

```json
{
  "$schema": "issue-1.json",
  "id": "F238",
  "title": "A Server With No Project Is Not Silent",
  "state": "Idea",
  "size": "XS",
  "priority": "Low",
  "rank": 30,
  "blockedBy": [],
  "covers": "A server prepared with no project not raised as *Not answering*; its row says \"No project yet\"."
}
```

**Why this size.** a host prepared with no project left out of *Needs you*'s silent machines, and its row saying "no project yet".

**How it stands.** Held: wizard changes wait until the whole flow has been gone through again.

**What must be true.** A server prepared with no project, which by design has no project account and no daemon, is not raised under *Needs you* as *Not answering*. Its row in *Machines* says "No project yet", and its way on is *Put it on a machine…* on a project's row under *Organization*.

## Why

`Machine.whyNotReachableOn` in `lib/src/app/machines.dart` already says "This server is prepared without a
project account or daemon." `Attention.silent` in `lib/src/app/attention.dart` still includes such a host;
`notConnectedYet` describes a host that has never answered as "You have not connected to this machine yet".
`MachinesPage._row` in `lib/src/ui/machines_page.dart` uses "not connected yet" until a fleet has answered,
rather than the promised "No project yet". No daemon is the expected state of a projectless server.

Projects are placed through *Put it on a machine…* on the project row in `OrganizationPage`
(`lib/src/ui/organization_page.dart`).

## Plan

- A machine of kind `host` with no socket (the server-only case `whyNotReachableOn` names) is not one of the silent machines and is not tried as a fleet. *Needs you* shows no row for it.
- Its row in *Machines* shows "No project yet" instead of an unreachable state. Its menu keeps the host's other commands.
- Once a project is on it and the machine has a socket, it counts as any other machine again.
- **Red first:** a test that a server-only host yields no silent attention row and its *Machines* row says "No project yet"; and that a host with a socket that does not answer still does.

## Test

Only the change: the test above, plus the attention and *Machines* row tests. No VM run.
