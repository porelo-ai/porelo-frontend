# F335 — One Row Per Machine

**Status:** Review.

**What must be true.** *Organization* lists the organization's available machines. *Machines* is a person's own view of what they use: always the local
machine, plus what they added. A server appears under *Machines* only after *Connect*, which is offered in *Organization* and on a project's row. It stands there once, with everything that
can be done with it reached from that row. "Host" is a technical term and appears nowhere in the interface's words.

## The operator's decision

To a person there is no difference between a host and a machine: there is one set of servers, called *Machines*, on which a person may run tasks where they have an
account. Which of them are theirs to use is their own list, and it is not joined from the organization.

## How the rows stand

Read from the code, not run. `MachinesPage` in `lib/src/ui/machines_page.dart` has one *Machines* section,
using the person's saved machines and `listedMachines` in `lib/src/app/machines.dart` to keep this computer
listed. A preparation replaces the machine of the same name. `OrganizationPage._hosts` in
`lib/src/ui/organization_page.dart` lists every organization machine under *Machines*, using
`OrganizationMachineRow` and `view.myHosts` to offer *Connect* to a person with an account.

Both lists open `OrganizationHostPage` through `_machineOnePage` in `lib/src/ui/shell.dart` for a machine
with a card. Work, daemon and vault details are included when its saved machine is opened.
Each row has one menu; the organization's row also shows *Connect* while not connected.
`MachinesPage._row` keeps *Connect* in its menu, so it does not meet the visible row action promised below.

