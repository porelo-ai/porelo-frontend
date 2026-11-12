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

Corrected after a reading of the first plan by another model; its six points and what became of them are below.

- **What the window made, proved by the kernel.** A socket path is the window's own only once the kernel shows that the
  process it launched holds a listening socket bound to that very file: `sock_diag` names the file each unix socket is
  bound to by device and inode, and `/proc/<pid>/fd` names the sockets the process holds. A launch, a bind seen at the
  path, or an answering `-O check` proves nothing about who bound it. The file is then held by an
  `O_PATH|O_NOFOLLOW` descriptor until it is removed, so its inode cannot be freed and given to a replacement that
  would compare equal.
- **Removed only while it is still that file.** The parent is opened one component at a time from `/` with
  `O_NOFOLLOW|O_DIRECTORY`, must be this account's alone (owned by it, no group or other write), the name's device
  and inode are read once more through it with `statx` and `AT_SYMLINK_NOFOLLOW`, must be a socket and equal the held
  one, and only then is it removed with `unlinkat`.
- **A leftover.** A path nothing recorded, such as one left by a run that crashed, goes only when it is a socket, the
  kernel names no socket of this network namespace bound to it, a connect is refused, and the same checks hold after
  the probe. `/proc/net/unix` is not used: it names a socket by the spelling it was bound with, and its inode is the
  socket's, not the file's.
- **Each card endpoint is recovered on its own**, before the orphaned master is looked for, so a forward left by a
  launch that never answered does not block every raise when its control socket is gone.
- **The directory is checked before anything is bound or launched.** A machine socket, a card's control socket or the
  one-instance socket in a folder that is not this account's alone is refused and said, not raised.
- **The one-instance socket is bound at a private name and linked to the shared name.** `link` takes a name only while
  it is free, so two launches never both take charge, and `dart:io`'s close, which unlinks the path it bound whatever
  is there by then, removes only the private name. The probe keeps its three answers: only nobody lets a leftover go,
  answers joins the running window, could-not-tell ends the launch with words and touches nothing. `release()` removes
  the shared name only while it is still the held socket.
- Red first:
  - a regular file at the socket path survives raise and drop
  - a socket put in place after the raise survives drop and reconnect, and still answers
  - a socket somebody else bound at the path before the launch's own is not recorded and survives drop
  - a probe failing with EMFILE leaves the one-instance socket
  - a socket swapped between probe and unlink survives, through a seam between the two
  - the one-instance shared name replaced while running survives `release()`
  - a card endpoint replaced after the master answered survives drop
  - the leftover-socket tests are changed to real sockets whose holder ended, made by another process
  - a folder that is not this account's alone is refused before anything is launched

### What the reading found, and what was done

1. *Implicit removals bypass the helper* - `dart:io`'s close unlinks its path, ssh unlinks its control path on exit.
   The one-instance socket now closes only its private name. ssh's own unlink of its control socket stays: it lies in a
   folder only this account can change.
2. *A bind seen does not prove who bound* - ownership now needs the launched process to hold the listener bound to the
   file.
3. *`/proc/net/unix` cannot authorize removal* - replaced by the kernel's device and inode per socket; the probe stays.
4. *A numeric identity can be reused* - the file is held by an `O_PATH` descriptor through cleanup.
5. *An unchecked card launch can leave a forward that blocks every raise* - each endpoint is recovered on its own.
6. *Binding where cleanup refuses* - the folder is checked before binding or launching.

What stays and is said: between the last read of the identity and the unlink, only a process of this account can put
another object at the name; ssh unlinks its own control path on exit; a socket only bound, not listening, in another
network namespace that shares the folder is not seen.

## Acceptance

- After any raise, reconnect, drop or start, a file or another program's socket at the path is still there and still
  answers.
- A socket the window's own ssh left behind after a crash is still cleared at the next raise.

## Estimate

`F513 size=M est=61 basis=median M 61 (24 records)`
