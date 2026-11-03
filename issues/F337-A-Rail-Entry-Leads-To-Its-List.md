# F337 — A Rail Entry Leads To Its List

**Status:** Implementing.
**Size:** S - one place in the shell, and a test.

**What must be true.** A rail entry always lands on the first page that entry opens, whatever page was open under it or was last
opened there.

**The operator:** a click on *Work* in the rail shows all work; the way from a machine's or a project's page keeps the narrowing.

In a walk, on a project's page, a click on *Projects* in the rail stayed on that page; only the arrow at the top went back to the
list. A person expects the rail entry to lead to the list. The operator added: a rail entry lands on the subpage last opened there, where the
expectation is the first page.

## Where it holds and where not

Read from the code, not run.

| Rail entry | Page open | A click on the entry |
|---|---|---|
| *Projects* | a project of the organization | stays |
| *Projects* | the list of a machine's projects, reached by way of the organization's | stays |
| *Machines* | a host's page | stays |
| *Machines* | a machine's page | goes to the list |
| *Projects* | a project's page on a machine | goes to the list |
| *Forges* | a forge's page | goes to the list |
| *Work*, *Needs you* | a piece of work or anything else opened | goes back |
| *Work* | narrowed to a machine or a project | keeps the narrowing |

*Organization* has no page of its own to return from: a project or host opened there moves the rail to *Projects* or *Machines*.

The three that stay are the organization's. Each keeps its page in a field of the shell's state (`_organizationProject`,
`_machineProjects`, `_organizationHost`), and `ShellModel.goTo` knows nothing of those. The older pages live in the model, which
`goTo` clears.

The same fields do something else: leaving for *Work* and coming back to *Machines* shows the host's page again, not the list,
which a machine's page does not do.

*Work*'s narrowing is the one case outside the organization's pages. `WorkView` holds it on purpose, so that it stays while something
takes the page's place, and a machine's or a project's page leads to *Work* narrowed.

## The shape

The rail's `onGo` in the shell clears the three fields before `goTo`. Not `goTo` itself: the code that opens a host's or a project's
page sets the field and then calls `goTo`, and clearing there would undo it.

The test is a click on the rail from each of the three pages, seen red first, and from another entry and back.
