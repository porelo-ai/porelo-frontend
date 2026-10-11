# F104 — A Project Followed From A File

**Status:** Analyzed; blocked by `sokar` B160, "A Project Followed From A File Over The Socket".
**Size:** M - the frontend's part: one contract change read in the client, the follow
dialog, the project's view and the mock, with scenarios. It waits for `sokar` B160.

**What must be true.** A person makes a project from a bundle or a directory on the machine, from
the interface, as `sokar project follow NAME FILE` does. An offline project, which can come only
that way, can be made from the interface again.

## Why

Since `sokar`'s B137, decided on 2026-10-09, an offline project never connects. `upstream:` and
`--upstream` are refused for it, and its repository comes in only as a bundle (`gate restore`) or
from a checkout on the machine. `sokar project follow NAME FILE` takes a bundle or a local directory
for every class, and a project followed from a file is never fetched in the background.

The interface follows a project only from a repository's address
(`lib/src/app/project_following.dart`, `SokarClient.follow(name, url)`). So an offline project can no
longer be made from the interface at all.

## The contract

- **Following from a file is the same `Follow`, with a path in `url`.** A value with neither a
  scheme (`https://`, `file://`) nor a host before a colon (`git@host:`) is taken as a file: a
  bundle or a directory, read once and never fetched in the background. An offline definition is
  taken only that way.
- **The path is absolute and on the machine.** Today the daemon does not make a relative path
  absolute, as `sokar project follow` does. `sokar` adds that, and says in `Follow`'s comment that
  `url` may be a path.
- **A bundle from this computer has no way to the machine yet.** `HandIn` writes into a running
  task only. The shape preferred: `Follow` takes the bundle's bytes itself, so no file outlives
  the call. The other shape would be a method that keeps the bytes on the machine and answers the
  path to give `Follow`. `sokar` B160 takes the first shape: the bytes go in the `Follow` call, the
  daemon keeps the bundle where only the account reads it, and a bundle above a limit the contract
  states is refused by name.

## The shape

- **The follow dialog offers a file beside an address**: a bundle or a directory, and for an
  offline project only that.
- **A directory or bundle already on the machine** is given as its absolute path there.
- **A bundle the person has on this computer** goes to the machine through the contract above.
- **A project followed from a file says so** in its view: that it is never fetched in the
  background, and how it is brought up to date (a new bundle).

## Plan

- **Today a directory on the machine already goes in `url`**:
  `ProjectFollowing.url` in `lib/src/app/project_following.dart` is "a URL, or a directory on that
  machine", and the scenario "a local repository needs nothing, and is followed" in
  `test/features/following_a_repository.feature` follows `/srv/git/payments`. What is missing is
  the bundle from this computer, the offline class, and saying it on the project.
- **Red first**: a scenario in `test/features/following_a_repository.feature`, "an offline project
  is made from a bundle on this computer", against the mock. It fails today: the dialog has only
  the `follow-url` field.
- **Contract**: read B160's `Follow` from `dart tool/contract.dart` against the handover. Add the
  bundle's bytes to `SokarClient.follow` in `lib/src/client/sokar_client.dart`, to
  `FleetBackend.follow` in `lib/src/app/fleet_backend.dart` (both places), and to the mock's
  `_follow` in `lib/src/mock/machine.dart`, with its refusal above the size limit and of an
  offline project given an address. If `Followed` gains a field saying it came from a file, read
  it in `Followed.from` in `lib/src/client/models.dart`.
- **Dialog**: `ProjectFollowingPanel` in `lib/src/ui/project_following_view.dart` offers a file
  beside the address: a path on the machine, or a bundle picked here. `ProjectFollowing` holds the
  picked bundle and sends it in `follow()`; a refusal shows in `follow-problem` as today.
- **The project says so**: beside the `project-unverified` mark in `lib/src/ui/projects_page.dart`,
  a mark that it is followed from a file, never fetched in the background, brought up to date by
  a new bundle.
- **Against a real machine**: a scenario in `integration_test/reaching_a_machine.feature` beside
  "a repository followed through the dialog becomes a project, and stops being one", following an
  offline project from a bundle and starting a task in it.

## Acceptance

- **An offline project is made from a bundle** from the interface, on a machine reached over ssh,
  and its tasks start. Seen to fail: today's dialog, which offers only an address.
- **A project of another class is followed from a directory on the machine.** It is listed as
  followed from a file, and nothing fetches it in the background.
- **An offline project with an address is refused in Sokar's words**, and the dialog offers the file
  instead.

## To be checked

- **The limit on a bundle's size** that `sokar`'s new way takes, and how the interface shows the
  upload of a large one. (Agent Core's for the limit, Agent Frontend's for showing it)
- **How the project tells it was followed from a file**: a field in `Following`'s answer, or
  read from `url` having no scheme. (Agent Core's)
