# F335 — One Row Per Machine

**Status:** Idea.

**What must be true.** *Organization* lists the organization's available machines. *Machines* is a person's own view of what they use: always the local
machine, plus what they added. A server appears under *Machines* only after *Connect*, which is offered in *Organization*. It stands there once, with everything that
can be done with it reached from that row. "Host" is a technical term and appears nowhere in the interface's words.

In a walk one server stood twice on the page: under *Hosts* (`you administer it · connected`) and under *Machines*
(`<host> · Connected`, with a ⋮ that holds *Give the server back*). The operator found this illogical and had already opened
the wrong row's menu.

## The operator's decision

To a person there is no difference between a host and a machine: there is one set of servers, called *Machines*, on which a person may run tasks where they have an
account. Which of them are theirs to use is their own list, and it is not joined from the organization. This replaces the operator's earlier remark that no hosts
belong under *Machines*, the options this issue listed, two rail entries among them, and a first reading of this decision in which everyone with a right saw a server
under *Machines*.

## Why there are two rows now

Read from the code, not run. The two sections read two lists, and nothing joins them. *Hosts* is what the organization says:
`OrganizationHostsSection`, from `porelo org`, narrowed by `myHosts` to the servers a person administers or has a project on.
*Machines* is what this computer watches: `Machines.all`, its own saved list. *Connect* adds a machine to that list, and *Give the
server back* needs what this computer kept from setting it up, so one server gets a row in each. While a server is being prepared its
row under *Machines* is a third kind, the preparation's, and it stands in *Hosts* as well.

| | Row under *Hosts* | Row under *Machines* |
|---|---|---|
| Says | administers it, the person's projects, connected or why not | where it is, connection, the last problem |
| In the row | *Connect*, while not connected | ⋮ |
| In its ⋮ | no ⋮ | *Open the machine*, the setup's protocol, *Give the server back*, *Run its setup again*, *Forget* |
| Opens | the host's page: address and key, its projects, its admins, a backup key, *Give it the token…*, *Disconnect* | the machine's page, where its work, daemon and vault are |

## The shape

- ***Machines*:** `Machines.all`, as today: the local machine, each private one reached over ssh or WSL, and each server of the organization after *Connect*. The *Hosts* section goes, and nothing joins it
  to the organization's list, so *Machines* holds only what this person chose.
