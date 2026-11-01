# F293 — Host Deliveries Hardened

**Status:** Idea.
**Severity:** medium.
**Size:** M - git's environment, the project transport's remote scripts and the registry transport's hold, across
several modules and their tests; no contract with another repository.

**What must be true.** What the interface brings to a host runs in a clean environment, cannot be redirected or
replaced between steps, and is never read half placed or from a checkout being pruned.

## To be fixed

1. **git in a clean environment:** every git the interface runs for registry bundles and project copies starts from
   an environment without inherited `GIT_*` variables, `GIT_ASKPASS` or `SSH_ASKPASS`, with only what it sets itself.
   Today `runHere` takes the parent's environment, so a `GIT_COMMON_DIR` or `GIT_OBJECT_DIRECTORY` there redirects
   where refs and objects go.
2. **One ssh call for copy and place:** staging a project's bundles, checking the folders, copying and placing run in
   one ssh session, with `change.id` checked before it is used in a path. Today they are separate calls, so a folder
   changed between them is not checked again, and an existing setup folder keeps a mode wider than `0700`.
3. **Bundles placed atomically:** `project.bundle` and `access.bundle` are placed in one step, so a `sync` never reads
   a new project bundle beside an old access bundle.
4. **sudo without the login shell:** `sudo -n porelo-host-person sync` runs directly, not wrapped in the account's
   login shell, so a profile's output or a non-POSIX shell cannot change the answer that is read.
5. **The registry held while sending:** sending a registry bundle to a host holds the registry, so a refresh's prune
   or a checkout change does not run while the bundle is read from the checkout's objects.

## Plan

- `lib/src/app/run_here.dart`, `lib/src/app/project_copies.dart`, `lib/src/app/host_access_adapters.dart`,
  `lib/src/app/project_access_transport.dart`.
- **Red first:** for 1, a real git run with `GIT_OBJECT_DIRECTORY` set in the parent leaves the registry checkout
  untouched; for 2 and 3, the transport's script run against a shell and a folder replaced by a link between steps;
  for 4, a profile that prints after the sync; for 5, a refresh started while a bundle is sent waits for it.

## To be checked

- Whether a private `https://` access repository still authenticates once git's global configuration and its
  credential helper are left out, or whether the helper is passed on by name.
