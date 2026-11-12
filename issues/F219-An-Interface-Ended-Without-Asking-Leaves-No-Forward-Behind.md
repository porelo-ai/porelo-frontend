# F219 — An Interface Ended Without Asking Leaves No Forward Behind

```json
{
  "$schema": "issue-1.json",
  "id": "F219",
  "title": "An Interface Ended Without Asking Leaves No Forward Behind",
  "state": "Backlog",
  "size": "S",
  "priority": "Medium",
  "rank": 9,
  "blockedBy": [],
  "covers": "The ssh forwards this interface raised ended with it also when it ends without asking, and one left over found again by its socket at the next start."
}
```

**Why this size.** the forwards this interface raised found again by their socket at the next start, or ended with it, and
their tests.

**How it stands.** A bug.

**What must be true.** The ssh forwards this interface raises for a machine end with it, also where it ends without
asking: `q` in `flutter run`, a crash, a kill. At the next start a forward of this account already up for the same
socket is used or ended, never a second one raised beside it.

## Why

Closing the window takes every forward down: `_letGo` (`lib/src/ui/shell.dart`) answers the exit request with
`Machines.letGoOfTheTunnels` and `letGoOfTheForwards`.
`Tunnel._endOrphanedMaster` in `lib/src/app/tunnel.dart` ends an orphaned card control master at startup
when its configuration is absent or names the same login, leaving another login's master alone.
For non-card tunnels, `Tunnel.raise` in that file refuses a socket that already answers and leaves it
alone; it does not find and end the orphaned process. Neither it nor `_letGo` provides parent-watch or
PID cleanup after `SIGKILL`. `lib/src/app/login_forward.dart` also holds its ssh processes only in
memory and supplies no parent-watch or startup PID cleanup, so the promised cleanup is incomplete.

## Plan

- **Found again at the start:** before raising a forward for a machine, a running `ssh` of this account whose command
  line is one this interface writes (`-N -o BatchMode=yes … -o ControlPath=none -L <the machine's socket>:…`) is
  ended, so the socket is this run's alone; nothing else of the account is touched.
- **Ended with the interface where the platform allows it:** the forward started so that it ends when its parent
  does (on Linux a parent-death signal through a small wrapper), where that holds without a helper of its own.
- **Red first:** a forward left by an interface that was killed is ended at the next start, and only one runs for the
  socket after it.

## Acceptance

- After `q` in `flutter run` and a new start, one forward runs per watched machine.
- Closing the window still takes them all down, as today.
- Seen to fail: the test red with two forwards for one socket before the start ends the old one.
