# F627 — The Shell's Machine Handlers Moved Into A Service

```json
{
  "$schema": "issue-1.json",
  "id": "F627",
  "title": "The Shell's Machine Handlers Moved Into A Service",
  "state": "Analyzed",
  "size": "L",
  "priority": "High",
  "rank": 3,
  "blockedBy": [],
  "covers": "Forgetting a machine, adding a connection, storing a credential to start and starting the agents run in a machine service tested without widgets; the shell keeps the dialogs and the operations shown"
}
```

**Why this size.** L: four handlers of 45 to 120 lines in `shell.dart`, each with a terminal or several dialogs between
its steps, plus about fifteen smaller ones read one by one; no contract changes.

**What must be true.** The shell's handlers for a machine only check what was given, call one method of a machine
service under `lib/src/app/` and show its answer; the service, tested without widgets, holds the checks, the order of
the backend calls and what follows a refusal. Third of the four parts begun in [F625](README.md#f625).

## Plan

Read in today's code (`lib/src/ui/shell.dart`).

- `_forget` (`:2641`): whether the machine can be forgotten, an optional take-down, the ssh entry it wrote, then the
  move away, `machines.forget` and removing the host entry, across three dialogs.
- `_addAConnection` (`:1902`): the dry-run declaration as a check, the declaration, then sending a key, storing on the
  machine or storing in a terminal.
- `_storeTheCredentialToStart` (`:3199`): the readiness's store command, else the provider's, in a terminal, then the
  start asked again.
- `_startTheAgents` (`:3294`): refresh, the carried and listed agents, why not, the wizard with its sign-in and store
  callbacks, and what is left said.
- Each becomes a method of `MachineActions` in `lib/src/app/`, the dialogs and the terminal passed in as callbacks;
  steps as in [F625](README.md#f625): the service's unit tests first, seen red, then the handler reduced to the mapping.
  Harm guarded: a machine forgotten while its take-down failed, a credential declared on the wrong machine, a step run
  after the person left.

## Acceptance

- `test/features` and `test/ui` pass unchanged; the new unit tests were seen red first.

## To be checked

- About fifteen smaller handlers of 25 to 45 lines in `shell.dart` (two to four awaited calls with a guard, such as
  `_letGo`, `_readAll`, `_bringToCentral`, `_openItsForge`), read one by one when this is built; each that runs a use
  case joins it.
