# F335 — One Row Per Machine

**Status:** Idea.

**What must be true.** A server a person connects to stands once in the interface, under a name that person expects, with
everything that can be done with it reached from that one row.

In a walk one host stood twice on the page: under *Hosts* (`you administer it · connected`) and under *Machines*
(`<host> · Connected`, with a ⋮ that holds *Give the server back*). The operator found this illogical, and had already opened
the wrong row's menu. The operator added: "Under *Machines* I do not expect hosts", so the question is not only the rows but
whether the two share a rail entry and a page at all.

## Why there are two

Read from the code, not run. The two sections read two lists, and nothing joins them. *Hosts* is what the organization says:
`OrganizationHostsSection`, from `porelo org`. *Machines* is what this computer watches: `Machines.all`, its own saved list.
*Connect* on a host adds a machine to that list, and *Give the server back* needs what this computer kept from setting it
up, so one server gets a row in each. While a host is being prepared its row under *Machines* is a third kind, the
preparation's, and it stands in *Hosts* as well.

## What each row offers now

| | Row under *Hosts* | Row under *Machines* |
|---|---|---|
| Says | administers it, the person's projects, connected or why not | where it is, connection, the last problem |
| In the row | *Connect*, while not connected | ⋮ |
| In its ⋮ | no ⋮ | *Open the machine*, the setup's protocol, *Give the server back*, *Run its setup again*, *Forget* |
| Opens | the host's page: address and key, its projects, its admins, a backup key, *Give it the token…*, *Disconnect* | the machine's page, where its work, daemon and vault are |

## What a machine and a host are to a person

- **A machine** answers *where can my work run?* It is a computer this person's window watches: this computer, one reached over
  ssh or WSL, one rented for themselves. The list is private to this computer, and nobody else is concerned.
- **A host** answers *which server does my organization share, and who is on it?* It belongs to the organization, has admins, and
  carries projects with all their members. It stands there whether or not this computer is connected.
- **They overlap once connected:** a connected host is also a place work runs, and that overlap is why it has two rows.

`doc/decisions.md` says *Machines say where work runs*. That sentence is from 2026-10-05, before the pages of the organization's hosts, and it does make a connected host
a machine. Core's words point the same way: for the playbook, a machine is a host whose persons start tasks. So keeping them
together has a reason, though it is not what the operator expects to see.

## The options

1. **One rail entry, one row per server, as now named.** Rows are joined under *Machines* by
   `machine.hostCard?.name == host.name`. The smallest change, and the rail stays as decided. It does not answer the operator's
   expectation: hosts stand under *Machines*.
2. **One rail entry under a new name,** such as *Computers*, with the same joined rows. It removes the mismatch in the word, but
   *machine* is in the pickers, the words and the walks throughout, and a shared server still sits beside this person's laptop.
3. **Two rail entries.** *Hosts* under *Set up*, shown where this computer reads an organization, listing every host of the person's
   with its connection and opening the host's page. *Machines* lists only what is not a host. *Prepare a server…*, *Give the server
   back* and the setup's protocol move to *Hosts*, and each server stands once because a connected host leaves *Machines*. A
   picker that asks where work runs still offers a connected host by its name.
4. **Hosts only on the *Organization* page,** whose section is there already, and *Machines* as today. The least to build, but a
   connected host still has a second row, now one page away, and a developer goes to *Organization* to connect.

**Recommended: option 3.** The two answer different questions for different people, the operator's word says so, and it carries on
the separation of a project from its machines, which was decided for the same reason. It is the largest: the rail and its counts,
the routing to the host's and the machine's pages, and the walks and tests that go through *Machines*.

## What stands under any option

- What stays alone keeps its row: a host with no connection here, with *Connect*; this computer, and a machine reached over ssh
  or WSL, which no organization holds.
- A preparation takes the place of that one row, so there are never two rows there either.
- The row's menu follows [F329](README.md#f329)'s decision.

## Open questions

- Which of the options? Recommended: 3, above.
- Which page does a connected host's row open? Recommended: the host's page, with *Open the machine* in the row's ⋮, as the host's
  page is what only this row reaches, and a project's work has its own way in.
- *Forget* and *Disconnect* both make this computer forget the machine, *Disconnect* also removing what it published for the
  connection, and *Forget* warning first on a host. Keep one? Recommended: *Disconnect* for a host of the organization, with
  that warning where a server stands rented.

## What it changes here

Under options 2 and 3: the host's page and the list of hosts, which stand under *Machines*; the sentence and the rail in `doc/decisions.md`, the setup words in `doc/index.md`; and the words of
[F331](README.md#f331), [F332](README.md#f332), [F333](README.md#f333) and [F334](README.md#f334).

## To be checked

- Whether the two pages should become one as well. This issue leaves them two.
- What the walks and the feature tests that find rows by `my-host` or `machines-row` need.
- Whether a rented server outside any organization still exists once a host needs one: under option 3 it would stay under
  *Machines*.
