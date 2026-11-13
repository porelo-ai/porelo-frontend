# F526 — The Planner Is Given Porelo's Own Path

```json
{
  "$schema": "issue-1.json",
  "id": "F526",
  "title": "The Planner Is Given Porelo's Own Path",
  "state": "Review",
  "size": "S",
  "priority": "High",
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

The planner is to read private repositories with Porelo's login, by letting git ask Porelo for a forge token per
call, as Porelo itself does: `-c credential.<url>.helper=!<porelo path> vault credential --for <url>`. The contract,
agreed on 2026-11-12: the window passes Porelo's path in `PORELO_EXECUTABLE`; the planner runs only that path and
refuses it as the window does; Porelo's `vault credential --for <url>` resolves the URL as its own follows do and
answers only in git's credential protocol on git's pipe, https with a token only, exact lowercased host, failing with a
message when the vault is shut. Today the window runs `porelo` by name from its own PATH everywhere
(`lib/src/app/core_credentials.dart`, `porelo_organization_source.dart`, `fleet_backend.dart`, the task attach in
`session.dart`) and knows no absolute path.

## Plan

- At start, the window finds Porelo once at fixed places, the account's own install in the user's local bin folder under
  the home folder, then `/usr/bin/porelo`, takes the first where anything is, and follows its links. It refuses the
  path, saying why in the window's log, where the file or any folder up to `/` can be written by a user other than its
  owner and root, or is owned by neither root nor the person.
- The planner the window starts gets that path in its environment as `PORELO_EXECUTABLE`; without a usable path the
  variable is left out, and the planner reads public repositories only.
- Red first: the path found is absolute with its links followed; a path others could swap is refused; an inherited value
  never reaches the planner; the started planner is given the path.

## Decided

- `PORELO_EXECUTABLE` names the path of Porelo's install that the window finds itself, with its links followed: the
  account's own install, in the user's local bin folder under the home folder, which its login shell finds first, else the package's,
  `/usr/bin/porelo`. It is never taken from the settings, a search path or anything a repository controls. The first
  place where anything lies decides; one refused is not passed over for the next.
- A value the window inherited is always overwritten: the planner's environment drops any `PORELO_EXECUTABLE` before
  the window adds its own, and where the window finds no usable Porelo the variable is left unset.
- On Windows the window has no local Porelo, so it always leaves `PORELO_EXECUTABLE` unset there, removing an
  inherited one.
- A folder or file its group may write is taken only where that group is the person's own primary group, as a umask
  of 002 with a group of the person's own leaves `$HOME` and the person's folders; one any other group, or anybody, may
  write is refused.
- Off Linux, and on Windows, the window gives nothing and logs no refusal: there is nothing of its own to vouch for.
- An inherited `PORELO_EXECUTABLE` is ignored on purpose, and only the two places are searched: a Porelo installed
  elsewhere, as under `/opt` or by Nix, is not found, and the planning then reads public repositories only. The
  window's other inherited variables, such as `GIT_CONFIG_*`, `PATH` or `LD_PRELOAD`, are its own environment and out
  of this issue's scope.
- A refused path is said in the window's log rather than on the planning place: the planning still works, for public
  repositories, and the reason is for whoever looks into why a private one is not read.

## How it was built

- `lib/src/app/porelo_executable.dart`: `poreloPlaces` names the two places, `findPoreloExecutable` resolves and checks
  the first found (owner root or the person; writable by nobody else, a group only where it is the person's own
  primary group; the file and every folder up to `/`, read without following links; nothing off Linux), and
  `plannerEnvironment` drops an inherited `PORELO_EXECUTABLE` in any case of its name. `pathFactsOf` reads the owning
  gid too.
- `LocalPlanner.of` finds it once and says a refusal in the window's log; `LocalPlanner` passes it to the planner it
  starts, and starts the planner with an environment of its own (`includeParentEnvironment: false`), so nothing
  inherited names Porelo. A planner found serving is not touched.
- Tests, each seen red: `test/app/porelo_executable_test.dart` (the account's install first, its link followed; the
  package's where the account has none; a file or folder others can write, or owned by another account, refused and
  a valid next place not taken; one the person's own group may write taken, another group's refused; nothing where
  none is installed or off Linux; an inherited value dropped) and
  `test/app/planner_test.dart` (the started planner is given the path).

## Estimate

`F526 size=S est=15 basis=median S 15 (11 records)`
