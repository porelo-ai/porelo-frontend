# F336 — A Host's Page Reads As A Way To Work

**Status:** Review.

**What must be true.** A person on a host's page sees at once whether this computer is connected, what that means and what
ending it does, and is led from there to working on the host.

**The operator:** built with [F335](README.md#f335).

## How it reads now

Read from the code, not run.

- **The blocks, top to bottom:** `OrganizationHostPage` in `lib/src/ui/organization_host_pages.dart` shows
  the way back, the name, the connection block, work details where supplied, then *Managing this machine*
  for an admin, address and key, the machine's progress, *Projects on this machine* and *Machine Admins*.
- **The connection block** explains not connected, connected while waiting for an account, and ready,
  with *Connect*, *Disconnect* and *Start work* as applicable. It explains what *Disconnect* ends.
  `CardHostConnections.disconnect` in `lib/src/app/organization_connections.dart` keeps the saved machine,
  marked disconnected, through `Machines.disconnect` in `lib/src/app/machines.dart`.
- **The row** is `OrganizationMachineRow` in `lib/src/ui/organization_host_pages.dart`; it shows
  connection words and *Connect*, with a disabled button while its connection attempt is running.
  That row and `OrganizationHostPage._connection` in the same file have no separate *Connecting* words,
  so they do not meet step 2's promise to say so at once.
- **The work path is incomplete.** `OrganizationHostPage._projects` in
  `lib/src/ui/organization_host_pages.dart` has no *Start work* on project rows. The top *Start work*
  callback in `lib/src/ui/shell.dart` calls `_startInDefault()`, so it does not fill in a named project
  as the path below promises. *Work on it* on `OrganizationProjectsPage` opens the machine page when
  the project is not yet listed by its daemon.

## The recommendation

**At the top, under the name, for everyone,** one block with the state, its meaning and its action:

| State | It says | Action |
|---|---|---|
| Not connected | This computer has no connection to `<host>` yet. You need one to work there; it is set up once, whatever number of projects the host carries. | *Connect* |
| Connected, no account yet | Connected. `<host>` makes your account once it has read the organization, up to five minutes after your project is on it, and only once its admin has given it the token. | *Disconnect* |
| Connected, ready | Connected as `<login>`. Ready to work on: `<projects>`. | *Start work*, *Disconnect* |

**Under *Disconnect*,** in small words: *Ends this computer's connection only. Your account, work and vault on the host stay, and
Connect brings it back.* It needs no question then, being that easy to undo. The button's label can stay.

**Below it, under a heading of their own such as *Managing this host*,** what only an admin does: address and key, the token,
projects and admins. A person who is no admin reads what they read today, in the same order, without the buttons.

**Each project's row** offers *Start work* where this person can, which is the step this page lacks now.

## The whole path, as a person reads it

1. *A host of mine:* its row says `Not connected`, with *Connect*.
2. *Connecting:* the row and the page say so at once, as [F331](README.md#f331) asks.
3. *Waiting:* the page says for what, and for whom: the admin's token, or up to five minutes for the account; the row does not flip,
   as [F334](README.md#f334) asks.
4. *Ready:* the row says `Connected · ready to work on <projects>`, and the page and each project's row offer *Start work*.
5. *Working:* *New work* opens with that host and project filled in, and the work stands under *Work*.

Where this page stands, and what the row is called, follows [F335](README.md#f335).

## To be checked

- That *Work on it* really ends on this page with nothing to do, by walking it.
- That *New work* can be opened with a host and project already chosen, for a project the host does not list yet. A host lists
  a project only after the person's first start there.
- Whether the account's five minutes and the token's wait can be told apart from what the host answers today.
