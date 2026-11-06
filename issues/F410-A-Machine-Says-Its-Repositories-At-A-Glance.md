# F410 — A Machine Says Its Repositories At A Glance

**Status:** Accepted (operator, 2026-11-06).
**Size:** S - the machine page's row of a carried project reads the machine's answer per repository, names the taken
ones first and gathers the rest by reason into one line each, opened on demand.

**What must be true.** A project's row under *Projects on this machine* says first which of its repositories are on
the machine ("on the machine: porelo, porelo-message-sluice"), then one line per reason the others are not ("15
repositories name no central address"), each opened on demand to name them; never one sentence per repository.

## Why

The operator's walk on the rehearsal VM (2026-11-06): porelo's row repeated "no central address, so this host cannot
take it; name one in the project file for a task here" for 15 repositories, one wall of text, and never said which two
were taken.

## Plan

- porelo-host already answers, per project in its progress, `repositories: [{repository, state, why}]` with `state`
  `taken`, `waiting` or `no-central` (porelo-host-person `repositories_said`). `lib/src/app/host_progress.dart`:
  `HostProjectProgress` reads them; a state it does not know is kept with its words.
- `lib/src/ui/organization_host_pages.dart` (`_progressWords` and the project row): where repositories are answered,
  the row says the taken ones, then per other state one line with the count, opened on demand to name each with its
  `why` once; the project's own `why` is not repeated per repository. Where none are answered, as today.
- **The test that goes red first:** a host answer with two taken and fifteen `no-central` repositories shows "on the
  machine" with the two names and one line for the fifteen, the long reason once. It guards a person who cannot see
  what is on the machine for a wall of the same sentence.

## Acceptance

- The taken repositories are named first; the others are counted per reason and named on demand.

## Done

`host_progress.dart`: `HostProjectProgress.repositories` reads porelo-host's per-repository answer (`repository`, `state`, `why`), and `taken` names those taken. `organization_host_pages.dart`: a carried project says "on the machine: <taken>", and `_notTaken` adds one folded line per other state with the count ("15 repositories name no central address, so the machine does not take them"), opened to name them and say the reason once. Where the host says no repositories, as before. Red first: the old page repeated the reason and named no taken repository.

Review reading: the folded lines follow the taken ones in both rows, and only for a carried project.
