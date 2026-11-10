# F455 — The Organization Read Now From The Window

```json
{
  "$schema": "issue-1.json",
  "id": "F455",
  "title": "The Organization Read Now From The Window",
  "state": "Implementing",
  "size": "S",
  "priority": "Medium",
  "rank": 9,
  "blockedBy": [],
  "covers": "*Read the organization now* asks the host to read the organization at once."
}
```

**Why this size.** one command on the machine's organization page that asks the host to read the organization now, and
its answer said.

**How it stands.** The host's own way to start its follow of the organization on demand is on Porelo's main
(2026-11-10): `porelo host follow`, which the window runs in the person's own account on the host through its login
shell; Porelo's interface for the window has no call for it, by design.
- Built: *Read the organization now* on the machine's organization page, beside the connection and the projects
  that wait before the machine takes them, for anyone connected there.
- It says the machine's answer: done, a completed read's failing status with the machine's last words, or its
  refusal in its own words. A Machine Admin then sees what the machine says of itself, read at once.
- A machine whose Porelo does not know the start, or answers it as unavailable (status 69), greys the action with
  that reason until the connection is made anew; nothing is run on it.
- A read longer than five minutes is ended on this computer by the window's limit on one command, and said so,
  while the machine finishes it; Porelo allows twelve minutes.
- Not seen yet against a real host: the follow's journal showing the read the window started.

**What must be true.** A person who changed the organization (placed a project, gave a token) asks the host to read
it now from the window, instead of waiting up to five minutes for its next round.
- *Read the organization now* on the machine's organization page, and beside a project that waits on the host's next
  read, starts that read and says when it is done or why it could not start.
- Where the host offers no such start, the action is greyed with that reason.

## Plan

- `SshHostFollow` in `lib/src/app/host_follow.dart` runs `porelo host follow` on the machine through `onTheMachine`
  (ssh to the person's account, the login shell), and first `porelo host follow --help`, which starts nothing, to
  learn whether the machine's Porelo offers the start. A completed answer (`completed`, `exitCode`) is said as done
  or with its status and the machine's last line; status 69 without one is `HostFollowUnavailable`; any other
  refusal is the machine's last line on standard error.
- `HostConnections.whyNotFollowNow` and `followNow`; `CardHostConnections` asks once per connection whether the
  machine offers the start, says *Connect first* without one, and keeps an unavailable answer until it is made anew.
- `readOrganizationNowCommand` in `lib/src/app/commands.dart`, homed on the organization row; the machine's page
  (`lib/src/ui/organization_host_pages.dart`) shows it as a button beside *Disconnect*, with its reason when greyed,
  and after the read has a Machine Admin's page read the machine's `org status` at once.
- Red first: the page's scenario where the machine's state changes only after the read (no such action, "Bad state:
  No element"), the greyed machine that runs nothing, and the runner's answers ("Error when reading
  'lib/src/app/host_follow.dart'"). The organization pages have no feature file, so the scenario is a widget test
  of the page with the fixture connections.

## Acceptance

- Against the mock host: the action shows the changed state at once; seen to fail: a host without the start, which
  must grey the action, not run anything.
- Against a real host: the follow's journal shows the read started by the window.
