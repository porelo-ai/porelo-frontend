# F335 — One Row Per Machine

**Status:** Idea.

**What must be true.** To a person there is one set of servers, called *Machines*, on which they may run tasks, in a project of theirs or in the
default project, where they have an account. Each stands once, under one rail entry, in one row, with everything that can be done
with it reached from that row. "Host" is a technical term and appears nowhere in the interface's words.

In a walk one server stood twice on the page: under *Hosts* (`you administer it · connected`) and under *Machines*
(`<host> · Connected`, with a ⋮ that holds *Give the server back*). The operator found this illogical and had already opened the
wrong row's menu.

## The operator's decision

To a person there is no difference between a host and a machine. This replaces the operator's earlier remark that no hosts belong
under *Machines*, and the options this issue listed, two rail entries among them.

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

- **One list under *Machines*:** this computer, a machine reached over ssh or WSL, a server rented for oneself, and every server of the
  organization this person has a right on, connected or not. The *Hosts* section goes. Rows are joined by
  `machine.hostCard?.name == host.name`, as `organization_connections.dart` already does.
- **The row says** what both say now: where it is, connected or why not, *you administer it* where so, and the person's projects on it.
- **In the row:** *Connect* while not connected. Everything else is in its one ⋮, following [F329](README.md#f329)'s decision.
- **A preparation** takes the place of that one row, so there are never two rows there either.
- ***Organization*** keeps its list of all the organization's servers, under the heading *Machines*, for what an owner does with them.
- **What stays technical:** `porelo-host` and its commands, `porelo org host …`, field names in answers, paths such as
  `/etc/porelo-host/`, ids in the code and the commands' keys. None of these is renamed by this issue.

## A person with no right on a server

**Recommended:** under *Machines* it has no row, as a row would offer nothing they can do; this is what `myHosts` does today. On
*Organization* it keeps its row, read only, as every member of the organization reads it today.

One case needs a row: a server this computer is connected to, where the right has since gone. Its row stays, says in words that this
person no longer has access there and whose it is to change, and offers *Disconnect*. It does not keep retrying.

**The right is an account,** and no separate right exists. By Agent Machines' reading, not run: a person has an account on a server by
administering it or by belonging to a project it carries, and the server's task check takes a task of the default project from anyone
admitted. That is who `myHosts` names, so it stays the rule for who has a row.

**A task with no project is a task of the default project,** on a server as on any machine. By Agent Core's reading, not run:
`porelo task start --host <server> --project default` reaches the start, given an ssh login to the person's account there. A blank
`--project` is refused, so the interface names the default project in that call.

## What else it changes

Nothing of this is built, and nothing built stops for it.

- **[F336](README.md#f336):** the page's words, and its block for everyone gains *Start work* in the default project, for anyone with an account there.
  *Managing this host* becomes *Managing this machine*.
- **[F337](README.md#f337):** the rule stands, and *Machines* stays the entry a click returns to. As the pages become one, its table's rows for
  a host's page and a machine's page become one row, and `_organizationHost` goes. Nothing asks for another rail entry any more, so
  the rail stays as `doc/decisions.md` has it.
- **[F338](README.md#f338):** `Connect to <machine>`; `not on a machine yet · its admin puts it on one`; *Open it on …* goes as proposed there.
  *Projects on your machines, outside the organization* stays a question about projects and is not touched by this.
- **[F341](README.md#f341):** the lines say `<machine>` and *it*; what the token is for does not change.
- **[F342](README.md#f342):** *Put it on a machine…*, *Take it off the machine…*, and the list it leaves read only stands on the machine's page. Only
  servers of the organization that the person administers are offered: never this computer or one rented alone.
- **[F343](README.md#f343):** the same list on the machine's page, and its title.
- **[F329](README.md#f329), [F334](README.md#f334):** one row and one ⋮, so its menu takes both rows' entries, and the steady line of the latter is that row's.
- **[F331](README.md#f331), [F332](README.md#f332), [F333](README.md#f333), [F339](README.md#f339), [F340](README.md#f340):** the words only, *Prepare the host* among them.
- **The pickers:** *New work* asks where it runs among the machines that answer, as `doc/decisions.md` says. A connected server is one of the
  watched machines already, so nothing joins there. A machine of this person's that is not connected stands under *Machines* with the rest and is not offered, as nothing can run there. The project picker that follows offers the default project on a server as well.
- **The words:** about 440 lines in `lib` hold "host" in a string, ids and ssh's own terms among them, so each is read rather than replaced.
  Most are in `organization_host_pages.dart`, `tunnel.dart`, `organization_page.dart`, `machines.dart`, `commands.dart` and `host_dialog.dart`. Among
  them: *host admin*, *Remove the host…*, *Open the host's page*, *Projects on this host*, *Saved hosts not watched*, *Complete setup on the host*.
- **Words from elsewhere:** a refused write shows the store's words as they come, and `org status`'s and `porelo-host`'s lines reach the screen
  too, and those say "host". Those lines belong to Core and Machines; until they change them, "host" still reaches the screen by that way.
- **`doc/decisions.md`:** a section of its own for this decision. *Machines say where work runs* becomes true of every server, and *Daily work in
  front, setting up apart* keeps its rail. `doc/index.md`'s setup words and `doc/design.md`'s *Projects on prepared hosts* follow; a role named in
  them follows the decision below.
- **Walks and tests:** those that find rows by `my-host`, `machines-row` or the *Hosts* section, and the feature steps on the machines page.

## Decided by the operator

- **One page per server as well,** as two pages are a difference a person sees. Its top is [F336](README.md#f336)'s block, then work, daemon and
  vault, then *Managing this machine* for its admin. It is the largest part; the row could lead to today's two pages for a while.
- **The role reads *machine admin*** in the interface, and "admin" where the page already says which machine. In Core and in the organization
  it stays what it is.
- ***Prepare a machine…* and *Give the machine back*,** for one word.
- ***SSH host key* stays** where a person compares it with what ssh shows, and the button reads *Change address and key…*.
- ***New work* offers no machine that is not connected,** since nothing can run there.
- ***Without a project* stays** what a person reads for the default project, and *Projects* lists no *Default*, as `doc/decisions.md` has it.

- **Two operations, for every machine.** *Disconnect* ends this computer's connection; the machine stays in the list and *Connect* brings it
  back. *Forget* takes the entry out of the list; if the person is an admin of that server, it warns first that the server keeps running.

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
- **The last machine.** `Forget` is refused while a machine is the only one watched. *Disconnect* needs the same reading, and the window needs words for
  no machine being connected.
- **Who gets the warning.** `_forget` in `shell.dart` warns where `machine.kind == 'host'`, in words of billing, with the way to give the server back.
  The test becomes that the person is an admin of that server, one who rented it counting as one.
- **[F336](README.md#f336):** its words for *Disconnect* come true only with this, so this comes first or with it.

## Open questions

- Where does a forgotten machine of the organization go? The operator is asked. What decides it: the list joins what the organization says, so such a
  machine comes straight back as a row with *Connect*, which makes *Forget* look like *Disconnect*. Recommended: this computer remembers
  the forgetting, the row stays away, and *Organization*'s row is the way back. The other way is to let it return, and say so in *Forget*'s question.

## To be checked

- Whether a rented server outside any organization still exists once preparing needs one: if it does, it is one more row in this list.
