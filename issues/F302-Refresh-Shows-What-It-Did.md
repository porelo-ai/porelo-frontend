# F302 — Refresh Shows What It Did

**Status:** Idea.
**Severity:** medium.
**Size:** S - the shell's Refresh and its status words, with their tests; no contract with another repository.

**What must be true.** Pressing *Refresh* shows at once that it runs, where the person is looking, and ends with what
it read or what failed: machines asked, the registry's revision, projects that changed. "Nothing changed" is said in
words as well.

## Why

The rail names *Organization* (`Section.organization` in `lib/src/app/shell_model.dart`). `_refreshAll` and
`_readAll` in `lib/src/ui/shell.dart` read identity standings, the organization, host access and connected machines.
`FleetModel.refresh` in `lib/src/app/fleet_model.dart` reports only "Refreshed: <n> tasks."
`StatusLine` is shown under *Work* and the machine/project area, not on the list pages or *Organization*.
The rail's *Refresh* in `lib/src/ui/shell_rail.dart` has no busy indicator or result summary. These files do not
provide the promised immediate feedback and account of what was read wherever Refresh is pressed.

## The shape

- Wherever Refresh is pressed, on a list or a page, the button turns into a small spinner while it runs, and a
  short "Refreshed at 18:52" stays beside it afterwards.
- At its end a short message names what was read: "Refreshed demo and this machine; registry b4257326; nothing
  changed", or the first thing that failed.

## Plan

- `lib/src/ui/shell.dart` (`_refreshAll`), `lib/src/ui/shell_rail.dart` (the rail's Refresh),
  `lib/src/app/fleet_model.dart` (`_say`).
- **Red first:** a widget test pressing Refresh sees the spinner while a fake machine holds its answer, and then the
  summary naming the machine.

## Acceptance

- Every Refresh gives a visible sign within a frame and a summary when it ends.
- A failed part is named, the others still read.
