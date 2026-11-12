# F219 — An Interface Ended Without Asking Leaves No Forward Behind

```json
{
  "$schema": "issue-1.json",
  "id": "F219",
  "title": "An Interface Ended Without Asking Leaves No Forward Behind",
  "state": "Backlog",
  "size": "M",
  "priority": "Medium",
  "rank": 9,
  "blockedBy": [],
  "covers": "The ssh forwards this interface raised ended with it also when it ends without asking, and one left over found again by its socket at the next start."
}
```

**Why this size.** M: a record of each forward that only this account can have written, a sweep that ends a recorded
forward only while it is still that very process and still serves that endpoint, in the tunnel and the login forward,
SIGTERM and SIGINT watched with a bounded end, and their tests, many of them guards of what is not ended; Linux only.

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

- **A record of each forward:** right after its ssh starts, the interface writes the pid, its start time (field 22 of
  `/proc/<pid>/stat`), the boot id (`/proc/sys/kernel/random/boot_id`) and the arguments it launched (never read
  back from `/proc` at once, where the child may still show the window's own) into `$XDG_RUNTIME_DIR/porelo-forwards`:
  `$XDG_RUNTIME_DIR` checked to be owned by this uid with mode 0700, the directory created 0700 and checked with lstat
  the same way, else no record is written or read and nothing is swept. Not under the state directory, whose path the
  environment may choose. A socket's path comes from the person's settings and may lie in a shared directory, so the
  record never lies beside it. Each record
  is written 0600, atomically (a temporary file renamed), following no link; one owned by another uid or wider than
  0600 is ignored. It is removed when its forward ends (`_itEnded`, `close`), and a stale one (pid gone, start time or
  command line differing) at the next start.
- **Found again at the start:** before the "already serving" refusal in `Tunnel.raise`, and before the port check in the
  login forward, a recorded pid is ended only when it is alive, runs as this account, has the recorded start time, has
  the recorded arguments, and they forward this very endpoint (`-L <socket>:` or `-L <port>:localhost:<port>`). A pidfd
  is opened first (`pidfd_open` through FFI, as `pty.dart` does), the checks run, and SIGTERM goes through it
  (`pidfd_send_signal`), never to a raw pid; where no pidfd can be opened nothing is ended. The boot id must match; the
  arguments are compared as vectors, the first included. Never a pid this run holds (`Tunnel._process`, the login
  forward's `_held`). The start then waits at most 20 × 100 ms, as `_endOrphanedMaster` does, for the endpoint to stop
  answering; still answered, it is refused as today, with no SIGKILL. An endpoint with no record of ours is left alone
  as today. A command-line pattern is not enough: a `host` machine's forward and a login forward with its own ssh
  options write other ones.
- The sweep runs only after `OneInstance.take`: a second instance about to be turned away ends nothing.
- A card machine's own refusal in `_raiseCard` ("an endpoint already exists and was left alone") is not part of this
  issue; its master is already ended at the start.
- The sweep reads `/proc` through a seam of its own, not through the tunnel's `run:`, so the existing fakes are
  unchanged. The login forward's `Process.start` gets a seam (`startLoginForward`, like `raiseLoginForward`), landed
  first without a change of behaviour.
- **Ended on SIGTERM and SIGINT:** `lib/main.dart` watches both through a function of its own that a test calls, lets go
  of the tunnels and forwards, and exits after them or after five seconds, whichever comes first (a watched signal no
  longer ends the process by itself). On Windows SIGTERM cannot be watched: only SIGINT is. SIGKILL and a crash cannot
  be watched: what they leave is ended at the next start.
- No parent-death signal: on Linux it fires when the thread that started the child ends, and Dart starts processes
  from pool threads that end when idle, so forwards would die at random.
- Linux only. The `/proc` seam answers "not ours" elsewhere (Windows, macOS), so nothing is swept there; a job object
  that ends its children would be Windows' own issue.
- **Red first:** in `test/app/tunnel_test.dart`, a forward a killed run left at the socket is ended and the machine
  raised (today: down, "already serving", the old one alive); an answering socket with no record of ours is still left
  alone; a recorded pid that now runs another command line, has another start time, or forwards another socket is not
  ended; a record owned by another uid, wider than 0600 or in a directory others may write is ignored; a pid this run
  holds is not ended; an endpoint still answered after the end is refused after the bounded wait; a record is gone
  after a normal close. In `test/app/login_reply_test.dart`, a login forward a killed run left on the port is ended
  and raised again (today: "already in use"), and a second forward for a port this run holds ends nothing. The signal
  function lets go and exits, also when letting go hangs.

## Acceptance

- After `q` in `flutter run`, or a kill of the window, and a new start, each watched machine is up with one forward,
  and each homeserver forward is raised.
- Closing the window still takes them all down, as today.
- An endpoint served by anything this interface did not record is left alone.
- Seen to fail: the tests red with the machine refused while the old forward still runs.

## To be checked

- Which signal `q` in `flutter run` sends a Linux desktop app.
