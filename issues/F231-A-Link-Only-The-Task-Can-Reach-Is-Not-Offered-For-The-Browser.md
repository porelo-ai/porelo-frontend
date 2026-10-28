# F231 — A Link Only The Task Can Reach Is Not Offered For The Browser

**Status:** Analyzed; found in walk 21 after the operator's round of sprints 6 to 6i.
**Size:** XS - links a task's program prints to a host only its container reaches shown as such, not as a button to
the browser, and the test; about 30 minutes.

**What must be true.** Below a task's terminal, a link its program printed to an address only the container reaches
(`host.containers.internal`, the gate as the task sees it, or a loopback address inside it) is not offered as *Open …
in your browser*; it is shown as plain text, "only reachable inside the task", or left out. Links to addresses this
computer reaches (GitHub, a pull request) keep their button.

## Why

Seen in walk 21 (20:18 local): below the terminal of `porelo-sluice-dry-sluice` the button *Open
host.containers.internal/sluice.git in your browser* appeared after the agent's push. That is the gate's address as the
container sees it (the task's `origin`), which the laptop's browser cannot open; the button leads nowhere.

## Read from the code

`terminal_links.dart` offers every web address a program marks as a link (OSC 8) as a button, so as not to let the
program choose where the browser goes on its own; it does not know which hosts only the container reaches. git in the
task printed its remote's address after the push.

## Plan

- `terminal_links.dart`: a link whose host is `host.containers.internal`, `localhost`, `127.0.0.1`/`::1` or a name
  without a dot, printed in a task's terminal, is listed as text with "only reachable inside the task" and no button.
- **Red first:** a printed link to `http://host.containers.internal/sluice.git` gives no browser button; one to
  `https://github.com/…` still does.

## Acceptance

- After a task's push, no button offers the gate's inside address to the browser.
