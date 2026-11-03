# F335 — One Row Per Machine

**Status:** Idea.

**What must be true.** A server a person connects to stands once on *Machines*, with everything that can be done with it
reached from that one row.

In a walk one host stood twice on the page: under *Hosts* (`you administer it · connected`) and under *Machines*
(`<host> · Connected`, with a ⋮ that holds *Give the server back*). The operator found this illogical, and had already opened
the wrong row's menu.

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

## The shape

- Join by `machine.hostCard?.name == host.name`, as the shell's project menu already does: one row, under *Machines*, with both
  rows' words and the union of the actions.
- What stays alone keeps its row: a host of the organization with no connection here, with *Connect*; this computer, and a
  machine reached over ssh or WSL, which no organization holds.
- A preparation takes the place of that one row, so there are never two rows there either.
- The row's menu follows [F329](README.md#f329)'s decision.

## Open questions

- Which page does the row open? Recommended: the host's page for a host, with *Open the machine* in the row's ⋮, as the host's page
  is what only this row reaches, and a project's work has its own way in.
- *Forget* and *Disconnect* both make this computer forget the machine, *Disconnect* also removing what it published for the
  connection, and *Forget* warning first on a host. Keep one? Recommended: *Disconnect* for a host of the organization, with
  that warning where a server stands rented.

## To be checked

- Whether the two pages should become one as well. This issue leaves them two.
- What the walks and the feature tests that find rows by `my-host` or `machines-row` need.
