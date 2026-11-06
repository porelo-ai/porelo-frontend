# F411 — Putting A Project On A Machine Says So

**Status:** Backlog.
**Size:** XS - the pending words of putting a project on a machine and taking it off name the machine.

**What must be true.** While a project is put on a machine, its row says "Putting it on <machine>…"; while it is taken
off, "Taking it off <machine>…". Never "Adding…" or "Removing…", which say the project is added to or removed from the
organization.

## Why

The operator's walk on the rehearsal VM (2026-11-06): porelo's row said "Adding…" while it was put on rehearsal; it
was not being added.

## Plan

- `lib/src/app/organization_source.dart` (the pending row of each change): `addProjectToHost` says
  `Putting it on $host…`, `removeProjectFromHost` `Taking it off $host…`.
- No test goes red first: words alone, nothing a person loses by them.
