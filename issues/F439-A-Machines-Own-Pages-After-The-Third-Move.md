# F439 — A Machine's Own Pages After The Third Move

**Status:** Implementing.

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
