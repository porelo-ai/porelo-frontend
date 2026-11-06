# F401 — The Bootstrap Line Says Where It Runs

**Status:** Review.
**Size:** XS - the root bootstrap line of *Prepare a server* in the shared box with its copy button, and words beside
it that say where it runs.

**What must be true.** In *Prepare a server*, the line a person runs on the server before setup stands on its own, in
a console font, with a button that copies it, and beside it the words say it runs on the server, logged in with the
first login its provider gave, not on this computer; the same for the line shown again when a run stopped on it.

## Why

The operator's walk on the rehearsal VM (2026-11-06): the line was plain selectable text in the dialog's running words,
hard to read and to copy, and the dialog did not say where it runs.

## Plan

- `lib/src/ui/host_dialog.dart`: the bootstrap line and the line shown again (`preparation-root-command`) in
  `CommandToCopy`; the words before it start with where it runs: on the server, logged in as the provider's first
  login (such as `ubuntu`), not on this computer.
- No test goes red first: the line's text and where it comes from do not change, and the copy is the shared
  `CommandToCopy`'s; the dialog's tests that find the line by its key keep finding it.

## Acceptance

- The line stands in its own box, in a console font, with a copy button, in both places.
- The words beside it say it runs on the server under the provider's first login, not on this computer.
