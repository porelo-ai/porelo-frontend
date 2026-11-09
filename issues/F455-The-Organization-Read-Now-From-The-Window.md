# F455 — The Organization Read Now From The Window

**Status:** Backlog; blocked by the host's own way to start its follow of the organization on demand.
**Size:** S - one command on the machine's organization page that asks the host to read the organization now, and
its answer said.

**What must be true.** A person who changed the organization (placed a project, gave a token) asks the host to read
it now from the window, instead of waiting up to five minutes for its next round.
- *Read the organization now* on the machine's organization page, and beside a project that waits on the host's next
  read, starts that read and says when it is done or why it could not start.
- Where the host offers no such start, the action is greyed with that reason.

## Plan

- A `Command` in `lib/src/app/commands.dart`, homed on the machine's organization page
  (`lib/src/ui/organization_host_pages.dart`), that runs the command the host names for it over ssh, through the
  login shell, and refreshes the host's progress after it.
- Red first: a feature scenario where the host's progress changes only after the read; the action then shows the new
  state without a wait.

## Acceptance

- Against the mock host: the action shows the changed state at once; seen to fail: a host without the start, which
  must grey the action, not run anything.
- Against a real host: the follow's journal shows the read started by the window.
