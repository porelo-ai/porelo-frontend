# F614 — A Given Token Is Not Asked For Again

```json
{
  "$schema": "issue-1.json",
  "id": "F614",
  "title": "A Given Token Is Not Asked For Again",
  "state": "Backlog",
  "size": "M",
  "priority": "Medium",
  "rank": 134,
  "blockedBy": [],
  "covers": "Once the token was handed to a machine for a project, the machine's page says that the token was given and the machine is taking the project, with the time since, and offers Give it my token again only when the machine's answer says it still waits; closing Putting <project> on <machine> reads the machine at once"
}
```

**Why this size.** M: it touches the window's record of a hand-over (`DeclaredHandOn`, `HostConnections`), the machine
page's progress words and its token button, and the placing dialog's close, with the token-wait races these already
guard; widget tests on the page and the dialog.

**What must be true.** A Machine Admin who just handed a machine the token for a project never reads on that
machine's page that the token is still wanted while the machine is only busy taking the project's repositories.

## Found

In a live setup of a rented machine. After *Putting porelo on <machine>* was closed, the machine page still said
"Waiting before <machine> takes them: porelo", offered *Give it my GitHub token…* and showed the project row as
"Waiting for your token". 30 to 60 seconds later it changed by itself to "Ready to work on: porelo" and "Carried".
The machine was taking 19 repositories in one run, a read key and a first copy each. It read as if the token had not
arrived.

## Plan

- Today: what the dialog reads of the machine reaches the page (`HostConnections.keepHeard` notifies it), but while
  the machine runs its read with the new token it still answers `waiting-for-token`. The page's chip
  (`_progressChip`), the connection line's "Waiting before … takes them" and `_giveTokenFor` in
  `organization_host_pages.dart` take that word as it is. The record of a hand-over, `DeclaredHandOn._answered`,
  keeps no time and the page does not read it; a token given by the page's own button ends the wait through
  `tokenTaken`, a declared hand-over does not. Closing `PlacingProjectDialog` reads nothing.
- Change: `HostConnections` keeps, per machine and project, when a token was handed on (declared or by a button),
  until the machine says the project is carried, held or refused, or a later read after the hand-over's own read still
  says it waits (not helped; as `_notHelped` in the dialog). While that record stands the page shows the row as
  "Token given, being taken" with the time since, leaves the project out of "Waiting before … takes them" and offers
  no token button. Closing the dialog asks the machine once (`connections.ask`, joining a read already on its way).
- Where the machine's answer already lists the project's repositories with their states (`HostProjectProgress.
  repositories`, `taken`), the row says "n of m taken"; otherwise it says no count.
- Red first: a widget test of the machine page with a hand-over recorded and a machine still answering
  `waiting-for-token`: today it shows "Waiting for your token" and the button; after the change it shows the token as
  given and no button. A second test: a later answer that still waits after the hand-over's read brings the button
  back with its reason. A third: closing the dialog asks the machine once.

## Acceptance

- After a token was handed on, the machine page never shows "Waiting for your token" or the token button for that
  project while the machine has not answered that it was not helped.
- The page says the token was given and how long ago, and "n of m taken" where the machine lists its repositories.
- A machine that still waits after the token was read gets the button back with its reason, as today.
- The three tests above fail without the change.

## To be checked

- Whether the machine fills `repositories` for a project while it still answers `waiting-for-token` or `pending`
  during that run; read on a host's `org status` answer. If not, the count waits for the machine to say it.
- The machine may come to say `taking`, with repositories done, their total (absent while it still counts) and since
  when, while a run with the token takes them, and a run that ends short returns to `waiting-for-token`, `held` or
  `refused` with its reason per repository (agreed, not built). The Machine Admin's page reads it from the host's
  status as root, as today; a member's own daemon serves it in the project's row. Once it is served, the page takes
  that word and its count in place of its own record of the hand-over.
