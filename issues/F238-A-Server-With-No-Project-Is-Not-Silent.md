# F238 — A Server With No Project Is Not Silent

**Status:** Accepted.
**Size:** XS - a host prepared with no project left out of *Needs you*'s silent machines, and its row saying "no project yet".

**What must be true.** A server prepared with no project, which by design has no project account and no daemon, is not raised under *Needs you* as *Not answering*. Its row in *Machines* says "No project yet", with *Register a project* in its menu as today.

## Why

Operator's walk 23 on walk9server, network 1, after setup and the VPN (2026-10-30): *Needs you* showed "walk9server · walk9server — Not answering: This machine cannot be reached, and anything it is asking waits unseen. Cannot reach walk9server: This server is prepared without a project account or daemon. Register a project from its menu." Nothing there waits on the person: no daemon is the expected state of such a host. The rows come from `lib/src/app/attention.dart` (the loop over `silent`), which counts every machine its fleet cannot reach. The words come from `Machine.whyNotReachableOn` in `lib/src/app/machines.dart` (`kind == 'host'` with no socket).

## Plan

- A machine of kind `host` with no socket (the server-only case `whyNotReachableOn` names) is not one of the silent machines and is not tried as a fleet. *Needs you* shows no row for it.
- Its row in *Machines* shows "No project yet" instead of an unreachable state. Its menu keeps *Register a project* and the host's other commands.
- Once a project is registered and the machine has a socket, it counts as any other machine again.
- **Red first:** a test that a server-only host yields no silent attention row and its *Machines* row says "No project yet"; and that a host with a socket that does not answer still does.

## Test

Only the change: the test above, plus the attention and *Machines* row tests. No VM run.
