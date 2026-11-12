# F526 — The Planner Is Given Porelo's Own Path

```json
{
  "$schema": "issue-1.json",
  "id": "F526",
  "title": "The Planner Is Given Porelo's Own Path",
  "state": "Backlog",
  "size": "S",
  "priority": "Medium",
  "rank": 99,
  "blockedBy": [],
  "covers": "The window resolves Porelo's executable once, absolute with its links followed, and gives that path to the planner it starts, refusing one that it or anyone else could swap."
}
```

**Why this size.** S: one resolution at start, one checked path in the planner's environment, and their tests.

**What must be true.** The planner the window starts knows the one `porelo` the window itself uses, by an absolute path
whose file and directory no other user can write, so it can lend git the account's forge tokens through Porelo without
looking Porelo up on a path of its own.

## Why

porelo-planner's PL87 (the planner reads private repositories with Porelo's login) lets git ask Porelo for a forge
token per call, as Porelo itself does: `-c credential.<url>.helper=!<porelo path> vault credential --for <url>`. The
contract, agreed in the room on 2026-11-12: the window passes Porelo's path; Porelo gains `vault credential --for
<url>` (porelo's issue for it, filed by Agent Core), which resolves the URL as `FollowCredential.credentialFor` does
and answers only in git's credential protocol, https with a token only, exact lowercased host, failing with a message
when the vault is shut. Today the window runs `porelo` by name from its own PATH everywhere
(`lib/src/app/core_credentials.dart`, `porelo_organization_source.dart`, `fleet_backend.dart`, the task attach in
`session.dart`) and knows no absolute path.

## Plan

- At start, the window resolves `porelo` once: the first on its own PATH, made absolute and its links followed. It
  refuses the path, saying why on the planning place, where the file or any directory up to `/` is writable by a user
  other than its owner and root, or is not owned by root or the person.
- The planner the window starts gets that path in its environment, under the name PL87 settles (proposed:
  `PORELO_EXECUTABLE`); without a usable path the variable is left out, and the planner reads public repositories only.
- Red first in `test/app/planner_test.dart`: the planner's environment names the resolved, absolute path; a link is
  followed; a path in a directory others can write is refused and left out; a planner found serving is not touched.

## Waits on

- porelo-planner's PL87 for the variable's name; porelo's `vault credential --for` for any use of it.

## Estimate

`F526 size=S est=15 basis=median S 15 (11 records)`
