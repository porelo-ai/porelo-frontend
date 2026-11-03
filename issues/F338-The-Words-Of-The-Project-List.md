# F338 — The Words Of The Project List

**Status:** Idea.

**What must be true.** A person new to a project's list can tell from its words what each row says and what each button does.

In a walk a developer asked of a project's row: "What is *Open it on <host>* supposed to mean? Why open?"

## What the words do now

Read from the code, not run.

- **The row** opens the project's own page, with its repositories and members.
- ***Open it on <host>*** does one of two things, and the label does not say which. Where this computer is connected and the host
  lists the project, which it does only after this person's first start there, it opens the project's working page on the host:
  its work, agents, messages and saved jobs. Otherwise it goes to the host's page, connected or not, and that page starts no work,
  as [F336](README.md#f336) says.
- **`on no host yet`** is true, and leaves out that it matters and whose it is to change.
- ***Projects on your machines, outside the organization*** opens the list of every project on every machine this computer watches,
  each machine's *Without a project* among them. Nothing filters out a project of the organization that a host lists, so
  *outside the organization* can be wrong.
- **`on this computer alone, outside the organization`** on a local project's row means the same list by other words, and its click
  leads to that list and not to the project.

## The proposal

| Now | Proposed | Why |
|---|---|---|
| *Open it on <host>*, not connected | *Connect to <host>*, doing it | what it takes, said as what it does |
| *Open it on <host>*, connected | *Work on it* | the row already names the host |
| `on no host yet` | `not on a host yet · a host admin puts it on one` | says whose it is |
| *Projects on your machines, outside the organization* | *All projects on your machines* | true of what the list holds |
| `on this computer alone, outside the organization` | `only on this computer` | shorter and enough |

*Work on it* does not become *Start work*, which [F336](README.md#f336) puts on a host's page. *Start work* starts something new.
This button also leads to work already running, and to the agents, messages and saved jobs beside it, and the project's working page
has *Start work* itself. For a first start, where the host does not list the project yet, *Work on it* opens *New work* with host and
project filled in; that is what [F336](README.md#f336) leaves to be checked.

## To be checked

- Whether a project of the organization that is on no host can be worked on at all, as the proposed `not on a host yet` assumes it
  cannot.
- Whether *All projects on your machines* should rather be filtered, as the words now promise.
