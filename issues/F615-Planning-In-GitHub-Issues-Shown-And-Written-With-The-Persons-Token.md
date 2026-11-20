# F615 — Planning In GitHub Issues Shown And Written With The Person's Token

```json
{
  "$schema": "issue-1.json",
  "id": "F615",
  "title": "Planning In GitHub Issues Shown And Written With The Person's Token",
  "state": "Analyzed",
  "size": "S",
  "priority": "High",
  "rank": 1,
  "blockedBy": [],
  "covers": "The planning place shows a project planned in GitHub Issues through the planner's screen, raised to the screen that refuses a board it has no access for; the window answers that refusal by handing the person's forge token from the system secret store into this computer's Porelo vault, where the planner takes it"
}
```

**Why this size.** S: one member of the screen's `PlanningHost` implemented in `planning_embedding.dart` over the
existing token hand-on of `ForgeConnection`, the pin with its test fakes, one decision and the changelog; the board,
its dialogs and the start and stop hooks need no change of their own, and the window owns no contract here.

**What must be true.** A person whose project is planned in GitHub Issues sees its board, opens its issues, starts and
stops its tasks in the window as before; where the planner has no token for the forge, the planning place offers to
hand the person's own token on, and afterwards every change the planner writes to GitHub is written with it, while no
task ever holds it.

## The contract this builds against

- The planner keeps the issues behind its store. The planning screen package it publishes draws the board and the
  issue dialogs; the window gives that screen its place, its links, its wizards and its start and stop of tasks, as
  today.
- Story, issue and task are strings the window passes through without reading them: in its place, its kept offers and
  its reports. An issue carried over from Markdown keeps its old id, and the board serves it under that id, so a task
  started before the cut-over is reported under it afterwards; ids made later keep today's pattern.
- A planned stage's start still names the issues it reads as files, each a name and a text, which Start mounts read
  only; the planner renders an issue into that text as Markdown. A stage on a host starts through the host daemon's
  own `Start`, reached over the forwarded socket, which takes them as the local daemon's does.
- The planner takes the person's forge token for an `https` address from this computer's Porelo vault through
  `porelo vault credential --for <url>`, the executable the window names in `PORELO_EXECUTABLE`; the window never
  sends a token to the planner over its loopback connection. One token, the person's existing git token, also carries
  planning.
- Where the vault holds no token for the forge, or GitHub refuses it for want of a right, the planner refuses the
  board with `NoForgeAccess` (HTTP 403), with the field `address` and, where GitHub names it, `right` (`Issues`,
  `Projects`); its words are the planner's. The screen offers, beside that refusal, the host call
  `Future<bool> handOnForgeToken(String address)` of its `PlanningHost`, which the window implements, and reads the
  board again after `true`.

## Plan

- `lib/src/ui/planning_embedding.dart`, `ShellPlanningHost.handOnForgeToken`: puts the token the system secret store
  keeps for the address into this computer's vault under `git.token.<host>`, through `ForgeConnection`'s existing
  `putToken` path (`lib/src/app/forge_connection.dart`), asking for it first in the helper terminal
  (`askForForgeToken`, `lib/src/ui/forges_view.dart`) where none is kept; answers `false` where the person turns it
  away or the vault refuses, with the reason in the window's log and never the token.
- `pubspec.yaml`: the `porelo_planning` pin moves to the planner commit that brings `NoForgeAccess` and the call;
  `test/` fakes of `PlanningHost` and of the planning client follow the package's interfaces.
- `lib/src/ui/planning_embedding.dart`: the comment on `given` no longer says the issues are files of a repository;
  `doc/decisions.md` (*The planner is given the one Porelo the window vouches for*) says the lent token now also
  writes the planning to GitHub, with its exposure; `CHANGELOG.md`.
- Red first: a widget test in which the fake planner refuses the board with `NoForgeAccess` and the screen calls
  `handOnForgeToken`: the secret store's token lands under `git.token.github.com`, and the call answers `true`.

## Acceptance

- In the test organization, with a project planned in GitHub Issues: the board loads, an issue opens, a stage starts
  and its end is reported; moving an issue shows on GitHub at once, under the person's account.
- With the token removed from this computer's vault, the planning place offers to hand it on, and after it the board
  loads.
- No token appears in the window's log, the planner's log, a command line or a task's environment.

## To be checked

- Which planner commit brings `handOnForgeToken` and `NoForgeAccess`, for the pin.
