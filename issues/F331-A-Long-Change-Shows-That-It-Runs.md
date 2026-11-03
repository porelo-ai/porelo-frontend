# F331 — A Long Change Shows That It Runs

**Status:** Idea.

**What must be true.** A person who asks for a change that takes a while sees at once that it runs, and sees where a failure
will be said.

In a walk *Open the project* in the dialog *Open <project>?* showed no progress while it ran. The operator proposes to handle
it as a new host is handled: close the dialog, show the project at once marked as in progress, and say failures on the
project's page.

## What happens now

Read from the code, not measured. `OrganizationChangeDialog` greys its two buttons, blocks closing, and shows nothing else
until the answer. Behind it `porelo project open` reads the organization, makes the repository at the forge if there is
none, pushes the signed first `project.yml`, and files the address. `OrganizationChangeMark` shows a running change on the
page, but under the dialog.

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

The cheap alternative is a progress line inside the frame, naming what runs: one place, every dialog on it, no new state.
It does not give the operator's closed dialog.

## Open questions

- A progress line in the frame, or the operator's proposal for opening a project? Recommended: the line first for every
  dialog on the frame, then the proposal only if a measured open still feels too long in a dialog.

## To be checked

- How long opening a project takes at real GitHub.
