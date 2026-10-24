# F167 — The Project Bundle Written By The Wizard

**Status:** Review.
**Size:** M - a git bundle made from the followed project's own source, its safe publication into the tresor folder, and the wizard's fields.

**What must be true.** Putting a project on a server asks for no path on a machine not yet rented:
the interface writes the selected project's bundle into the chosen tresor folder as
`porelo-host/<project>.bundle` and names its place on the host itself. The public ssh key fills in
from `<private key>.pub` beside the chosen private key, and the summary says in words which project
the server is for before anything is rented.

## Plan

- **Today**, read in the code: the wizard takes the project's name from the project selected under
  *Projects* (`shell.dart` `_putOnAServer`) and asks for *Project repository address*, passed as is
  into `machine.yml` (`host_dialog.dart` `_repository`, `HostFiles.prepare` in
  `packages/porelo_host/lib/src/host_files.dart`). No bundle is written. Choosing the private key
  leaves the public-key field as it was.
- **The source, through the contract:** `Following` answers a `Followed` per project with `url`
  (where its repository is) and `commit` (the verified commit in force). The bundle is made from
  exactly that: `git clone --no-checkout <url>` into a private scratch directory of this computer,
  `git cat-file -e <commit>` must hold, then `git branch -f main <commit>`, `HEAD` pointed at it,
  and `git bundle create <scratch>/<project>.bundle HEAD main`, so the follow on the host finds a
  remote `HEAD` and the commit the daemon verified. Nothing reads the daemon's mirror or state
  files. A project with no verified commit is refused before renting, said in the wizard's drive
  step.
- **Publication:** `HostFiles` gains `publishBundle`: written beside its target and renamed over
  (`<folder>/porelo-host/<project>.bundle`), refused over a symlink or a directory, the scratch
  removed after a failure too. `machine.yml`'s `url` becomes the derived host path
  `/srv/porelo-host/drive/porelo-host/<project>.bundle` (the collection's `drive_path`), held as
  one constant beside `hostCollection`.
- **The wizard:** *Project repository address* goes; its stored value is ignored when read. The
  drive step says that the project's bundle is written into the folder. The summary opens with
  *A server for the project <project>*. Choosing the private key fills the public-key field with
  `<path>.pub` when that file exists, and only while the field still holds the previous default or
  is empty.
- **Tests, their harm, red first:** the bundle carries the followed `commit` as `main` and `HEAD`
  and no other project's history (a server set up with the wrong project), checked by `git
  bundle list-heads` on a bundle made from a real scratch repository; a symlink at the target is
  refused and nothing outside the folder is written (local files damaged); an unverified project
  rents nothing. Words and the prefill get no test.

## Acceptance

- In the guided walk and on a rented host, the wizard has no repository field, the tresor folder
  holds `porelo-host/<project>.bundle` after *Put it on a server*, and `porelo project inventory`
  on the host accepts it with its signature checked.
- Breaking the commit check (bundling the upstream tip instead) turns the bundle test red.

## To be checked

- That a `Followed.url` of the daemon's own making (a local bundle path) is readable by this
  computer's `git`; if not, the drive step says so instead of renting.
