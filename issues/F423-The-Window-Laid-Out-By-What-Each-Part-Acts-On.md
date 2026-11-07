# F423 — The Window Laid Out By What Each Part Acts On

**Status:** Idea.

**What must be true.** The side bar and the pages follow what each part acts on, so a person finds every function where
its subject is: their own work across machines, one machine, the forges, their projects, their organizations, and their
own cards and keys. Nothing Porelo offers for a machine is hidden or reachable only through another page.

## The shape

### The side bar

| Entry | What it is | Today |
|---|---|---|
| *Work* | every task of this person on every machine | stays |
| *Needs you* | what waits on this person, from every machine | stays |
| *My machines* | the machines this person works with; one machine's page holds everything Porelo offers on it (below) | the list stays; the page grows |
| *My forges* | where the repositories are, and the tokens and host keys reaching them | stays |
| *My projects* | the projects this person works in | stays |
| *Organizations* | every organization this person is in, as a list like the other pages; one organization's page is today's *Porelo organization*; the window works in the one chosen, and changing it is one action | today the entry is *Organization*, the one this computer reads; its page's menu changes it with *Choose another Porelo organization…*, by typing the other one's repository address, with no list to choose from |
| *Cards & keys* | this person's keys and their card in each organization: show, propose, create, renew, rotate, revoke, backup key | today only the dialog *My key and card…* in the title bar's options |

Today the side bar holds *Work* and *Needs you* on top, and below them, under the heading *Set up*, *My machines*,
*My forges*, *My projects* and *Organization*.

### One machine's page

Every part of what Porelo offers on a machine has its section there, each with its state and its actions, folded like the
other lists:

| Section | What it shows and does | Today |
|---|---|---|
| Tasks | the machine's tasks, as *Work* filtered to it | |
| Projects | the projects it carries, with their repositories, put on and taken off | *Put it on a machine…* and taking it off, from the project |
| Vault | its state (made, locked, open), the names of what it stores with their kind (never a value), store, replace and remove an entry, unlock and lock | *Show the vault* in the machine's menu lists the entries by name, kind and length, the devices that open it with revoking one, and granting an entry's authorization; making it, opening it by passphrase or device, shutting it and enrolling a device are menu entries. A value is stored only as a forge token, in a terminal; nothing replaces or removes an entry |
| Credentials | what the machine connects out with and where each comes from, trusted host keys | *Connections* and *Destinations* in the machine's menu |
| Agents and providers | the installed agents, the declared providers and what the vault holds for each | *Show the agents installed here* and *Show what this machine can authenticate against* in the machine's menu |
| Ecosystems | the installed ecosystem adapters | none |
| Reach | what a task may reach and what it was refused | *What this project may reach*, per project, in the project's menu; nothing per machine |
| Events | the security-relevant events, and whether none was changed | none |
| Health | what `doctor` reports, and what can be cleaned up (`prune`, `tighten`) | *Check whether this machine can run anything* in the machine's menu; nothing cleans up |
| Managing this machine | setting it up, starting and stopping Porelo there, taking it down | start, stop, adding a user, clearing it, taking it down and forgetting it, in the machine's menu |

A host and a person's own machine share this page; what a host does not offer says why in words.

### Where a function lives

A function stands under its subject, and only there: putting a project on a machine on the machine's page and the
project's page alike is one action reached from two places, not two. A function reachable from another page leads to its
subject's page.

## Acceptance

- Each entry and section above is reached from the side bar in at most two clicks, and the window's own guide names
  each.
- The vault section lists the stored entries by name and kind and shows no value, also not in a tooltip, a log line or
  a copy.
- Changing the organization changes what *My projects*, *Needs you* and the organization's page show, and no write goes
  to the organization not chosen.
- *Cards & keys* does all that *My key and card…* does today; the dialog is gone.

## Open questions

- Whether *Cards & keys* stands under *Set up* or beside *Work* and *Needs you*.
- Which of the machine page's sections go first.

## To be checked

- Which calls the sections without a function need (an entry's replacing and removing, ecosystems, reach per machine,
  events, `prune` and `tighten`), read against the IDL a running daemon serves; what it lacks goes into
  `doc/Contract-Gaps.md` and is raised with Core, which would make this issue wait on another repository.
- Where the list of every organization a person is in comes from: the window reads only the one this computer reads
  (`porelo setup --organization`, changed with `--replace`), and nothing it calls today names the others.
- How it splits into issues of L or smaller. A first reading: the side bar and *Cards & keys* in place of the dialog;
  the machine page's sections from the functions the window has today; *Organizations* as a list once its source is
  known; one issue per missing function, once its call is known.
