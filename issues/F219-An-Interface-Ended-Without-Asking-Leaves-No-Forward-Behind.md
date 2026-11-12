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

**Why this size.** S: a record of each forward's pid and command line beside its endpoint, a sweep of a recorded one at
the next start in the tunnel and the login forward, SIGTERM and SIGINT watched, and their tests; Linux only.

**How it stands.** A bug.

**What must be true.** The ssh forwards this interface raises for a machine end with it, also where it ends without
asking: `q` in `flutter run`, a crash, a kill. At the next start a forward this interface left behind for the same
socket or port is ended and raised anew; an endpoint answered by anything else is still left alone.

## Why

Closing the window takes every forward down: `_letGo` (`lib/src/ui/shell.dart`) answers the exit request with
`Machines.letGoOfTheTunnels` and `letGoOfTheForwards`. Nothing ends them on any other end: the window watches no
signal, and no forward is tied to the window's life. After a kill:

- A machine without a card is shown down at the next start: `Tunnel.raise` (`lib/src/app/tunnel.dart`) finds its
  socket answered by the leftover ssh and refuses it ("something is already serving …, and it was left alone"), while
  that ssh still serves.
- A homeserver or login forward (`lib/src/app/login_forward.dart`), held only in memory and raised again at every
  start from the settings, is refused as "Port N is already in use".

Card control masters are already ended at the start by `Tunnel._endOrphanedMaster`; they are not part of this issue.

## Plan

- **A record of each forward:** right after its ssh starts, the interface writes beside its endpoint (the socket's
  path, or the state directory keyed by the port) the pid and its `/proc/<pid>/cmdline`.
- **Found again at the start:** before the "already serving" refusal in `Tunnel.raise`, and before the port check in
  the login forward, a recorded pid that is alive, runs as this account and still has the recorded command line is
  ended, and the start waits until its endpoint stops answering. An endpoint with no record of ours, or whose pid now
  runs another command line, is left alone as today. A command-line pattern is not enough: a `host` machine's forward
  and a login forward with its own ssh options write other ones.
- The sweep reads `/proc` through a seam of its own, not through the tunnel's `run:`, so the existing fakes are
  unchanged. The login forward's `Process.start` gets a seam (`startLoginForward`, like `raiseLoginForward`), landed
  first without a change of behaviour.
- **Ended on SIGTERM and SIGINT:** `lib/main.dart` watches both, lets go of the tunnels and forwards, and exits (a
  watched signal no longer ends the process by itself).
- No parent-death signal: on Linux it fires when the thread that started the child ends, and Dart starts processes
  from pool threads that end when idle, so forwards would die at random.
- Linux only. Windows has no `/proc` and only SIGINT; a job object that ends its children would be its own issue.
- **Red first:** in `test/app/tunnel_test.dart`, a forward a killed run left at the socket is ended and the machine
  raised (today: down, "already serving", the old one alive); an answering socket with no record of ours is still left
  alone; a recorded pid that now runs another command line is not ended. In `test/app/login_reply_test.dart`, a login
  forward a killed run left on the port is ended and raised again (today: "already in use").

## Acceptance

- After `q` in `flutter run`, or a kill of the window, and a new start, each watched machine is up with one forward,
  and each homeserver forward is raised.
- Closing the window still takes them all down, as today.
- An endpoint served by anything this interface did not record is left alone.
- Seen to fail: the tests red with the machine refused while the old forward still runs.

## To be checked

- Which signal `q` in `flutter run` sends a Linux desktop app.
