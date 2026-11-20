# F615 — Planning In GitHub Issues Shown And Written With The Person's Token

```json
{
  "$schema": "issue-1.json",
  "id": "F615",
  "title": "Planning In GitHub Issues Shown And Written With The Person's Token",
  "state": "Review",
  "size": "S",
  "priority": "High",
  "rank": 1,
  "blockedBy": [],
  "covers": "The planning place shows a project planned in GitHub Issues through the planner's screen, raised to the screen that refuses a board it has no access for; the window answers that refusal by handing the person's forge token from the system secret store into this computer's Porelo vault, where the planner takes it"
}
```

**Why this size.** S: one optional interface of the screen implemented in `planning_embedding.dart` over the
existing token hand-on of `organization_access_dialogs.dart`, the pin with its test fakes, one decision and the changelog; the board,
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
- Where the vault holds no token for the forge, or GitHub refuses it for want of a right, the planner refuses with
  `NoForgeAccess` inside its existing 502 answers (`StoreRefused` on reads, `SaveRefused` on writes), named by the
  type `urn:porelo-planner:NoForgeAccess`, with `parameters.address`, the forge's https origin with no user, port,
  path, query or fragment, and `parameters.right` where GitHub names one (`Issues`, `Projects`); its words are the
  planner's.
- The window's call is an optional interface of the screen package beside `PlanningHost`:
  `PlanningForgeAccess.handOnForgeToken({required String provider, required String address})`. The screen offers it
  only to a host that implements it; `provider` is the name of the planning provider whose planner refused, so the
  token goes into that machine's vault; the call answers `true` only when a token now stands there, and the screen
  then reads the board again.

## Plan

- `lib/src/ui/organization_access_dialogs.dart`: the part of `prepareOrganizationForge` after it parsed the
  repository (open the local vault, follow a declaration, ask for the token where the secret store keeps none, hand
  it to the vault under `git.token.<host>`, confirm it there) moves into a function of its own, which
  `prepareOrganizationForge` calls unchanged; beside it `prepareForgeForPlanning(context, origin, forges)` takes the
  planner's origin through `planningForgeHost`, which refuses anything but `https://<host>` with at most a lone `/`
  (read from the text itself, so no user, port, not even `:443`, query, fragment, other scheme or upper-case scheme;
  the host through `forgeAddress`), and calls the
  same function for `https://<host>/`. On that path a declaration naming another source than the vault is refused in
  words and never turned to the vault: the planner's ask names only the forge.
- `lib/src/ui/planning_embedding.dart`, `ShellPlanningHost` also implements `PlanningForgeAccess`: for the provider
  `LocalPlanner.name`, this computer's planner, it runs the hand-on it is given and answers `true` once this
  computer's vault resolves a token for the forge (a declaration already present counts); for any other provider, a
  machine whose vault this window does not hand tokens to this way, for an origin `planningForgeHost` refuses, and on
  any refusal it answers `false` and says why in the window's log, naming only the host, never the address as received
  or the token. One hand-on runs at a time: the same ask while one runs gets that one's answer and opens nothing more,
  any other answers `false` at once. The screen calls it only from the person's press on its offer.
- `lib/src/ui/shell.dart`: the shell gives its `ShellPlanningHost` that hand-on, as `prepareForgeForPlanning` with its
  own context, `ForgeConnection` and terminal, refusing once the shell is no longer mounted.
- `pubspec.yaml`, `pubspec.lock`: the `porelo_planning` pin moves to the published planner commit with the contract,
  and on to the one whose screen offers the hand-on where the board was refused for want of the token.
- `lib/src/ui/planning_embedding.dart`: the comment on `given` no longer says the issues are files of a repository;
  `doc/decisions.md` (*The planner is given the one Porelo the window vouches for*) says the lent token now also
  writes the planning to GitHub, with its exposure; `CHANGELOG.md`.
- Tests, each seen red with its guard broken: `test/ui/planning_forge_access_test.dart` calls
  `ShellPlanningHost.handOnForgeToken` with a recording hand-on: another provider answers `false` and never runs it;
  this computer's planner runs it with the bare origin and answers `true`, and refuses an origin with a path, user,
  port or another scheme; a refused or failed hand-on answers `false`; a second same ask while the first runs runs nothing
  more, and an ask for another forge or provider meanwhile answers `false`; a host given no hand-on answers `false`. In `test/ui/organization_access_dialogs_test.dart`, `prepareForgeForPlanning` refuses thirteen malformed origins
  before the vault or the token is touched, puts the secret store's token under `git.token.github.com` once, and
  refuses a declaration naming the environment in words, with no dialog and nothing declared.

## Acceptance

- In the test organization, with a project planned in GitHub Issues: the board loads, an issue opens, a stage starts
  and its end is reported; moving an issue shows on GitHub at once, under the person's account.
- With the token removed from this computer's vault, the planning place offers to hand it on, and after it the board
  loads.
- No token appears in the window's log, the planner's log, a command line or a task's environment.
