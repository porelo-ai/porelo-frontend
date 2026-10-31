# F190 — Approved Work Brought To The Central Forge

**Status:** Analyzed.
**Size:** M - a pull-request state and a bring-on call in the client and its stand-ins, with the contract docs, drawn
as a *Needs you* row and a list on the project's page with one confirmation; no comments, no merging, no token form.

**What must be true.** For a task's pull request on the host's Forgejo, a person sees its state, its approval and the
commit the approval was given on, and brings approved work on to the central forge from the interface, without a
terminal on the host. The bring-on is bound to the exact commit, target repository and pull request number, and shows
the push's source level (`E0`, `E1`, `I1`, `A`), highest risk class (`C0`–`C3`) and check completeness in one line.
Approving happens in IntelliJ or on the forge.

## Why

Bringing approved work on to the central forge is the person's last decision on a piece of work. Binding it to the
approved commit keeps a moved pull request or a moved central branch from being pushed unseen.

## Plan

- **Waits for the contract:** the daemon answers, per pull request `porelo/<task>` → `main` on the host's Forgejo, its
  number, state (open, merged, closed), approval with who gave it, when and on which commit, the source level,
  highest class and check completeness of its commit, and a bring-on call over Varlink bound to commit, repository and
  pull request number, refused when the central forge or the pull request head moved. `doc/Backend-API.md` and
  `doc/Contract-Gaps.md` take them first.
- **The client:** a `HostPullRequest` in `lib/src/client/models.dart`, read and brought on through `PoreloClient`
  (`lib/src/client/porelo_client.dart`) and `FleetBackend` (`lib/src/app/fleet_backend.dart`), with `MockMachine`
  (`lib/src/mock/machine.dart`) and `FakeBackend` (`test/fakes/fake_backend.dart`) holding every state.
- **Where:** a *Ready to bring on* row in *Needs you* (`Attention` in `lib/src/app/attention.dart`, `AttentionView` in
  `lib/src/ui/attention_view.dart`) once a pull request is approved on its current commit, and the same row in a *Pull
  requests* list on the project's page. The row shows the pull request, its state, the approval and its commit, the
  target (repository, branch), that it goes as the person with their SSH identity, and one line of level, class and
  checks.
- ***Bring it on…*** is a `Command` in `lib/src/app/commands.dart`. Its confirmation names the commit, repository and
  pull request number, and each check not complete; it is never refused for that.
- **States:** not approved, changes requested, or approved on an older commit: no *Needs you* row, and *Bring it on…*
  listed as unable to run with that reason. Merged or closed shows as such, with when it was brought on. While it is
  sent, nothing changes until the daemon answers. A refusal shows in Porelo's words, naming the moved commit and that
  the central forge's commits come to the host's forge as the branch `central/main`. A pushed result names the new
  head. A project `offline` shows neither row nor action, and says so. A host forge not reachable keeps the last state
  with its time.
- **Red first:** a scenario in `test/features/work_handover.feature` where the pull request moves after its approval
  and *Bring it on…* cannot run.

## What it drops

- Comments, inline threads and review verdicts beyond the approval: move to the IntelliJ plugin's code review
  (`porelo-intellij`).
- Approving and merging from the interface: move to IntelliJ or the host's forge.
- Commit statuses: nowhere.
- The hidden token prompt for the central forge: nowhere; the person's SSH identity is used, and a token goes through
  its terminal as on the *Forges* page.
- Inbound public pull requests mirrored into the host's forge: nowhere here; their held comments are
  [F191](README.md#f191)'s.

## Acceptance

- The row shows the pull request's state, its approval with its commit, the target, and level, class and checks in
  one line. Seen to fail: a scenario where any is missing, or a check not complete reads as clean.
- *Bring it on…* cannot run unless the approval is on the pull request's current commit, and its call carries that
  commit, the repository and the pull request number. Seen to fail: a scenario where an approval on an older commit
  lets it run, or the call carries another commit.
- A refusal for a moved head shows in Porelo's words and changes nothing until the daemon answers. Seen to fail: a
  scenario where the row shows "brought on" before the answer.
- A project `offline` offers no bring-on. Seen to fail: a scenario where it does.
- No form in the interface takes a token. Seen to fail: a widget test finding a secret field.

## To be checked

- Whether the gathered push runs through `porelo` over Varlink, so the interface needs no ssh to the host.
- The method and field names the pull request and the bring-on get in `Tasks1`.
