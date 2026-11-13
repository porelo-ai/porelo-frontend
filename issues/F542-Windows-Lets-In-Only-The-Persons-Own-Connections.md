# F542 — Windows Lets In Only The Person's Own Connections

```json
{
  "$schema": "issue-1.json",
  "id": "F542",
  "title": "Windows Lets In Only The Person's Own Connections",
  "state": "Backlog",
  "size": "M",
  "priority": "Medium",
  "rank": 108,
  "blockedBy": [],
  "covers": "On Windows, what the window forwards from a machine to this computer is reached only by the person: each connection to a card's or a sign-in's loopback port is let in only where it was opened by the person's own account."
}
```

**Why this size.** M: the owner of a loopback connection read on Windows, the check in `LoopbackCarrier` and in a
sign-in's forward, measuring Win32-OpenSSH's `-L` to an `AF_UNIX` socket, and their tests on the Windows runner.

Split from [F394](README.md#f394) (2026-11-13), which closed it on Linux.

**How it stands.**
- On Linux the window holds every forward's port itself and relays only connections whose other end belongs to the
  person's uid, read from `/proc/net/tcp` (`lib/src/app/person_only_relay.dart`).
- On Windows a card's ports are held by the window too (`LoopbackCarrier`), but it carries every connection, whoever
  opened it; a sign-in's redirect and a joined homeserver are forwarded by ssh binding `localhost:<port>`. Every local
  account of this computer reaches them, and through the forge's web is the person there.

**What must be true.**
- On Windows a connection to any of these ports opened by another account, or by one that cannot be told, is closed
  before anything is read from it; the person's own is carried as today.

**To be checked.**
- `GetExtendedTcpTable` names the owning process of the connection's other end, and from its token the account.
- Whether Win32-OpenSSH's `-L` forwards to an `AF_UNIX` socket, so a sign-in's forward can go through the carrier or a
  relay as on Linux.

`F542 size=M est=61 basis=median M 61 (24 records)`
