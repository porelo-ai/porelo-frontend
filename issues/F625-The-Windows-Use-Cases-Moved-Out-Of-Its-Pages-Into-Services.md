# F625 — The Window's Use Cases Moved Out Of Its Pages Into Services

```json
{
  "$schema": "issue-1.json",
  "id": "F625",
  "title": "The Window's Use Cases Moved Out Of Its Pages Into Services",
  "state": "Analyzed",
  "size": "XL",
  "priority": "High",
  "rank": 1,
  "blockedBy": [],
  "covers": "A page's handler only checks its input, calls one service and shows its answer; token hand-ons, a host's give-back and the shell's machine, approval and work handlers move into services tested without widgets"
}
```

**Why this size.** XL: about a dozen handlers of 50 to 120 lines in `shell.dart` and four other pages each chain
several backend, settings or vault calls with rules between them; it splits into the four parts below, each M or L.

**What must be true.** A widget's handler only checks what was given, calls one service method and shows its answer;
the dialogs it needs are asked through callbacks the service is given. The use case (what is kept, in which order,
under which rule, what is told the machine, the vault or the forge, and what is undone when a step fails) lives in a
service under `lib/src/app/` that knows no `BuildContext`, `setState` or widget, and is tested without them.

## Plan

Read in today's code. Already a service, only placed under `lib/src/ui/`: `WindowTaskStarts`
(`lib/src/ui/planning_embedding.dart`) and `WindowTaskReports` (`lib/src/ui/planning_reports.dart`) use no widget and
are tested by plain `test()`; they move to `lib/src/app/` unchanged. `porelo-host`'s `runHostCommand`
(`packages/porelo_host/bin/porelo_host.dart`) checks its arguments, maps them to a plan and calls `run.up`, `run.down`
or `run.memberships`; it needs no change.

The entry points that carry a use case, in four parts, each its own issue once split:

1. **Token hand-ons (M).** `_handForgeTokenOn` (`lib/src/ui/organization_access_dialogs.dart:264`) opens the machine,
   looks at its vault, applies the declaration rules and declares, with dialogs between; `_giveHostTokenNow`
   (`lib/src/ui/shell.dart:6814`) runs a hand-over step that goes on after its dialog closes. Both become one service
   in `lib/src/app/`; the dialogs stay and are passed in as callbacks.
2. **A host's give-back and token (M).** `_giveBack` (`lib/src/ui/host_dialog.dart:693`) brings the host down,
   confirms it, forgets its record, removes it from the organization with a two-minute limit and forgets its machines,
   reading again on failure; `_giveToken` (`lib/src/ui/organization_host_pages.dart:621`) branches over what the
   connection heard before and after. Each becomes a service method with its compensation; the page keeps `_busy` and
   `_problem`.
3. **The shell's machine handlers (L).** `_forget` (`shell.dart:2641`), `_addAConnection` (`:1902`),
   `_storeTheCredentialToStart` (`:3199`) and `_startTheAgents` (`:3294`) chain checks, backend calls and a terminal;
   they move to a machine service, the shell keeping the dialogs and the operations shown.
4. **Approval, new work and forms (M).** `_approve` (`shell.dart:3742`, branch choice, gate, remembered branch),
   `_newWork` (`:6178`, machine and project chosen and started), `_attempt` (`lib/src/ui/key_recovery_dialog.dart:89`,
   request, terminal, restore when it never opened) and `_save` (`lib/src/ui/forges_view.dart:269`, token asked, forge
   added or edited).

Steps per part: the service's unit tests first, over `FakeBackend` and recording callbacks, each covering a path the
widget tests hold today (a refusal, a failed step and what is undone, a page closed meanwhile), seen red with the
handler's logic not yet moved; then the handler reduced to the mapping, its widget tests passing unchanged. The guard
on each: a step that runs after the person left, or a failure that leaves a host or a credential half done.

## Open questions

- Split this issue into the four parts above as issues of their own, in that order, so each is built and tested alone?

## To be checked

- About fifteen smaller handlers of 25 to 45 lines in `shell.dart` (two to four awaited calls with a guard, such as
  `_letGo`, `_readAll`, `_bringToCentral`, `_openItsForge`) are read one by one when part 3 is built; each that runs a
  use case joins it.
