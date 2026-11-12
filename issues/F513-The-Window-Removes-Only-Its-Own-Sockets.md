# F513 — The Window Removes Only Its Own Sockets

```json
{
  "$schema": "issue-1.json",
  "id": "F513",
  "title": "The Window Removes Only Its Own Sockets",
  "state": "Backlog",
  "size": "M",
  "priority": "High",
  "rank": 86,
  "blockedBy": [],
  "covers": "The window removes a socket path only when it holds proof that the object there is the socket its own ssh or its own instance made and nobody listens on it; never another program's live socket and never a file."
}
```

**Why this size.** M: the tunnel's ways of clearing a machine's socket (raise, reconnect, drop, a card's endpoints, the
orphan clean-up at start) and the window's one-instance socket, each moved from a pathname check to an identity it
holds, and their tests.

**What must be true.** Whatever another program puts at a machine's socket path or the one-instance path, and whenever,
the window does not delete it: neither a live socket nor a file.

## Why

The reading by another model of [F219](README.md#f219)'s final changes found four grave points that the issue's own fix
does not settle, since they lie in code it touched but does not own. Each loses data or takes away another program's
socket:

1. **Ownership by launch.** `lib/src/app/tunnel.dart` remembers that its ssh was launched (`_madeTheSocket`,
   `_ownsEndpoints`), not which socket object it made. A socket put in its place after a raise is deleted by drop,
   reconnect or `_clearOwnedCardEndpoints()` without being asked; a launch also does not prove ssh bound anything.
2. **Probe and unlink apart.** Raise, reconnect and the orphan clean-up probe one resolution of the path and delete
   through another. Between the two another program can put a listening socket there, or a bound socket can start to
   listen after the probe was refused.
3. **A file deleted.** `_clearTheWay()` deletes whatever exists at `machine.socketPath` once a connect to it is
   refused. A regular file there is refused too (ECONNREFUSED on Linux), so it is deleted. The test of a leftover
   socket in `test/app/tunnel_test.dart` creates a regular file and expects exactly this.
4. **The one-instance socket.** `lib/src/app/one_instance.dart` counts every `SocketException` of its probe as nobody
   answering. Under EMFILE a running window's socket is then deleted at start. `release()` deletes the path without
   checking that it still names its own socket.

## Plan

- One helper decides whether a socket path may go: `lstat` says socket (not file, not link), and its (device, inode)
  equals the one recorded when this window's ssh or instance bound it, read right after the bind is seen. Paths with
  nothing recorded, such as orphans from an earlier run, are checked like this: the probe connects and is refused, and
  the same (device, inode) is read before and after it. Only then is the path unlinked, through the directory
  descriptor of its parent with `unlinkat`. The parent is opened with `O_NOFOLLOW|O_DIRECTORY` and checked as the
  forward records' directory is.
- The one-instance probe uses the tunnel's three answers (nobody, somebody, could not tell). Only "nobody" lets its
  path go; `release()` goes through the helper.
- Red first:
  - a regular file at the socket path survives raise and drop
  - a socket put in place after the raise survives drop and reconnect
  - a probe failing with EMFILE leaves the one-instance socket
  - a socket swapped between probe and unlink survives, through a seam between the two
  - the leftover-socket test is changed to a real socket

## Acceptance

- After any raise, reconnect, drop or start, a file or another program's socket at the path is still there and still
  answers.
- A socket the window's own ssh left behind after a crash is still cleared at the next raise.

## Estimate

`F513 size=M est=61 basis=median M 61 (24 records)`
