# F95 — A Waiting Push Fetched Here, Into A Clone Chosen

**Status:** Analyzed.
**Size:** M - a folder dialog, a git run here, the review's own-clone box and its wiring, and a
changed decision in `doc/decisions.md`; no contract changes.

**What must be true.** Beside a waiting push, a person can run its `git fetch` here, into a clone they
choose, instead of only copying the command.

## Why

The fetch the machine names is already shown under *Read it in your own clone*, with the host put in,
and copied with one button.

## Plan

- **Where it is today.** `_OwnClone` in `lib/src/ui/gate_view.dart` shows
  `PendingPush.fetchFrom(login)` (`lib/src/client/models.dart`) with a Copy button; `ReviewView`
  builds it, and `_ShellState` in `lib/src/ui/shell.dart` passes `login`.
- **Choosing the clone.** `lib/src/ui/pick_a_file.dart` gets a folder twin of `PickAFile`, on
  `file_selector`'s `getDirectoryPath`, injected through `SokarApp` (`lib/src/app/sokar_app.dart`)
  and `Shell` as `pickAFile` is, so a scenario answers it.
- **Running it.** A small class in `lib/src/app/` runs the fetch with `RunHere` from
  `lib/src/app/project_workspace.dart`, in the chosen folder. It never hands the string to a shell:
  it takes `git fetch <url> <refspec>` apart, refuses anything of another shape, checks the folder
  is a git work tree (`git rev-parse`), then runs `git fetch` with those two arguments and answers
  done, or git's own words. Nothing in the clone is checked out or built.
- **The box.** `_OwnClone` gets "Fetch it into a clone here…" beside Copy; after the run it says
  which folder now holds the push under which ref, or why not, and keeps the folder for the next
  push of the same repository.
- **The decision.** "A waiting push is read in the person's own clone, and never built there" in
  `doc/decisions.md` says the fetch also runs here when the person asks for it, never by itself.
- **Red first.** In `test/features/work_handover.feature`, beside "a waiting push can be fetched
  into the person's own clone": "a waiting push is fetched into the clone chosen, and said to be
  there" (the folder dialog answers, the fake runner records `git fetch` with the two arguments in
  that folder), and "a fetch that fails says git's reason". A unit test in `test/app/` holds the
  refusal of a fetch line of any other shape.

## Acceptance

- Choosing a clone and running the fetch brings the waiting push into that clone, and says so, or why
  not. Seen to fail: a scenario that runs the fetch into a chosen clone and finds the push not there,
  or a failed fetch with no reason shown.

## Open questions

- Is the chosen clone checked to be one of the push's repository (its remotes), or is any git
  work tree taken? (the operator's)
- An ssh fetch run from the window has no terminal for a host key or a passphrase: is it run
  with `BatchMode=yes` and its refusal shown, or in a terminal of the window's own? (the operator's)

## To be checked

- `fetchFrom` puts in the ssh login only where the machine needs a tunnel; for this computer, a WSL
  distribution, or a machine whose ssh name differs, which address does a fetch run here use?
  (Agent Frontend's)
