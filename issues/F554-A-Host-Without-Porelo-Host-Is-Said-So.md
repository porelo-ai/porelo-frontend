# F554 — A Host Without Porelo-Host Is Said So

```json
{
  "$schema": "issue-1.json",
  "id": "F554",
  "title": "A Host Without Porelo-Host Is Said So",
  "state": "Review",
  "size": "XS",
  "priority": "Highest",
  "rank": 4,
  "blockedBy": [],
  "covers": "A host whose /usr/sbin/porelo-host is missing, as after a setup that stopped before installing it, is said so on its page in the window's words, with how to go on, instead of the last line env printed there (uutils env's \"use -[v]S to pass options in shebang lines\")."
}
```

**Why this size.** The cause is measured; one exit read in two places, and their tests.

**What must be true.** A host without porelo-host says so on its page, under GNU and uutils `env` alike.

## Plan

- **Measured** (Agent Core, `ubuntu:26.04`, uutils `env` 0.10.0): when the program `env` should run is missing, also
  by an absolute path, uutils `env` exits 127 and prints "env: '<prog>': No such file or directory" and then, as its
  last line, "env: use -[v]S to pass options in shebang lines". On the Scaleway host `/usr/sbin/porelo-host` was
  missing, as its setup stopped before installing it, so the window's `env -i ... /usr/sbin/porelo-host org status
  --json` got exactly that, and `SshHostProgress._ask` (`lib/src/app/host_progress.dart`) shows the last line of
  standard error. No quoting fault: the words reach `env` apart, under GNU and uutils `env` alike.
- **The change.** A run of porelo-host on the host (`SshHostProgress._ask`, the token given by `tokenGivenWords` in
  `lib/src/app/host_token.dart`, and the membership read in `packages/porelo_host/lib/src/host_run.dart`) that ends with exit 127 says, in the window's words, that porelo-host
  is not installed on that machine, that its setup stopped before installing it, and that *Set up this machine…* goes
  on with it; the shell's own lines are not shown as the reason, nor kept as the step's words. Any other exit keeps today's last line.
- **Red first** (harm: a machine whose setup stopped shows a line of `env` that sends the person after a quoting
  fault, and nothing says porelo-host is missing): a test of `SshHostProgress.status` with a run that answers exit
  127 and uutils `env`'s two lines expects the refusal to name the missing porelo-host and not to hold `-[v]S`; the
  same for the membership read.

## Acceptance

- Against a host without `/usr/sbin/porelo-host`, its page says porelo-host is not installed there and how to go on;
  the tests are seen red on today's code.
