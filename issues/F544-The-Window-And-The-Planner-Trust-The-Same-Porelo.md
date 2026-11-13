# F544 — The Window And The Planner Trust The Same Porelo

```json
{
  "$schema": "issue-1.json",
  "id": "F544",
  "title": "The Window And The Planner Trust The Same Porelo",
  "state": "Review",
  "size": "XS",
  "priority": "Medium",
  "rank": 111,
  "blockedBy": [],
  "covers": "The window hands the planner it starts only a Porelo executable the planner also accepts: neither may be written by others, or by a group other than the person's own private group, so a umask 002 setup keeps its lent login and a shared group never reaches it."
}
```

**Why this size.** XS: one rule in `_whyNot`, the words of a refusal, and a test case, once the rule both sides keep is
decided.

Found on the test machine, where the account's own program folder is `drwxrwxr-x` with the person's own primary group (umask 002).
- `findPoreloExecutable` (`lib/src/app/porelo_executable.dart`) takes the account's own install before `/usr/bin/porelo`.
  Its `_whyNot` lets a folder through that only the person's own primary group may write, and the window passes that
  path as `PORELO_EXECUTABLE`.
- The planner refuses that same path because its folder is group-writable without the sticky bit, and lends no login.
  Every repository read then fails with `Unreadable`, the window never hands the project over, and the board stays
  empty.

**What must be true.**
- A Porelo executable the window passes as `PORELO_EXECUTABLE` is one the planner accepts: the file and every folder up
  to `/` are owned by root or the person, others may not write them, and a group may write them only where it is the
  person's own private group.
- The person's own private group is the one gid the window runs as, the person's primary group, which no other account
  has as its primary group and which lists no other member.
- A refused first place is not passed over for the next; the refusal is said, as before.

## Decided

- The planner takes the window's rule, and both tighten it to the person's own private group alone. The window's own-group
  allowance exists so that a umask 002 setup, whose folders its private group may write, keeps the lent login.

## Plan

- `lib/src/app/porelo_executable.dart`: `privateGroupOf(gid, uid)` reads `/etc/passwd` and `/etc/group` and gives the
  gid only where it is private; `findPoreloExecutable` takes that as the group it allows.
- Red first in `test/app/porelo_executable_test.dart`: a group another account has as its primary one, a group that
  lists another member, a group no file names, and no single gid, each refused; the person's private group taken.

## How it was built

- `privateGroupOf` gives the window's gid only where the person's account names it as primary, no other account does,
  and `/etc/group` lists no member but the person. A group-writable folder of any other group is refused, with the
  words "a group other than your own private one".
- Red: with the two checks for other accounts and other members taken out, the new case failed (`Expected: null`).
- Every `/etc/group` line that names the gid counts, as the system's own lookup takes them all, and a file that cannot
  be read or decoded names no private group. Red: with only the first line read, a second line of the gid naming
  another member was taken for private.
- Accounts and members known only through NSS (LDAP, NIS) are not seen; the person's own account missing from
  `/etc/passwd` names no private group.
- `test/app/porelo_executable_test.dart` passes, 7 cases.

`F544 size=XS est=10 basis=median XS 10 (8 records)`
