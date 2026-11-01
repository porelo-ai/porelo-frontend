# F300 — One Project, One Entry Across Machines

**Status:** Idea.
**Severity:** medium.
**Size:** M - the projects page's rows and its navigation count, with their tests; no contract with another
repository.

**What must be true.** A project that this computer and a host both hold reads as one entry under *Projects*, with
the machines it is on under it, so nobody takes two rows of one name for two projects. "Without a project" is shown
once per machine in the same way.

## Why

Seen in the sprint 6m walk (2026-11-01, michi): after Register, *Projects* listed sprint6m-demo twice and "Without a
project" twice, one row for picard ("on this machine") and one for walk6m. The rows differ only in "on <machine>" in
their subtitles.

## The shape

- Grouped by project: the project's name as a heading, one line per machine under it, each with that machine's state
  and actions as today. Alternatively grouped by machine with a heading per machine; the walk asked for one project as
  one entry, so by project is the first choice.
- The navigation count counts projects, not rows.

## Plan

- `lib/src/ui/projects_page.dart` (`scopedProjectRows` callers), `lib/src/ui/shell.dart` (the count).
- **Red first:** a widget test with one project on two machines shows its name once, with both machines under it.

## Acceptance

- A project on n machines shows its name once and n machine lines.
- Selecting a machine line acts on that machine only, as a row does today.