- **In its row:** *Connect* while disconnected. Everything else is in its one ⋮, following [F329](README.md#f329)'s decision.
- ***Organization*:** its list of all the organization's servers, under the heading *Machines*, with what an owner and an admin do with them. A person with an account there
  has *Connect* in the row; once connected the row says so.
- **A preparation** stands in the one row under *Machines*, in place of what it becomes.
- **What stays technical:** `porelo-host` and its commands, `porelo org host …`, field names in answers, paths such as
  `/etc/porelo-host/`, ids in the code and the commands' keys. None of these is renamed by this issue.

## The three operations

| | *Connect* | *Disconnect* | *Forget* | Taking it down |
|---|---|---|---|---|
| Where | *Organization*; under *Machines* after *Disconnect* | the row under *Machines* | the row under *Machines* | see below |
| Under *Machines* | appears | stays, with *Connect* | gone | gone from the list of the person who did it |
| In *Organization* | says connected | stands, with *Connect* | stands, with *Connect* | gone |

The local machine stands always, and offers neither *Disconnect* nor *Forget*. Today it can be forgotten while another machine stands. Since *Forget* leaves the server in
*Organization*, no forgetting needs remembering.

## A person with no right on a server

**The right is an account,** and no separate right exists. By Agent Machines' reading, not run: a person has an account on a server by administering it or by belonging to a
project it carries, and the server's task check takes a task of the default project from anyone admitted.

The rule stays and moves. `myHosts` no longer decides who has a row under *Machines*, as nobody has one before their own *Connect*. It decides who is offered *Connect* in
*Organization*:

- **No right, and not connected:** the read-only row in *Organization*, as every member reads it today, with no *Connect*. It has no row under *Machines*.
- **Connected, and the right has since gone:** this person's own list keeps the row, since nothing joins it away. It says that they no longer have access there and whose it is to
  change, does not keep retrying, and offers *Disconnect* and *Forget*. So a row under *Machines* still reads the organization for its words, though not for its existence.
- **The server has left the organization,** taken down by someone else: the same row says so, and offers *Forget*. `_movedPast` in `organization_connections.dart` already sees that.

**A task with no project is a task of the default project,** on a server as on any machine. By Agent Core's reading, not run:
`porelo task start --host <server> --project default` reaches the start, given an ssh login to the person's account there. A blank
`--project` is refused, so the interface names the default project in that call.

## What else it changes

Nothing of this is built, and nothing built stops for it.

- **[F336](README.md#f336), first:** its path starts in *Organization*: step 1's row with *Connect* stands there, and only from step 2 on is there a row under *Machines*. The
  page's top block keeps its three states, and *Not connected* now also means disconnected, under *Machines*. It says that *Connect* brings it back and *Forget* takes it off
  this person's list. *Start work* in the default project is for anyone with an account there. *Managing this host* becomes *Managing this machine*, and an admin
  reads it whether connected or not.
- **[F337](README.md#f337):** the rule stands, and the rail stays as `doc/decisions.md` has it. As the pages become one, its table's rows for a host's page and a machine's page
  become one row, and `_organizationHost` goes. A server opened from *Organization* moves the rail to *Machines* today, which needs reading again: it may not be in this
  person's list.
- **[F338](README.md#f338):** *Connect to <machine>* on a project's row meets the rule that *Connect* is offered in *Organization*; see the open questions. *Work on it* and the other words stand with "machine" for
  "host".
- **[F341](README.md#f341):** the lines say `<machine>` and *it*. The token takes the admin's connection, so the page leads to *Connect* first.
- **[F342](README.md#f342):** decided there: from the organization's projects, a machine's admin puts a project on it. So *Organization*'s project row holds *Put it on a machine…*, chosen among machines the person administers, read from the organization, connected or not.
- **[F343](README.md#f343):** the same list on the machine's page, connected, and its title.
- **[F329](README.md#f329):** the two lists keep separate rows with separate menus. Under *Machines* the ⋮ holds the entries of today's machine row. *Organization*'s row holds
  *Connect* and what an owner and an admin do.
- **[F334](README.md#f334):** its steady line is the row's under *Machines*; a disconnected machine no longer tries.
- **[F331](README.md#f331), [F332](README.md#f332), [F333](README.md#f333), [F339](README.md#f339), [F340](README.md#f340):** the words only, *Prepare the host* among them.
- **The pickers:** *New work* asks where it runs among the machines that answer, as `doc/decisions.md` says, so a connected server is there already and a disconnected one is not. The
  project picker that follows offers the default project on a server as well.
- **The code of the rows:** `OrganizationHostsSection` and its `_HostRow` with *Connect* leave `MachinesPage` for `organization_page.dart`, whose *Open the host's page* is an admin's alone
  today. No join by `machine.hostCard?.name == host.name` is built for the list.
- **The words:** about 440 lines in `lib` hold "host" in a string, ids and ssh's own terms among them, so each is read rather than replaced.
  Most are in `organization_host_pages.dart`, `tunnel.dart`, `organization_page.dart`, `machines.dart`, `commands.dart` and `host_dialog.dart`. Among
  them: *host admin*, *Remove the host…*, *Open the host's page*, *Projects on this host*, *Saved hosts not watched*, *Complete setup on the host*.
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
- **The owner acts rarely.** Admins do the operational work, renting or adding an existing machine among it. So who enters a new machine is not settled as the owner, and the role is open, as no
  machine's admin exists before the machine.
- **A machine added over ssh or WSL is private.** It stands only under *Machines*, marked clearly as a private machine, with *Connect* and *Disconnect*. *Forget* deletes the entry, so it is added anew there.
- ***Prepare a machine…* stands in *Organization*.**
- **A third operation: taking a server down,** for a rented one giving it back, also removes it from the organization's list. Renting a server or
  setting one up by hand must enter it in the organization.

## What the two operations ask of today's code

Read from the code, not run.

- **`disconnect` in `organization_connections.dart`** calls `machines.forget`, so today's *Disconnect* is a forget as well. It must keep the entry
  and only end the connection.
- **A saved mark.** A disconnected machine stays disconnected after a restart, so its entry in `frontend.json` says so. The entry holds no such thing
  now, and `connected` in `organization_connections.dart` takes having a saved card to mean connected. `doc/design.md` makes that file a contract with
  `porelo-intellij`, changed only after agreement in both, so the plugin must learn not to connect to such an entry.
- **Nothing raises it again by itself.** At the start every saved machine is watched and connected, and a machine that stops answering is raised
  again by `raiseAgainIfNeeded`. Both skip a disconnected machine, which is a decision, unlike a forward that dropped. Its row says *not connected*,
  not *not answering*, and it is left out of what asks every machine: the notices, the refresh for all, and *New work*.
- **What *Connect* does on it.** A machine of the organization is written anew from its card, as today. Every other kind has only its saved entry
  to raise from.
- **Every kind has to mean something.** `dropAndUnpublish` applies to a forward this interface raised. It is to be read per kind what *Disconnect* does on
  this computer, on WSL, and on a socket somebody else forwarded, which this interface can only stop watching.
- **The local machine.** `canForget` asks only that another machine stands, so the local one can be forgotten today; it must not be. On Windows the local machine is a WSL
  distribution, which is to be read for what *always* means when none is set up.
- **Who gets the warning.** `_forget` in `shell.dart` warns where `machine.kind == 'host'`, in words of billing, with the way to give the server back.
  The test becomes that the person is an admin of that server, one who rented it counting as one. It also says that the server stays in *Organization*.
- **[F336](README.md#f336):** its words for *Disconnect* come true only with this, so this comes first or with it.

## Taking a machine down: a machine that exists, and a rental

The operator: *Give the machine back* is a poor name, as it concerns only a rented machine. The organization's settings must tell a machine that simply exists from an
active rental with a later return. A return can be started in two places: always under *Organization*, and under *Machines* by an admin who may do it.

**The words,** proposed:

| | A machine that simply exists | An active rental |
|---|---|---|
| The action | *Take Porelo off this machine…* | *Return this rental…* |
| Its question says | The accounts named and all they hold here are deleted, and it leaves the organization's list. The machine itself stays yours. | The same, and the provider then removes the machine, which ends its billing once the provider confirms. |
| Button, with holders | *Delete these accounts and take Porelo off* | *Delete these accounts and return it* |
| Button, without | *Take Porelo off* | *Return it* |
| What stays to do | nothing of Porelo's; the person ends any contract at their provider | nothing, once confirmed |
| When a step of it fails | it stays, says what would be lost, and offers to go on anyway | the same, and it stays billed |

*Take Porelo off* is what `down` on `--given` does by its own words, *nothing is rented or given back*. The label is wrong today the other way round: `commands.dart` says *Give the server
back* where a host name is saved, which is the given server, and the dialog's words and buttons say give back on it too.

**Until 0.9 there is no second column to show.** `up` rents nothing, so every machine prepared now simply exists; only a saved rental from before can be returned.

**The mark** is in the organization's settings and holds no secret. What it asks of Core and Machines, and what must move for another admin on another computer to start a return, they are asked. Today
`_giveBack` and `machine.takeDown` need the record `settings.hostUp` keeps on the computer that set it up, or say *nothing was kept from putting it on a server*. So until that is settled a start from
*Organization* can only say this on any other computer.

Agent Machines' reading of the rental's plan, not built: the mark can stand on the machine's card as provider, zone and server id, none a secret, and never the state, which holds the machine's private key. Another admin lacks the state, its passphrase and a provider key. Machines proposes that they return it with their own provider key, found by the server id and the project tag, with no state moved. That leaves the renter's state stale, which the plan must learn to read. The operator decides.

## What the third operation meets today

Read from the code and from `doc/`, not run.

**A card has to exist before `up`.** *Prepare a server…* reads `machineFile`, which refuses unless the organization names that host with this person
among its admins, and pins the keys of `hosts[].admins`: that pin is whom a new server believes. `porelo-host up` refuses without that file. So the card comes
first, with no address, and `org host change` files the address, port and host key once `up` reports them. Whatever rents a server needs the
same order, as the pin has to be written before the server exists.

**Renting is refused today.** `up` takes only `--given`, and with `--scaleway-project` it answers `Verified SSH-only preparation requires the served Core
and host setup contracts.` So nothing in this interface rents now, as `_stopped` in `host_runs.dart` says. It returns with [F166](README.md#f166), planned for 0.9. *Down* on `--given` gives nothing back: *nothing is rented or given back*, and releasing the
server at the provider is the person's own step, which the list cannot see.

**What enters a server set up by hand today:**

| How it was set up | What enters the organization |
|---|---|
| *Prepare a server…* on a server that exists | its address and key on a card that must already be there; an owner's `org host add HOST --admin LOGIN` made that card |
| `porelo-host up` in a terminal | nothing: `--machine-file` is read and no card is written, so its admin files it by hand on the page |
| Added as a machine over ssh or WSL | nothing, as decided: it is private and stays in this computer's list |

**What taking it down does to the card today:** nothing. `cardLeftBehind` in `host_access.dart` says *a host admin enters its new address, or an organization owner removes
the host*, and `doc/design.md` says the same. `org host remove` is an owner's, and a host carrying on from its pin refuses it until its admin acts.

**What outlasts a server,** by Agent Machines' reading: nothing on it keeps the pin alive, as `down` stops the follow's timer and removes `/etc/porelo-host/organization`.
What stays is its card in the organization and the public half of its read key on the central repository, which `down` does not remove and which opens nothing, its
private half being gone.

**What this asks:**

- The give-back's last step removes the card, only once the provider has confirmed it or, on a given server, once `down` has finished. A kept server keeps its card. `cardLeftBehind` and that sentence in `doc/design.md` go.
- *Prepare a machine…* enters the card itself where the person may, rather than refusing a name the organization does not hold. Today it can only refuse, and it needs the role still open. The first admin named by that step is the person adding it.
- `org host remove` is an owner's in Core today, and a machine's admin is now to have it. What that takes, and what the pin's refusal asks of a server that is gone, is asked of Core.

## Open questions

- Who starts a return under *Organization*, *always* being said of the place? Recommended: an admin of that machine; an owner only where no admin is left, as the owner acts rarely. Under *Machines*, its admin alone, as decided.
- Does a machine that simply exists have the same two places as a rental? Recommended: yes, for one way to find it.
- Who may enter a new machine? Not the owner by default, as decided, and no machine's admin exists before it. An organization-wide role is one way; Core is asked what it costs.
- A project still on the server when it goes: `org host remove` is to be read for whether it refuses, or leaves the project on no machine. [F319](README.md#f319) empties the accounts and says nothing of the projects.
- A project's row says *Connect to <machine>* in [F338](README.md#f338). Does it connect, or lead to the row in *Organization*? Recommended: lead to that row, so that *Connect* stays in one place.
- An admin who has forgotten a server, or never connected: the machine's page, opened from *Organization*, has what they manage. Taking it down needs what this computer kept and a way to the
  server. Recommended: *Organization*'s row offers it to an admin in any case, as a return is, and says what is missing where it cannot.

## To be checked

- Whether someone can reach an organization's machine by adding it as a private one, past the official way: Core and Machines are asked what stops the login and whether it gives more than *Connect*.
- Whether the interface should say so when an address added under *Machines* is an organization's machine. By reading, not built: `checkMachine` reads the key from `known_hosts` or `ssh-keyscan`, and a card holds `hostKey`, so it can compare them for an ssh entry where
  the organization is read and the card has a key. It cannot for WSL or a socket someone else forwarded, and a key nobody checks against a card proves nothing about rights, so it could only be a word, never a guard.

- Whether a rented server outside any organization still exists once preparing needs one: if it does, it is one more row in this list.
