# F423 — The Window Laid Out By What Each Part Acts On

```json
{
  "$schema": "issue-1.json",
  "id": "F423",
  "title": "The Window Laid Out By What Each Part Acts On",
  "state": "Idea",
  "size": "-",
  "priority": "Medium",
  "rank": 46,
  "blockedBy": [],
  "covers": "The side bar as a folding tree by what each part acts on: each machine with its sections, each organization with its sections, *My cards & keys* in place of its dialog; a page with entries under it shows facts and actions, only a leaf a list."
}
```

**What must be true.** The side bar and the pages follow what each part acts on, so a person finds every function where
its subject is: their own work across machines, one machine, the forges, their projects, their organizations, and their
own cards and keys. Nothing Porelo offers for a machine is hidden or reachable only through another page.

## The shape

### The side bar

The side bar is a tree whose entries with entries under them fold open and shut, in this order:

| Entry | Under it | What it is | Today |
|---|---|---|---|
| *Work* | | every task of this person on every machine | stays |
| *Needs you* | | what waits on this person, from every machine | stays |
| heading *Set up* | | | stays |
| *My machines* | each machine, and under one machine its sections (below) | the machines this person works with | a list; one machine's functions sit in its menu |
| *My forges* | | where the repositories are, and the tokens and host keys reaching them | stays |
| *My projects* | | the projects this person works in | stays |
| *My cards & keys* | | this person's keys and their card in each organization: show, propose, create, renew, rotate, revoke, backup key | only the dialog *My key and card…* in the title bar's options |
| *Organizations* | each organization, and under one People, Projects, Hosts, Organization owners, Organization Admins | every organization this person is in; the window works in the one chosen | the entry is *Organization*, the one this computer reads; its page's menu changes it with *Choose another Porelo organization…*, by typing the other one's repository address, with no list to choose from |

**The right side never repeats the side bar.** An entry with entries under it (*My machines*, one machine,
*Organizations*, one organization) shows only what it is, its state in a few facts, and what can be done with it; a list
appears only for a leaf: *Work*, *Needs you*, *My forges*, *My projects*, *My cards & keys*, and one section of a machine
or of an organization.

**Functions sit in the row's or the page's ⋯ menu; only a few selected, especially important ones are buttons**, at
most one or two on a page, the one a person comes for first.

**Changing the organization is one action in the title bar**, which names the organization worked in.

**On a tablet the side bar stays beside the content; on a phone it is a drawer** opened with the menu button, and
choosing a leaf closes it.

### One machine's sections

Every part of what Porelo offers on a machine has its section under that machine, each with its state and its actions:

| Section | What it shows and does | Today | What the daemon serves for it |
|---|---|---|---|
| Tasks | the machine's tasks, as *Work* filtered to it | under *Work* | `List`, `Watch` |
| Projects | the projects it carries, with their repositories, put on and taken off | *Put it on a machine…* and taking it off, from the project | `Projects`, `TakeProject`, `RemoveProject`, `Clear` |
| Vault | its state (made, locked, open), the names of what it stores with their kind (never a value), store, replace and remove an entry, unlock and lock | *Show the vault* in the machine's menu lists the entries by name, kind and length, the devices that open it with revoking one, and granting an entry's authorization; making it, opening it by passphrase or device, shutting it and enrolling a device are menu entries. A value is stored only as a forge token, in a terminal; nothing replaces or removes an entry | `Credentials`, `Keyslots`, `EnrollDevice`, `RevokeKeyslot`, `UnlockWithShare`, `Lock`, `Authorizations`, `Authorize`, `VaultClear` (not called). No method removes or replaces an entry: `CredentialForget` forgets the record and keeps the secret, which `porelo vault remove` removes at the machine |
| Credentials | what the machine connects out with and where each comes from, trusted host keys | *Connections* and *Destinations* in the machine's menu | `Credentials`, `CredentialDeclare`, `CredentialCheck`, `SshKeys`, `Destinations`, `WriteDestination`, `RemoveDestination`, `TrustHostKey`, `HostKeys` (not called) |
| Agents and providers | the installed agents, the declared providers and what the vault holds for each | *Show the agents installed here* and *Show what this machine can authenticate against* in the machine's menu | `Agents`, `Providers`, `ImportCredential`, `Installable` (not called; installing needs root, so it can only say what could be installed) |
| Ecosystems | the installed ecosystem adapters | none | nothing: no method names an ecosystem adapter |
| Reach | what a task may reach and what it was refused | *What this project may reach*, per project, in the project's menu; nothing per machine | `Egress` and `SetEgress` per project only; nothing gathers them per machine or counts requests and refusals over time |
| Events | the security-relevant events, and whether none was changed | none | `Events`, `VerifyEvents` (not called) |
| Health | what `doctor` reports, and what can be cleaned up | *Check whether this machine can run anything* in the machine's menu; nothing cleans up | `Doctor`; `Prune` with `apply` and `includingWork` (not called); nothing for `tighten` |
| Managing this machine | setting it up, starting and stopping Porelo there, taking it down | start, stop, adding a user, clearing it, taking it down and forgetting it, in the machine's menu | `Node`, `Process` (not called), `Clear`, `Panic`; start, stop and set-up are commands on the machine |

A host and a person's own machine share these sections; what a host does not offer says why in words.

### One organization's sections

People, Projects, Hosts, Organization owners and Organization Admins hold what today's *Porelo organization* page and
its dialogs show and change: cards proposed, added, changed, replaced and revoked; projects with their repositories,
admins, members and review; hosts with their admins and projects; owners and admins added and removed. Creating an
organization and choosing the one worked in stay as they are. Nothing the window calls leaves an organization.

### Where a function lives

A function stands under its subject, and only there: putting a project on a machine under the machine and under the
project alike is one action reached from two places, not two. A function reachable from another page leads to its
subject's page.

## Acceptance

- Each leaf of the side bar is reached in at most three clicks from a folded side bar, and the window's own guide names
  each.
- A page with entries under it shows no list of those entries.
- The vault section lists the stored entries by name and kind and shows no value, also not in a tooltip, a log line or
  a copy.
- Changing the organization changes what *My projects*, *Needs you* and the organization's sections show, and no write
  goes to the organization not chosen.
- *My cards & keys* does all that *My key and card…* does today; the dialog is gone.
- At a phone's width the side bar is a drawer, and choosing a leaf closes it.

## Open questions

- Which of a machine's sections go first.

## To be checked

- *Organizations* as a list of several: nothing the window calls names more than the one organization this computer
  reads (`porelo setup --organization`, replaced with `--replace`), and no `porelo org` command lists others. Until the
  daemon or the organization's store names them, the entry holds that one organization. Raised with Core as a
  requirement before this part is planned.
- The sections without a call (an entry's replacing and removing, ecosystems, reach per machine, `tighten`) go into
  `doc/Contract-Gaps.md` and are raised with Core; each becomes an issue of its own once its call lands.
- How it splits. A first reading, each L or smaller:
  - the side bar as a tree, the pages with entries under them showing facts and actions, the tablet's and phone's
    layout, and one machine's sections from what the window does today (Tasks, Projects, Vault, Credentials, Agents
    and providers, Health with `doctor`, Managing);
  - *My cards & keys* in place of the dialog;
  - one organization's sections from today's organization page, with the organization changed in the title bar;
  - Events, from `Events` and `VerifyEvents`;
  - cleaning up under Health, from `Prune`;
  - one issue per section that waits on a call: an entry's removing and replacing, ecosystems, reach per machine,
    `tighten`, and the list of organizations.
