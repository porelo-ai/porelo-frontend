# F302 — Refresh Shows What It Did

**Status:** Idea.
**Severity:** medium.
**Size:** S - the shell's Refresh and its status words, with their tests; no contract with another repository.

**What must be true.** Pressing *Refresh* shows at once that it runs, where the person is looking, and ends with what
it read or what failed: machines asked, the registry's revision, projects that changed. "Nothing changed" is said in
words as well.

## Why

Pressing *Refresh* gives no visible feedback on list pages. `_refreshAll` (`lib/src/ui/shell.dart`) reads the
registry, the joinable projects and each connected machine, yet on the *Projects* list there is no status bar, so
Refresh shows nothing at all; only a project page has the bottom bar, which says "Refreshed: 0 tasks."
(`lib/src/app/fleet_model.dart`), reading as if nothing was looked at.

## The shape

- Wherever Refresh is pressed, on a list or a page, the button turns into a small spinner while it runs, and a
  short "Refreshed at 18:52" stays beside it afterwards.
- At its end a short message names what was read: "Refreshed demo and this machine; registry b4257326; nothing
  changed", or the first thing that failed.

## Plan

- `lib/src/ui/shell.dart` (`_refreshAll`, the rail's Refresh), `lib/src/app/fleet_model.dart` (`_say`).
- **Red first:** a widget test pressing Refresh sees the spinner while a fake machine holds its answer, and then the
  summary naming the machine.

## Acceptance

- Every Refresh gives a visible sign within a frame and a summary when it ends.
- A failed part is named, the others still read.
