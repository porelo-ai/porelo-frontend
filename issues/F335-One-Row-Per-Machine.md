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

**A task with no project is a task of the default project,** on a server as on any machine. By reading, not run: the interface's way there
is not yet known to reach the start, as `porelo task start --host` refuses a blank `--project`; Agent Core is asked whether
`--project default` reaches it, and what stops it if not. Until that is answered, nothing here promises such a start on a server.

## What else it changes

Nothing of this is built, and nothing built stops for it.

- **[F336](README.md#f336):** the page's words, and its block for everyone gains *Start work* in the default project, for anyone with an account there.
  *Managing this host* becomes *Managing this machine*.
- **[F337](README.md#f337):** the rule stands, and *Machines* stays the entry a click returns to. If the pages become one, its table's rows for
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
  watched machines already, so nothing joins there. What changes: a machine of this person's that is not connected is not offered, though it now stands under *Machines* with the
  rest. The project picker that follows offers the default project on a server as well, once Core's answer above allows it.
- **The words:** about 440 lines in `lib` hold "host" in a string, ids and ssh's own terms among them, so each is read rather than replaced.
  Most are in `organization_host_pages.dart`, `tunnel.dart`, `organization_page.dart`, `machines.dart`, `commands.dart` and `host_dialog.dart`. Among
  them: *host admin*, *Remove the host…*, *Open the host's page*, *Projects on this host*, *Saved hosts not watched*, *Complete setup on the host*.
- **Words from elsewhere:** a refused write shows the store's words as they come, and `org status`'s and `porelo-host`'s lines reach the screen
  too, and those say "host". Those lines belong to Core and Machines; until they change them, "host" still reaches the screen by that way.
- **`doc/decisions.md`:** a section of its own for this decision. *Machines say where work runs* becomes true of every server, and *Daily work in
  front, setting up apart* keeps its rail. `doc/index.md`'s setup words and `doc/design.md`'s *Projects on prepared hosts* follow; a role named in
  them follows the question below.
- **Walks and tests:** those that find rows by `my-host`, `machines-row` or the *Hosts* section, and the feature steps on the machines page.

## Open questions

- Is one page per server meant as well? Recommended: yes, as two pages are a difference a person sees. Its top is [F336](README.md#f336)'s block, then
  work, daemon and vault, then *Managing this machine* for its admin. It is the largest part; the row could lead to today's two pages for a while.
- *Host admin* is a role in Core and in the organization. In the interface: *machine admin*? Recommended: yes, and "admin" where the page already
  says which machine.
- *Prepare a server…* and *Give the server back* name the rented thing, and the operator calls them servers too. Do they say *machine*?
  Recommended: *Prepare a machine…*, *Give the machine back*, for one word.
- *Host key* is ssh's own term, and what ssh prints. Keep it in *Change address and host key…* and in its dialog? Recommended: keep it where a
  person compares it with what ssh shows, as *SSH host key*, and *Change address and key…* on the button.
- A machine of this person's that is not connected, in *New work*: offered with a word that it connects first, or not offered? Recommended: offered.
- What a person reads for the default project, today *Without a project* and no *Default* under *Projects*: does it stay? Recommended: yes, as
  `doc/decisions.md` has it, as nothing in this decision is about that word.
- *Forget* and *Disconnect* both make this computer forget the machine, *Disconnect* also removing what it published for the connection, and
  *Forget* warning first on a server. Keep one? Recommended: *Disconnect* for a machine of the organization, with that warning where a server
  stands rented.

## To be checked

- Whether a rented server outside any organization still exists once preparing needs one: if it does, it is one more row in this list.
