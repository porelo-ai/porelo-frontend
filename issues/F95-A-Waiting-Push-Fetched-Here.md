# F95 — A Waiting Push Fetched Here, Into A Clone Chosen

**Status:** Analyzed.
**Size:** M - a folder dialog, a git run here, the review's own-clone box and its wiring, and a changed decision in
`doc/decisions.md`.

**What must be true.** Beside a waiting push, a person can run its `git fetch` here, into a clone they choose, instead
of only copying the command, with the push's source level (`E0`, `E1`, `I1`, `A`) and risk class (`C0`–`C3`) shown in
`_OwnClone` and an explicit warning before fetching when the push is `E0` or `C2`/`C3`.

## Why

The fetch the machine names is already shown under *Read it in your own clone*, with the host put in, and copied with
one button. Running the `git fetch` directly into a chosen local clone avoids copying and pasting while keeping the
rule in `doc/decisions.md` that nothing in the local clone is checked out or built automatically.

## Plan

- **Where it is today.** `_OwnClone` in `lib/src/ui/gate_view.dart` shows `PendingPush.fetchFrom(login)`
  (`lib/src/client/models.dart`) with a Copy button; `ReviewView` builds it, and `_ShellState` in
  `lib/src/ui/shell.dart` passes `login`.
- **Source-level and risk-class warning.** `_OwnClone` in
  `lib/src/ui/gate_view.dart` displays the push's source level (`E0`, `E1`, `I1`, `A`) and risk class (`C0`–`C3`). When
  the push is `E0` or has risk class `C2` or `C3`, `_OwnClone` shows an explicit warning before fetching or copying the
  command: fetching brings objects only, and checking out or opening the worktree in a local IDE can execute repository
  hooks, build scripts, or IDE auto-tasks on this computer.
- **Choosing the clone.** `lib/src/ui/pick_a_file.dart` gets a folder twin of `PickAFile`, on `file_selector`'s
  `getDirectoryPath`, injected through `PoreloApp` (`lib/src/app/porelo_app.dart`) and `Shell` (`lib/src/ui/shell.dart`)
  as `pickAFile` is, so a scenario answers it.
- **Validating and running it.** A small class in `lib/src/app/` runs the fetch with `RunHere` from
  `lib/src/app/project_workspace.dart`, in the chosen folder. It never hands the string to a shell: it takes
  `git fetch <url> <refspec>` apart, validates the remote URI and refspec (refusing any leading `-`, shell
  metacharacters, git `-c` protocol overrides from untrusted strings, or anything of another shape), checks the folder
  is a git work tree (`git rev-parse`) and, by its remotes (`git remote -v`), a clone of the push's repository — else
  it says which repository it expects — then runs `git fetch` with those two validated argv elements in a terminal of
  the window's own (`runInATerminal` in `lib/src/ui/unlock_terminal.dart`), where a host key or a passphrase is
  answered, and reads done or git's own words from its end. Nothing in the clone is checked out or built.
- **The box.** `_OwnClone` gets "Fetch it into a clone here…" beside Copy; after the run it says which folder now holds
  the push under which ref, or why not, and keeps the folder for the next push of the same repository.
- **The decision.** "A waiting push is read in the person's own clone, and never built there" in `doc/decisions.md`
  says the fetch also runs here when the person asks for it, never by itself.
- **Red first.** In `test/features/work_handover.feature`, beside "a waiting push can be fetched into the person's own
  clone": "a waiting push is fetched into the clone chosen, and said to be there" (the folder dialog answers, the fake
  runner records `git fetch` with the two arguments in that folder), "a folder that is no clone of the push's
  repository is refused, naming the repository expected", "a fetch that fails says git's reason", and a scenario
  asserting that an `E0` or `C2`/`C3` push displays the checkout and IDE warning in `_OwnClone`. A unit test in
  `test/app/` holds the refusal of a fetch line of any other shape or with a leading `-` in the URI or refspec.

## Acceptance

- Choosing a clone and running the fetch brings the waiting push into that clone as an argv-validated `git fetch`, and
  says so, or why not. Seen to fail: a scenario that runs the fetch into a chosen clone and finds the push not there,
  or a failed fetch with no reason shown, or a unit test where a leading `-` in the URI or refspec is accepted.
- `_OwnClone` displays the push's source level (`E0`, `E1`, `I1`, `A`) and risk class (`C0`–`C3`), and shows the
  explicit checkout and IDE auto-task warning when the push is `E0` or `C2`/`C3`. Seen to fail: a scenario with an `E0`
  or `C2` push where the warning is absent.

## To be checked

- `fetchFrom` puts in the ssh login only where the machine needs a tunnel; for this computer, a WSL distribution, or a
  machine whose ssh name differs, which address does a fetch run here use?
