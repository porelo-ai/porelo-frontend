# F293 — Host Deliveries Hardened

```json
{
  "$schema": "issue-1.json",
  "id": "F293",
  "title": "Host Deliveries Hardened",
  "state": "Idea",
  "size": "M",
  "priority": "Medium",
  "rank": 22,
  "blockedBy": [],
  "covers": "Host deliveries hardened: git in a clean environment, commands without the login shell or a deliberate exception."
}
```

**Why this size.** git's environment and the commands that run in a login shell, across several modules and their tests;
no contract with another repository.

**Severity.** Medium.

**What must be true.** What the window brings to a host today runs in a clean environment, cannot be redirected or
replaced between steps, and is never read half placed.

## How it stands

`lib/src/app/run_here.dart` starts processes with the parent's environment plus the supplied entries.
`isolatedGit` in `lib/src/app/commit_signing.dart` sets global and system configuration controls and disables
terminal prompts; `ProjectWorkspace._git` in `lib/src/app/project_workspace.dart` sets the prompt and, when needed,
its own askpass. Neither clears inherited `GIT_DIR`, `GIT_COMMON_DIR` or `GIT_OBJECT_DIRECTORY`, so these files
do not meet the clean-environment promise.

The window brings a host its collection and machine file (`HostRun.up` in
`packages/porelo_host/lib/src/host_run.dart`), and runs its commands there over ssh. `inTheLoginShell` wraps
`porelo-host-push` in `packages/porelo_host/lib/src/project_transfer.dart` and the commands in
`lib/src/app/connections.dart`, `machines.dart`, `session.dart`, `setup_run.dart` and `tunnel.dart`.

## To be fixed

1. **git in a clean environment:** every git the interface runs starts from an environment without inherited `GIT_*`
   variables, `GIT_ASKPASS` or `SSH_ASKPASS`, with only what it sets itself. `runHere` in `lib/src/app/run_here.dart`
   takes the parent's environment, so a `GIT_COMMON_DIR` or `GIT_OBJECT_DIRECTORY` there redirects where refs and
   objects go.
2. **Commands without the login shell:** `porelo-host-push` and the other commands above run directly, not wrapped in
   the account's login shell, so a profile's output or a non-POSIX shell cannot change the answer that is read. A use
   that needs the login shell, as a plain ssh command has no local bin folder on its `PATH`, is recorded in
   `doc/decisions.md` as a deliberate exception.

## Plan

- `lib/src/app/run_here.dart`, `lib/src/app/commit_signing.dart`, `lib/src/app/project_workspace.dart`,
  `packages/porelo_host/lib/src/project_transfer.dart` and the other uses of `inTheLoginShell`.
- **Red first:** for 1, a real git run with `GIT_OBJECT_DIRECTORY` set in the parent leaves the checkout untouched;
  for 2, a profile that prints before the command's answer.

## To be checked

- Whether a private `https://` repository still authenticates once git's global configuration and its
  credential helper are left out, or whether the helper is passed on by name.
