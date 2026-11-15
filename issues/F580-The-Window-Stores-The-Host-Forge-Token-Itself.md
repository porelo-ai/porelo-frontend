# F580 — The Window Stores The Host Forge Token Itself

```json
{
  "$schema": "issue-1.json",
  "id": "F580",
  "title": "The Window Stores The Host Forge Token Itself",
  "state": "Implementing",
  "size": "M",
  "priority": "High",
  "rank": 14,
  "blockedBy": [],
  "covers": "Story ST362: a person admitted to a host with a local forge never stores their forge token there by hand: the window runs the machine's own store command for it once, by itself, and Needs you offers Store it now in place of a command to copy."
}
```

**Why this size.** Two ways in (by itself, and from *Needs you*), one run over ssh with its outcome in words, the
host vault opened first where it is shut, and guards on a command that ends in a credential; one answer is still
asked of the daemon's side.

**What must be true.** A person admitted to a host whose forge is local sees its pull requests without typing a
command on the host: the window stores their forge token there, and says only what came of it.

## Plan

- Today: the daemon refuses a host forge's pull requests with `MissingHostForgeToken {credential, storeCommand}`,
  its command `porelo host forge-token`, which mints the person's token through root's helper on the host and writes
  it straight into their host vault. `PullRequestsRefusedRow` (`lib/src/app/host_pull_requests.dart`) shows that
  command to copy into a terminal on the host (`attention_view.dart`), and nothing runs it.
- The window runs the command the machine names, never one of its own: `ssh <the machine's loginSshOptions> -T
  <host> inTheLoginShell(storeCommand)`, as the card's login, standard input closed, no terminal. The token passes
  between root's helper and the vault on the host alone; this side reads only the command's exit code and its last
  line of words, which it shows as they come.
- By itself: the first time in a window's run that a machine answers `MissingHostForgeToken` for a project, the
  window runs it once for that machine; a run that fails leaves the row as it stands, with the command's reason.
- *Needs you*: the row offers *Store it now* (a `Command` in `commands.dart`, home the row) in place of the line to
  copy; while it runs, the row says so and offers no second press. With the host vault shut it opens the vault
  first, as the window's other host actions do (`_unlockMachine`), then runs the command.
- After a run that ended 0, the machine is asked for the project's pull requests again, and its answer is the
  verdict; nothing is applied optimistically.
- Harm and tests, red first: the token never in a command line, a log or the window (the command line is the
  machine's own words through the login shell, and the run's output is never logged); one run per machine at a time,
  so a second press or the run by itself beside a press mints no second token (each issue revokes the one before);
  the run goes to the card's own login on that machine, never root and never another machine's options.

## Acceptance

- The guards above in `test/app` and a widget test of *Store it now* against a fake run, each seen red; a feature
  scenario where the row turns into the machine's pull requests after the run.

## To be checked

- Settled with Agent Core: a shut host vault refuses the pull requests with `HostPullRequestsRefused`
  (`vault-unreadable`) before the token is looked for, so `MissingHostForgeToken` comes only from an open vault
  without the entry; the window opens the vault on the first and runs the command on the second.
- porelo is to answer a shut vault from `porelo host forge-token` with its own exit code, 77, every other refusal
  staying 69, and to name `--if-forge` in the command; the window reads 77 for that command alone and is built once
  that stands in porelo.
