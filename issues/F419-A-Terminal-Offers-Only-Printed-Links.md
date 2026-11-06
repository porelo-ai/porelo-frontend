# F419 — A Terminal Offers Only Printed Links

**Status:** Accepted (operator, 2026-11-06).
**Size:** XS - links under a terminal leave out an address that still holds a variable or a template, and one that
only the task can reach.

**What must be true.** Under a terminal the window offers to open only a link that was printed as an address: none
holding `$`, `${…}` or its encoded `%7B…%7D`, and none only the task reaches (`host.containers.internal`, the task's
own `localhost`), which this computer cannot open.

## Why

The operator's walk on the rehearsal VM (2026-11-06): under the sluice task's terminal the window offered "Open
github.com/mvdan/sh/releases/download/v/$VERSION/shfmt_v/$%7BVERSION%7D_linux_amd64 in your browser", a link taken
from a script's text with its variables unexpanded, which leads nowhere, and "host.containers.internal/sluice.git:
only reachable inside the task".

## Plan

- `lib/src/app/links.dart`: a found address holding `$`, `{`, `}` or `%7B`/`%7D` is no link; one `onlyInsideTheTask`
  is not listed (the login's reply, which the window forwards, stays as today).
- `lib/src/ui/terminal_links.dart`: the line "only reachable inside the task" goes with it.
- No test goes red first beyond the link finder's own: a link that leads nowhere is offered, nothing is lost or sent.

## Built

- `links.dart`: `hyperlinkOf` takes no address holding `$`, `{`, `}`, `%7B` or `%7D` (either case).
- `terminal_links.dart`: a link only the task reaches is left out of the list, with its "only reachable inside the
  task" line; in a terminal that forwards a login's reply, and for the login's own page, it stays as before.
- `task_terminal_test.dart`'s link test holds both; red first on the old code (eight "only reachable inside the task"
  lines, and the `shfmt` template offered).