`_movedPast` in `lib/src/app/organization_connections.dart` notices a missing organization card, but
`MachinesPage._row` in `lib/src/ui/machines_page.dart` does not read organization access or removal.
`Machines.raiseAgainIfNeeded` in `lib/src/app/machines.dart` checks the disconnected mark without checking
whether access has gone. The promised lost-access words and stop to retries are not built on that path.
`_organizationHost` remains in `lib/src/ui/shell.dart`, and opening an unsaved organization machine moves
to *Machines*. The *Start work* gaps are stated in [F336](README.md#f336).

## The shape

- ***Machines*:** `Machines.all`, as today: the local machine, each private one reached over ssh or WSL, and each server of the organization after *Connect*. The *Hosts* section goes, and nothing joins it
  to the organization's list, so *Machines* holds only what this person chose.
- **In its row:** *Connect* while disconnected. Everything else is in its one ⋮, following [F329](README.md#f329)'s decision.
- ***Organization*:** its list of all the organization's servers, under the heading *Machines*, with what an Organization Admin and its Machine Admin do with them. A person with an account there
  has *Connect* in the row; once connected the row says so.
- **A preparation** stands in the one row under *Machines*, in place of what it becomes.
- **What stays technical:** `porelo-host` and its commands, `porelo org host …`, field names in answers, paths such as
  `/etc/porelo-host/`, ids in the code and the commands' keys. None of these is renamed by this issue.

## The three operations

| | *Connect* | *Disconnect* | *Forget* | Taking it down |
|---|---|---|---|---|
| Where | *Organization*; a project's row; under *Machines* after *Disconnect* | the row under *Machines* | the row under *Machines* | see below |
| Under *Machines* | appears | stays, with *Connect* | gone | gone from the list of the person who did it |
| In *Organization* | says connected | stands, with *Connect* | stands, with *Connect* | gone |

The local machine stands always, and offers neither *Disconnect* nor *Forget*. `MachinesPage._row` in
`lib/src/ui/machines_page.dart` omits its connection action and disables forgetting it; `_forget` in
`lib/src/ui/shell.dart` also refuses it. Since *Forget* leaves the server in *Organization*, no forgetting
needs remembering.

## A person with no right on a server

**The right is an account,** and no separate right exists. Server behavior is not checked here: a person
has an account on a server by administering it or by belonging to a project it carries, and the server's
task check takes a task of the default project from anyone admitted.

The rule stays and moves. `myHosts` no longer decides who has a row under *Machines*, as nobody has one before their own *Connect*. It decides who is offered *Connect* in
*Organization*:

- **No right, and not connected:** the read-only row in *Organization*, as every member reads it today, with no *Connect*. It has no row under *Machines*.
- **Connected, and the right has since gone:** this person's own list keeps the row, since nothing joins it away. It says that they no longer have access there and whose it is to
  change, does not keep retrying, and offers *Disconnect* and *Forget*. So a row under *Machines* still reads the organization for its words, though not for its existence.
- **The server has left the organization,** taken down by someone else: the same row says so, and offers *Forget*. `_movedPast` in `organization_connections.dart` already sees that.

**A task with no project is a task of the default project,** on a server as on any machine.
The Core command is not run here:
`porelo task start --host <server> --project default` reaches the start, given an ssh login to the person's account there. A blank
`--project` is refused, so the interface names the default project in that call.

## What else it changes

The lists, connection mark, shared page and role gates are built. Remaining gaps are named beside the code;
the requirements below still apply.

- **[F336](README.md#f336), first:** its path starts in *Organization*: step 1's row with *Connect* stands there, and only from step 2 on is there a row under *Machines*. The
  page's top block keeps its three states, and *Not connected* now also means disconnected, under *Machines*. It says that *Connect* brings it back and *Forget* takes it off
  this person's list. *Start work* in the default project is for anyone with an account there. *Managing this host* becomes *Managing this machine*, and an admin
  reads it whether connected or not.
- **[F337](README.md#f337):** the rule stands, and the rail stays as `doc/decisions.md` has it. As the pages become one, its table's rows for a host's page and a machine's page
  become one row, and `_organizationHost` goes. A server opened from *Organization* moves the rail to *Machines* today, which needs reading again: it may not be in this
  person's list.
- **[F338](README.md#f338):** *Connect to <machine>* on a project's row connects at once, as decided, so *Connect* stands there and in *Organization*. *Work on it* and the other words stand with "machine" for "host".
- **[F341](README.md#f341):** the lines say `<machine>` and *it*. The token takes the admin's connection, so the page leads to *Connect* first.
- **[F342](README.md#f342):** decided there: from the organization's projects, a machine's admin puts a project on it. So *Organization*'s project row holds *Put it on a machine…*, chosen among machines the person administers, read from the organization, connected or not.
- **[F343](README.md#f343):** the same list on the machine's page, connected, and its title.
- **[F329](README.md#f329):** the two lists keep separate rows with separate menus. Under *Machines* the ⋮ holds the entries of today's machine row. *Organization*'s row holds
  *Connect* and what an Organization Admin and its Machine Admin do.
- **[F334](README.md#f334):** its steady line is the row's under *Machines*; a disconnected machine no longer tries.
- **[F331](README.md#f331), [F332](README.md#f332), [F333](README.md#f333), [F339](README.md#f339), [F340](README.md#f340):** the words only, *Prepare the host* among them.
- **The pickers:** *New work* asks where it runs among the machines that answer, as `doc/decisions.md` says, so a connected server is there already and a disconnected one is not. The
  project picker that follows offers the default project on a server as well.
- **The code of the rows:** `OrganizationMachineRow` in `lib/src/ui/organization_host_pages.dart` is
  used by `OrganizationPage._hosts` in `lib/src/ui/organization_page.dart`. `MachinesPage` in
  `lib/src/ui/machines_page.dart` reads the person's own list without joining the organization's list.
- **The words:** page and action labels in `organization_host_pages.dart`, `organization_page.dart`,
  `machines_page.dart`, `host_dialog.dart` and `commands.dart` use *machine*, with *SSH host key* as decided.
  Technical names remain. A complete audit of all interface words in `lib` is not checked here.
- **Words from elsewhere:** a refused write shows the store's words as they come, and `org status`'s and `porelo-host`'s lines reach the screen
  too, and those say "host". Those lines belong to Core and Machines; until they change them, "host" still reaches the screen by that way.
- **`doc/decisions.md`:** a section of its own for this decision. *Machines say where work runs* holds as it stands. *Daily work in front, setting up apart* keeps its rail. `doc/index.md`'s
  setup words and `doc/design.md`'s *Projects on prepared hosts* follow, with the role as decided below.
- **Walks and tests:** those that find rows by `my-host`, `machines-row` or the *Hosts* section, the feature steps on the machines page, and every walk that connects from *Machines*.

## Decided by the operator

- **One page per server as well,** as two pages are a difference a person sees, reached from either list. Its top is [F336](README.md#f336)'s block, then work, daemon and
  vault, then *Managing this machine* for its admin. It is the largest part; the row could lead to today's two pages for a while.
- **The role reads *machine admin*** in the interface, and "admin" where the page already says which machine. In Core and in the organization
  it stays what it is.
- ***Prepare a machine…*,** for one word.
- ***SSH host key* stays** where a person compares it with what ssh shows, and the button reads *Change address and key…*.
- ***New work* offers no machine that is not connected,** since nothing can run there.
- ***Without a project* stays** what a person reads for the default project, and *Projects* lists no *Default*, as `doc/decisions.md` has it.
- **Two operations.** *Disconnect* ends this computer's connection; the machine stays under *Machines* and *Connect* there brings it back. *Forget* takes the entry out of the
  person's list; it stands on in *Organization*. If the person is an admin of that server, *Forget* warns first that the server keeps running.
- **A machine's admin may remove it from the organization.**
- **The owner acts rarely,** and the roles below do the operational work.
- **A machine added over ssh or WSL is private.** It stands only under *Machines*, marked clearly as a private machine, with *Connect* and *Disconnect*. *Forget* deletes the entry, so it is added anew there.
- ***Prepare a machine…* stands in *Organization*.**
- ***Connect to <machine>* on a project's row connects at once,** so it stands there and in *Organization*.
- **The words for taking a machine down are *Take Porelo off this machine…* and *Return this rental…*,** and a machine that simply exists has the same two places as a rental.
- **A third operation: taking a server down,** for a rented one giving it back, also removes it from the organization's list. Renting a server or
  setting one up by hand must enter it in the organization.

## The roles

Each level answers for the one below and may always create, change and delete there.

| Role | Answers for | Where that stands |
|---|---|---|
| Owner | owners and Organization Admins | `owners.yml` and a new file |
| Organization Admin | cards, projects' card, machines, and the admins of projects and machines | `members.yml`'s admins, `host.yml`'s admins |
| Machine Admin | the machine's card, its carried projects, its token, taking Porelo off | |
| Project Admin | developers, repositories and the project's address, `project.yml` | `projects/<project>/repository.yml` |

A change or replacement of a Machine Admin by an Organization Admin takes effect on a running server at its
next follow, with no confirmation by the former admin. Core and Machines file what that takes.
The interface's role gates are built in `lib/src/app/organization_source.dart`; the server's follow is not
checked here.

**What the table asks of these pages,** read from the code, not run:

- **Role gates:** `lib/src/ui/organization_page.dart` uses `view.isOrganizationAdmin` for cards,
  projects and machines, `view.mayRemove(host)` for removal, and `view.isOwner` for owners and
  Organization Admins. `OrganizationView.organizationAdmins` in `lib/src/app/organization_source.dart`
  reads `organization_admins` through `lib/src/app/porelo_organization_source.dart`.
- **A new machine:** an Organization Admin enters it and names its Machine Admin, who may be themselves. That answers who enters one. *Prepare a machine…* in *Organization* then runs for that Machine Admin, as `access.unavailable` already asks.
- **Removing a machine:** by the operator's word its Machine Admin may and an Organization Admin may. The owner no longer does. Taking Porelo off removes the entry, and *Remove the machine…* under *Organization* stands for the same right: `mayRemove` is the one rule for both, and the machine stays the guard for taking it down. Where the organization's answer says a person is neither, the window says so instead of offering.
- **A return, or taking Porelo off, under *Organization*** starts for its Machine Admin or an Organization Admin. Under *Machines*, for its Machine Admin.
- **Naming further admins:** by the operator's word a Project Admin or Machine Admin does not name further admins of that level; that is the Organization Admin's. So *Add* under the machine's *Host admins* and a member's change of role to admin on the project's page leave those roles and go to an Organization Admin, in *Organization*. It changes today's `org host admin add` and `project member role`, which are Core's.
- **The project's page:** a Project Admin changes developers and repositories, and keeps *Change the address…*, as the page offers today.
- **Words:** *Organization Admin*, *Machine Admin* and *Project Admin* in the interface. This replaces the *machine admin* decided above only in its capitals.

**The role contract:** `OrganizationView.organizationAdmins`, from `porelo org`'s `organization_admins`,
is the one seam. While it is null, owners act as Organization Admins, Machine Admins name their peers,
and Project Admins change member roles. Once it exists, `isOrganizationAdmin`, `mayNameAdminsOf`,
`mayRemove` and `mayChangeMember` gate these pages, and an owner lists people under *Organization Admins*.

**Built:** *Organization* lists machines, with *Connect* for a person with an account and *Prepare a machine…*
in its header. *Disconnect* keeps the entry with `disconnected: true`, and nothing raises it until *Connect*.
The local machine cannot be forgotten, and the warning goes to a machine's admin or the person who set it up.
A server has one page, from either list, with details inside it when its saved machine is opened.
Test coverage of that path is not checked here.

## What the two operations ask of today's code

Read from the code, not run.

- **`disconnect` in `lib/src/app/organization_connections.dart`** calls `machines.disconnect`.
  It must keep the entry and only end the connection. `Machines._mark` in `lib/src/app/machines.dart` does so.
- **A saved mark.** A disconnected machine stays disconnected after a restart, so its entry in
  `frontend.json` says so. `Machine.stored` in `lib/src/app/machines.dart` writes `disconnected: true`,
  and `connected` in `lib/src/app/organization_connections.dart` checks the mark. `doc/design.md` makes
  that file a contract with `porelo-intellij`, changed only after agreement in both, so the plugin must
  learn not to connect to such an entry. The plugin's behavior is not checked here.
- **Nothing raises it again by itself.** `_openAndConnect` and `raiseAgainIfNeeded` in
  `lib/src/app/machines.dart` skip a disconnected machine, which is a decision, unlike a forward that dropped.
  Its row says *Not connected*, not *not answering*, and it is left out of what asks every machine:
  the notices, the refresh for all, and *New work*. The notices path is not checked here.
- **What *Connect* does on it.** A machine of the organization is written anew from its card, as today. Every other kind has only its saved entry
  to raise from.
- **Every kind has to mean something.** `dropAndUnpublish` applies to a forward this interface raised. It is to be read per kind what *Disconnect* does on
  this computer, on WSL, and on a socket somebody else forwarded, which this interface can only stop watching.
- **The local machine.** `MachinesPage._row` in `lib/src/ui/machines_page.dart` disables *Forget*
  for this computer, and `_forget` in `lib/src/ui/shell.dart` refuses it; it must not be forgotten.
  `Machine.local` in `lib/src/app/machines.dart` names the local socket; a WSL distribution is a
  separate entry. What *always* means on Windows when no WSL distribution is set up is still to be checked.
- **Who gets the warning.** `_warnsOnForgetting` in `lib/src/ui/shell.dart` checks for a host entry
  and warns its admin, a person with a saved setup, or where the organization names no matching card.
  The test becomes that the person is an admin of that server, one who rented it counting as one.
  It also says that the server stays in *Organization*.
- **[F336](README.md#f336):** its words for *Disconnect* come true only with this, so this comes first or with it.

## Taking a machine down: a machine that exists, and a rental

The operator: *Give the machine back* is a poor name, as it concerns only a rented machine. The organization's settings must tell a machine that simply exists from an
active rental with a later return. A return can be started in two places: always under *Organization*, and under *Machines* by an admin who may do it. A machine that simply exists has the same two places.

**The words,** of which the operator decided the two actions, and the rest proposed:

| | A machine that simply exists | An active rental |
|---|---|---|
| The action | *Take Porelo off this machine…* | *Return this rental…* |
| Its question says | The accounts named and all they hold here are deleted, and it leaves the organization's list. The machine itself stays yours. | The same, and the provider then removes the machine, which ends its billing once the provider confirms. |
| Button, with holders | *Delete these accounts and take Porelo off* | *Delete these accounts and return it* |
| Button, without | *Take Porelo off* | *Return it* |
| What stays to do | nothing of Porelo's; the person ends any contract at their provider | nothing, once confirmed |
| When a step of it fails | it stays, says what would be lost, and offers to go on anyway | the same, and it stays billed |

*Take Porelo off* is what `down` on `--given` does by its own words, *nothing is rented or given back*.
`lib/src/app/commands.dart` and `lib/src/ui/host_dialog.dart` choose *Take Porelo off this machine…*
for a given machine and *Return this rental…* for a saved rental, with matching confirmation buttons.

**Until 0.9 there is no second column to show.** `up` rents nothing, so every machine prepared now simply exists; only a saved rental from before can be returned.

**The mark** is in the organization's settings and holds no secret. What it asks of Core and Machines,
and what must move for another admin on another computer to start a return, remains to be checked.
`machine.takeDown` in `lib/src/app/commands.dart` needs the record `settings.hostUp` keeps, or says
*nothing was kept from putting it on a server*. Under *Organization*, `_takeOffCommand` in
`lib/src/ui/shell.dart` can instead use `HostAccess.takingOffRecord` from `lib/src/app/host_access.dart`
for a given machine. Returning a rental from another computer is not checked here.

The rental proposal, not verified in the code here: the mark can stand on the machine's card as provider,
zone and server id, none a secret, and never the state, which holds the machine's private key. Another admin
lacks the state, its passphrase and a provider key. The proposal is that they return it with their own
provider key, found by the server id and the project tag, with no state moved. That leaves the renter's
state stale, which the plan must learn to read. The operator decides.

## What the third operation meets today

Read from the code and from `doc/`, not run.

**A card has to exist before `up`.** *Prepare a machine…* reads `machineFile`, which refuses unless the
organization names that host with this person among its admins, and pins the keys of `hosts[].admins`:
that pin is whom a new server believes. `porelo-host up` refuses without that file. So the card comes
first, with no address, and `org host change` files the address, port and host key once `up` reports them. Whatever rents a server needs the
same order, as the pin has to be written before the server exists.

**Renting is refused today.** `up` takes only `--given`, and with `--scaleway-project` it answers `Verified SSH-only preparation requires the served Core
and host setup contracts.` So nothing in this interface rents now, as `_stopped` in `host_runs.dart` says. It returns with [F166](README.md#f166), planned for 0.9. *Down* on `--given` gives nothing back: *nothing is rented or given back*, and releasing the
server at the provider is the person's own step, which the list cannot see.

**What enters a server set up by hand today:**

| How it was set up | What enters the organization |
|---|---|
| *Prepare a machine…* on a server that exists | its address and key on a card that must already be there; an Organization Admin adds that card with `org host add HOST --admin LOGIN` |
| `porelo-host up` in a terminal | nothing: `--machine-file` is read and no card is written, so its admin files it by hand on the page |
| Added as a machine over ssh or WSL | nothing, as decided: it is private and stays in this computer's list |

**The card remains after taking Porelo off.** `HostRuns.confirmDown` in `lib/src/app/host_runs.dart`
clears recovery; `_giveBack` in `lib/src/ui/host_dialog.dart` forgets the machine but does not remove its
organization card. `cardLeftBehind` in `lib/src/app/host_access.dart` says a Machine Admin enters its
new address or an organization owner removes the machine; `doc/design.md` says the same. This does
not meet the promised card removal. `OrganizationView.mayRemove` in `lib/src/app/organization_source.dart`
allows an Organization Admin, and a Machine Admin when `organization_admins` is present; the message
does not describe that rule.

**The server-side teardown is not checked here:** nothing on it keeps the pin alive, as `down` stops the
follow's timer and removes `/etc/porelo-host/organization`.
What stays is its card in the organization and the public half of its read key on the central repository, which `down` does not remove and which opens nothing, its
private half being gone.

**What this asks:**

- The give-back's last step removes the card, only once the provider has confirmed it or, on a given server, once `down` has finished. A kept server keeps its card. `cardLeftBehind` and that sentence in `doc/design.md` go.
- *Prepare a machine…* enters the card itself where the person may, rather than refusing a name the
  organization does not hold. `HostAccess.unavailable` in `lib/src/app/host_access.dart` refuses that
  name and directs the person to an Organization Admin; `HostDialog._prepare` in
  `lib/src/ui/host_dialog.dart` does not add its card, so the promised automatic entry is not built.
  The first admin named by that step is the person adding it.
- The roles above govern `org host remove`. The interface offers it through `view.mayRemove(host)`
  in `lib/src/ui/organization_page.dart`; Core's enforcement and the pin's refusal on a server that is
  gone are not checked here.

## Decided by the operator on the last two

- **A project still on the machine when it goes.** The take-down dialog names it and warns, and taking down stays possible. Its words say that only what has reached the central forge is safe, as work only on the machine's own forge goes with it. It does not imply it can say whether anything would be lost.
- **A Machine Admin with no record on this computer.** The row under *Organization* offers it and says what is missing.

**What exactly is missing there.** `porelo-host down` on a machine that simply exists asks only its name, its address and SSH host key and the person's key, as read from `packages/porelo_host`, not run on a second computer. The organization's card holds the first three and the person's card the last, so usually nothing is missing and the dialog goes by the card. What remains:

- The card names no address or SSH host key: it was never set up, and the row leads to *Remove the machine…*.
- The card names another ssh port than 22: `HostAccess.whatTakingOffLacks` in
  `lib/src/app/host_access.dart` refuses taking Porelo off from another computer.
- The person's own card must be proven: `HostAccess.whatTakingOffLacks` in
  `lib/src/app/host_access.dart` refuses without an identity.
- The machine does not take the person's key as root, which only the machine says.
- A rental: its recovery data stand only on the computer that rented it, so another computer cannot return it. None exists until 0.9.

## To be checked

- Whether someone can reach an organization's machine by adding it as a private one, past the official way.
  Server behavior is not checked here: without an account the login is refused, and with one it gives no more
  than *Connect*. A removed member's
  key still logs in until the next follow, at most five minutes while the follow succeeds, and a follow that cannot fetch makes that wait as long as it lasts.
- Whether the interface should say so when an address added under *Machines* is an organization's machine. By reading, not built: `checkMachine` reads the key from `known_hosts` or `ssh-keyscan`, and a card holds `hostKey`, so it can compare them for an ssh entry where
  the organization is read and the card has a key. It cannot for WSL or a socket someone else forwarded, and a key nobody checks against a card proves nothing about rights, so it could only be a word, never a guard.

- Whether a rented server outside any organization still exists once preparing needs one: if it does, it is one more row in this list.
