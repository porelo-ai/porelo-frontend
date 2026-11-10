# F439 — A Machine's Own Pages After The Third Move

```json
{
  "$schema": "issue-1.json",
  "id": "F439",
  "title": "A Machine's Own Pages After The Third Move",
  "state": "Review",
  "size": "M",
  "priority": "Medium",
  "rank": 14,
  "blockedBy": [],
  "covers": "One header with *Open its forge* in sight, *Machine Admins* alone, a project's repositories on a machine, *New work* without a needless question, a dead forge forward noticed."
}
```

**Why this size.** the header and *Machine Admins*, the project's repositories, *New work*, the forward's check.

**What must be true.** A machine's page has one header with its actions in sight, a project opened from the machine
shows what of the project is on that machine, *Machine Admins* shows the admins alone, *New work* on a machine asks
nothing the window knows, and a forge forward that stopped answering is noticed and raised anew.

## Why

The third move (2026-11-08), findings 5, 6, 9, 15 and 23, decided by the operator that evening with the design
*Third move findings, before and after* (pairs 6+15 and 9).

## Acceptance

- **One header** (findings 6, 15): a remote machine's page shows its path, name and state chip once, its Porelo
  version and when it last answered, and *Open its forge* as a visible button beside *Disconnect* (not only in a ⋮).
- **Machine Admins** (finding 6): the machine's leaf *Managing this machine* is named *Machine Admins* on a machine
  with an organization's card, and shows the Machine Admins, *Add a Machine Admin* and *Make a backup key* only, no
  project details and no repeat of the machine's page. This computer keeps *Managing this machine* as designed.
- **A project on a machine** (finding 5): *My machines → <machine> → Projects → <project>* shows the project's
  repositories on that machine, one row each: carried, not carried or held; its state at central (up to date,
  ahead); its running tasks. The general project page is one link at the top, and the list *Machines* with the same
  machine again is gone.
- **New work on a machine** (finding 9): on *<machine> → Tasks*, *New work* opens with the project preselected when
  the machine carries one besides Default, with a *change* link for another; no dialog asks it first. The repository
  and the task's name are asked in the same form.
- **A dead forge forward** (finding 23): when the machine's forge gives no answer through the forward (an empty reply
  or none), the machine's page says "The host's forge gives no answer through this computer's forward" and *Open its
  forge* raises the forward anew before opening. The host's side of the cause is the machine's (said in the room).

## Size

M: S the header and Machine Admins, S the project's repositories (with the machine's data as the room settles it),
XS New work, S the forward's check.

## How it stands

Built, each point with a widget test seen red first (`test/ui/machine_own_pages_test.dart`, the forge's in
`test/ui/organization_host_pages_test.dart` and `test/app/organization_connections_test.dart`).

- One header: the page's head carries the state chip (of this computer's connection), `Porelo <version> · last answered
  <time>` (the daemon's last list, or the host's own answer, whichever is later; *not read* otherwise), and *Open its
  forge* as a button beside *Disconnect*; the embedded facts no longer repeat path, title, kind line, State or Porelo.
  The organization's row keeps *Open its forge* in its ⋮.
- Machine Admins: the leaf is named so where the window has an organization and the machine a card; it shows the
  admins' list with its two actions under one head. This computer keeps *Managing this machine*.
- A project on a machine: opened from the machine's Projects or its page, the path goes back there, the Machines list
  is gone, a link opens the organization's page of the project (or its page under My projects), and each repository's
  row says carried / not carried / held, its central state and the tasks running in it. The carry and central state
  come from the host's `org status`, which only a connected Machine Admin reads; for anyone else they say *not read*,
  with the reason once above the rows. Missing from the daemon for that: per-repository carry and central state for a
  person who is no Machine Admin. Running tasks are the person's own daemon's; other persons' tasks on the host are
  not seen.
- New work: from a machine's Tasks or page, one project besides Default is preselected; *change* closes the form and
  asks the project.
- Dead forward: the page asks the forge (`HEAD /` on the forwarded port, five seconds; no byte back is none) when the
  connection is up, when the page opens and on refresh, not on a timer; one five-second limit holds for connecting,
  asking and the first byte. *Open its forge* re-adds only the forge's forward on the live ssh master (`-O cancel`,
  then `-O forward`), never the master that carries the terminals and the daemon's link, and at most once in thirty
  seconds; a forge still dead after it is said as caused on the host. A refused or failed raise is said beside the
  page's button and in a snack bar from the organization's row.
- A project page opened from a machine that does not answer shows the machine's state beside its title and its tasks
  as not read; one shown by the finder forgets the machine it was opened from. A card machine the organization does
  not name keeps *Managing this machine*.
