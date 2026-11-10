# F460 — The Host's Finished Work Brought To Central From The Window

```json
{
  "$schema": "issue-1.json",
  "id": "F460",
  "title": "The Host's Finished Work Brought To Central From The Window",
  "state": "Backlog",
  "size": "M",
  "priority": "Medium",
  "rank": 11,
  "blockedBy": [],
  "covers": "*Bring it to central…* brings a host's finished `main` to the central forge from the project's page, refusals in the backend's words."
}
```

**Why this size.** a release action for a project carried on a host, its question, its run through the backend, and its
answer, refused in the backend's words.

**How it stands.** The backend's gathered push of a host's `main` to the central forge, taking repository names and
naming a refused login, is on Porelo's main (2026-11-10), in its review.

**What must be true.** A person brings a host's finished `main` of a project to the central forge from the window, by
a button where they expect a release, without a command line or a pasted token.
- The project's page on its host offers *Bring it to central…* once the host's `main` is ahead of central, naming the
  commits it brings.
- It runs the backend's gathered push and says what reached central, or refuses in the backend's words (a token
  refused by the forge said as refused, never as a prompt that could not be shown).
- In class `guarded` the gate's release stays as it is; this is the step after it, for any class.

## Plan

- A `Command` in `lib/src/app/commands.dart`, homed on the machine's project page (`lib/src/ui/machine_tree.dart`),
  over the backend's push, read leniently; the state at central already read from the host (`host_progress.dart`)
  decides whether it is offered.
- Red first: a feature scenario with the host ahead of central, where the button must be offered, and one with a
  refusal, said on the page.

## Acceptance

- Against the mock: the button brings the commits and the page then says up to date; a refused token is said as
  refused. Against a host: central's `main` at the host's commit after one press.
