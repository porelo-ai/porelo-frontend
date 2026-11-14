# F554 — A Host's Reads Run Under Uutils Env

```json
{
  "$schema": "issue-1.json",
  "id": "F554",
  "title": "A Host's Reads Run Under Uutils Env",
  "state": "Backlog",
  "size": "S",
  "priority": "Highest",
  "rank": 3,
  "blockedBy": [],
  "covers": "On a laptop and a host whose env is uutils coreutils (Ubuntu 26.04), a host's page reads its Porelo and how it stands instead of showing env's refusal \"use -[v]S to pass options in shebang lines\"; every env the window runs or sends gets its options as separate words, under GNU env too."
}
```

**Why this size.** One call to find by measurement, its fix and a test against uutils env's rule; one module.

**What must be true.** With uutils `env` on both ends, a host's page shows its Porelo and when it last answered, and
no `env` refusal stands under its title.

## Plan

- **Seen.** On the operator's laptop and the Scaleway host, both Ubuntu 26.04 with `env (uutils coreutils) 0.10.0`,
  the host's page shows "env: use -[v]S to pass options in shebang lines" under its title, beside "Porelo not read ·
  last answered not read". uutils `env` says exactly that (exit 125) when its options arrive as one argument word
  without `-S`, as `env "-i PATH=/usr/bin /bin/echo hi"`, or as a shebang `#!/usr/bin/env prog -opt` hands them;
  GNU `env` takes more. The host side was measured clean (no forced command, a clean follow).
- **Read, not the cause.** `hostCommandEnvironment` (`packages/porelo_host/lib/src/host_command.dart`) goes as part
  of the one remote command `SshHostProgress._ssh` (`lib/src/app/host_progress.dart`) hands ssh, which root's shell
  splits into words; `onTheMachine` (`lib/src/app/connections.dart`) quotes each word for the login shell;
  `Machine`'s daemon relay (`lib/src/app/machines.dart`) runs `porelo daemon connect` with no `env`. No shebang
  `#!/usr/bin/env <prog> <option>` stands in this repository, porelo or porelo-host.
- **Measure first.** On the laptop, the window's log names each process the host page starts and its stderr; the
  call whose stderr is that line is the cause. Where the log does not name it, the same page against a VM with
  uutils env (`ubuntu26.04`) and `strace -f -e trace=execve` on the window finds the `execve` of `env` with one joined
  word. The plan's fix follows from that call; it goes into the issue before the code.
- **Red first** (harm: a host's state and Porelo cannot be read at all on Ubuntu 26.04): a test runs the found
  command line through a stand-in `env` first on `PATH` that refuses, as uutils does, any option word holding a space,
  and passes under the real GNU or uutils `env` of the machine running it; it fails on today's code.

## Acceptance

- The host's page on the operator's laptop shows its Porelo and last answer against the Scaleway host; the test is
  seen red on today's code and green under both `env`s.

## To be checked

- Which process prints the line: by the window's log first, by `strace` on the VM where the log does not say.
