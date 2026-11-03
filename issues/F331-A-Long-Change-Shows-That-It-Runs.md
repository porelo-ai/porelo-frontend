# F331 — A Long Change Shows That It Runs

**Status:** Idea.

**What must be true.** A person who asks for a change that takes a while sees at once that it runs, and sees where a failure
will be said.

In a walk *Open the project* in the dialog *Open <project>?* showed no progress while it ran. The operator proposes to handle
it as a new host is handled: close the dialog, show the project at once marked as in progress, and say failures on the
project's page.

Later in that walk, adding a member at real GitHub took very long before the person appeared in the list; the operator asks
for a provisional row marked like *adding…* while it runs. A repository's removal lagged too: a check right after it still
listed the repository, and the walk did not establish why.

## What happens now

Read from the code, not measured. `OrganizationChangeDialog` greys its two buttons, blocks closing, and shows nothing else
until the answer. Behind it `porelo project open` reads the organization, makes the repository at the forge if there is
none, pushes the signed first `project.yml`, and files the address. `OrganizationChangeMark` shows a running change on the
page, but under the dialog.

After a member or a repository is changed, the wait has three parts, each a new `porelo` process that goes to the forge:

1. the change itself, with the dialog open;
2. `porelo org`, reading the organization again, with the dialog still open;
3. `porelo project show`, once the dialog has closed, with the old list standing and no mark at all, because
   `OrganizationChangeMark` has stopped.

The third part fits both findings: the person is not in the list yet, and a removed repository is still listed, though the
change is already made. A line in the dialog would not cover it.

## Other dialogs with the same gap

- **Every dialog on that frame**, in the same way: on the organization's page *Create the organization*, adding a project, a
  host or an owner, and accepting a new card; on a project's page its address, adding a repository or a member; on a host's
  page its address and host key, and putting a project on it; and every question before a removal. *Create the
  organization* makes a repository as well and should wait about as long as opening a project.
- **Outside the frame**, `destinations_view.dart` and `default_view.dart` disable their buttons while busy and show no
  progress. This comes from a search for busy flags and is no full list.

## What the proposal costs

The new host is not quite the model. *Prepare a server* keeps its dialog open until setup ends, following the protocol in it;
only its row in *Machines* appears at once. That row rests on a saved record, a protocol, and ways to go on or take it down,
for a run of minutes. A project needs less, but closing the dialog early still means:

- **A refusal needs a new home.** The frame's rule is that a refusal stays in the dialog. On the page it must outlast leaving
  the page, so it moves from the page's state into `Organization`, per project, with a way to ask again under the same id.
- **Other changes must wait visibly.** `Organization` takes one change at a time. The open dialog prevents a second today;
  with it closed every action on these pages must grey out, or answer `Another change is still being asked for.`
- **Closing the window while it runs** ends with no answer, and the id that makes asking again safe is held only in memory.
  The page then reads what stands, and a repository may exist before the address is filed.
- **The walks and the tests that wait for the dialog** change with it.

A provisional row answers part of this. The refusal has a natural home in the row it concerns, which keeps its words and
offers to ask again or to drop it. *Nothing is shown as done before the source's own answer* still holds, as the row says
*adding…*, but the page's rule that *a refused write changes no row* changes. A row marked *removing…* serves a removal,
and the costs of the other changes and of a closed window stand.

The cheap alternative is a progress line inside the frame, naming what runs, and the mark kept on until the page has read
again: one place, every dialog on it, no new state. The dialog stays open, and the row appears only at the end.

Neither shortens the wait.

## Open questions

- A provisional row and a closed dialog, or a progress line in the dialog? Recommended: the provisional row for what adds to or
  takes from a list (members, repositories, projects, hosts, owners), and the line for what has no row, such as an address or
  *Create the organization*. Opening a project marks its existing page the same way.

## To be checked

- How long each of the three parts takes at real GitHub, and opening a project too. If the third is most of it, the page might
  use what the change already answered.
- Whether the removal in the walk was this third part: nothing of the walk's state was read.
