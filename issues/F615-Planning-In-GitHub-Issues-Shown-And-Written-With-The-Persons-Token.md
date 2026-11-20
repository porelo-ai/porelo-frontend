# F615 — Planning In GitHub Issues Shown And Written With The Person's Token

```json
{
  "$schema": "issue-1.json",
  "id": "F615",
  "title": "Planning In GitHub Issues Shown And Written With The Person's Token",
  "state": "Analyzed",
  "size": "M",
  "priority": "High",
  "rank": 1,
  "blockedBy": [],
  "covers": "The planning place shows a project planned in GitHub Issues through the planner's screen; the person's own forge token, which the planner takes from this computer's Porelo vault, is asked for with the rights planning needs, and a planner that finds no token or too few rights offers to hand it on"
}
```

**Why this size.** M: one contract change with the planner (a refusal the window answers and a host call), the token
words and the hand-on of the token into this computer's vault, the pin of the planning screen with its fakes, and the
documents; the board and its dialogs stay the planner's own screen.

**What must be true.** A person whose project is planned in GitHub Issues sees its board, opens its issues, starts and
stops its tasks in the window as before, and every change the planner writes to GitHub is written with the person's
own token, which the window asks for once with the rights planning needs and never hands to a task.

## The contract this builds against

- The planner keeps the issues behind its store. The planning screen package it publishes draws the board and the
  issue dialogs; the window gives that screen its place, its links, its wizards and its start and stop of tasks, as
  today.
- Story, issue and task are strings the window passes through without reading them: in its place, its kept offers and
  its reports. An issue carried over from Markdown keeps its old id.
- A planned stage's start still names the issues it reads as files, each a name and a text, which Start mounts read
  only; how the planner renders an issue into that text is the planner's.
- The planner takes the person's forge token for an `https` address from this computer's Porelo vault through
  `porelo vault credential --for <url>`, the executable the window names in `PORELO_EXECUTABLE`; the window never
  sends a token to the planner over its loopback connection.
- Where the vault holds no token for the forge, or GitHub refuses it for want of a right, the planner refuses with a
  code the window recognizes, naming the forge's address and, where GitHub says it, the right missing.

## Plan

- `lib/src/ui/forges_view.dart`, `tokenRightsWords`: the token also needs Issues (read and write) on the project's
  repositories and Projects (read and write) on the organization, for planning; `lib/src/app/forge.dart`'s 403 hint
  names Issues for an `/issues` path and Projects for a GraphQL project field refusal.
- `lib/src/ui/planning_embedding.dart`, `ShellPlanningHost`: implements the screen's new host call for the planner's
  no-access refusal by offering to hand the person's token from the system secret store into this computer's vault,
  through `ForgeConnection`'s existing `putToken('git.token.<host>')` path (`lib/src/app/forge_connection.dart`), and
  asking for the token in the helper terminal where the secret store has none; the board is read again afterwards.
- `pubspec.yaml`: the `porelo_planning` pin moves to the planner's head that brings the GitHub store and the call;
  `test/` fakes of `PlanningHost`, `PlanningClient` and `PlanningTaskChanges` follow the package's interfaces.
- `lib/src/ui/planning_embedding.dart`: the comment on `given` no longer says the issues are files of a repository;
  `doc/decisions.md` (*The planner is given the one Porelo the window vouches for*) says the lent token now also
  writes the planning to GitHub, with its rights and exposure; `doc/design.md`'s planning place likewise; `CHANGELOG.md`.
- Red first: a widget test in which the fake planner refuses the board with the no-access code shows the offer, and
  taking it puts the secret store's token under `git.token.github.com`; a unit test that `tokenRightsWords` names
  Issues and Projects.

## Acceptance

- In the test organization, with a project planned in GitHub Issues: the board loads, an issue opens, a stage starts
  and its end is reported; moving an issue shows on GitHub at once, under the person's account.
- With the token removed from this computer's vault, the planning place offers to hand it on, and after it the board
  loads; with a token lacking Issues, the board says that right is missing and where to give it.
- No token appears in the window's log, the planner's log, a command line or a task's environment.

## Open questions

- One token or two: planning needs Issues and organization Projects rights beside Contents. One token kept as today
  is simpler; a second, planning-only token kept apart limits what a machine holding the git token can reach. The
  analysis assumes one.

## To be checked

- With the planner: the refusal code and its fields, the host call's name and answer, and whether `given` stays a list
  of name and text.
- With the planner: that a task started before the cut-over and reported after it is accepted under its old ids, so
  the window's kept offers need no rewrite.
- Whether a fine-grained token waiting for the organization's approval of Projects is said as waiting, as for
  Contents.
