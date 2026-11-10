# F437 — Join, Leave And Accept A Card In The Window

```json
{
  "$schema": "issue-1.json",
  "id": "F437",
  "title": "Join, Leave And Accept A Card In The Window",
  "state": "Backlog",
  "size": "M",
  "priority": "Medium",
  "rank": 8,
  "blockedBy": [],
  "covers": "Join an organization by a card proposal, an owner accepting it on the person's row, and leaving an organization, from the window."
}
```

**Why this size.** the organization source's propose, list, accept, turn-down and leave calls with their stand-ins,
the join's waiting answer, the proposed person's row with its *Accept* and *Turn down*, and the leave's question;
S the join, S the acceptance, XS the leave.

**Blocked by** the backend's card proposal and acceptance, and by its leaving an organization.

**What must be true.** A person who cannot write an organization's repository asks to join it from the window, by
filing their card as a proposal; an owner sees the proposal on the waiting person's row in *People* and accepts it
there; and a member leaves an organization from the window, which withdraws their own card and roles and forgets the
organization on this computer.
- A proposal grants nothing until accepted: the row says *proposed*, never a role.
- An owner alone sees *Accept* and *Turn down*; anyone else sees the row without them.
- Leaving is refused, in the backend's words, where it would leave the organization without an owner, and the window
  names who could take the place as the backend says.

**Blocked by** the backend's card proposal and acceptance (a card filed as a proposal by a person who cannot write
the repository, accepted by an owner) and its `porelo org leave` (one's own card withdrawn, one's roles revoked, the
organization forgotten on this machine), each readable and callable by the window.

## Why


The operator's word (2026-11-08): card proposal and acceptance, yes; leaving an organization, yes. The side bar's
organization pages show *Join an organization…*, *Accept a proposed card…* and *Leave <organization>…* as actions
waiting for a command; until the backend offers them, they stay greyed.

## Plan

- **The organization source** (`lib/src/app/porelo_organization_source.dart`, beside `org person revoke` at
  `OrganizationChange.revokeCard`): `proposeCard(organization)`, `proposedCards(organization)`,
  `acceptCard(organization, login)`, `turnDownCard(organization, login)` and `leave(organization)`, each over the
  backend's `--json` answer, read leniently like the other answers there; an unknown command answers *not offered by
  this porelo*, and the action stays greyed with that reason. The stand-ins in `lib/src/mock/` and the feature
  world's fake source answer the same.
- **The organization's facts** (`lib/src/ui/shell.dart`, the *Proposed cards* fact that says today *not read — the
  organization source does not list proposed cards*): the count of waiting proposals as the backend lists them.
- **The waiting actions** (`shell.dart`, `waiting:` of the organization row): *Join an organization…*, *Propose a
  card…*, *Accept a proposed card…* and *Leave <organization>…* become commands once the backend offers them.
  - *Join an organization…* keeps today's choice of the organization; where the person cannot write its repository it
    proposes the card instead, and the page says it waits for an owner, with the proposal's row.
  - *Accept a proposed card…* opens *People* (`OrganizationSection.people`) at the first proposed row.
  - *Leave <organization>…* asks once, naming what goes (one's card, one's roles by name, the organization on this
    computer), then leaves; the side bar forgets the organization when the backend says it is gone.
- **People** (`lib/src/ui/organization_page.dart`): a proposed person's row with the chip *proposed*, its login and
  key as the backend reads them, and for an owner *Accept* and *Turn down* (asking once), each a call; a refusal is
  said on the row in the backend's words.
- **Features:** `test/features/organization_join.feature` (proposal filed and waiting; a writer files the card at
  once; the source without proposals greys the action), `organization_proposals.feature` (owner accepts, owner turns
  down, a non-owner sees no buttons, a refusal kept), `organization_leave.feature` (asked once and left; refused for
  the last owner with the backend's words; cancel leaves nothing changed).

## Acceptance

- Each feature above runs red before the code and green after; a proposed row with an *Accept* for a non-owner, a
  proposal shown as a member, or a leave that goes without asking fails a scenario.
- Against the backend on the VM: a second identity proposes, the owner accepts in the window, and `porelo org` lists
  the person; the person leaves, and `porelo org` lists them no longer.

## Open questions

- None.

## To be checked

- The backend's command names and `--json` answers once its plan reading has settled where a proposal is kept; the
  plan follows them.
- Whether turning a proposal down is offered by the backend, or only accepting (the row then has *Accept* alone).
