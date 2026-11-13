# F205 — The Host's Setup Commands Run By Their Paths

```json
{
  "$schema": "issue-1.json",
  "id": "F205",
  "title": "The Host's Setup Commands Run By Their Paths",
  "state": "Idea",
  "size": "-",
  "priority": "Low",
  "rank": 38,
  "blockedBy": [],
  "covers": "Every command `porelo-host` runs on the host over ssh, and through `sudo` above all, named by its absolute path."
}
```

**What must be true.** Every command `porelo-host up` and `down` run on the rented host over ssh, and above all those
it runs through `sudo`, is named by its absolute path (`/usr/bin/mkdir`, `/usr/bin/sha256sum`, `/usr/bin/sudo`,
`/usr/bin/env`, `/usr/bin/ansible-playbook` and the rest), so the login user's `PATH` on the host can put no other
program in their place, as the rules ask of a binary run with more rights than its caller.

## Why

The upload of the setup's files ([F197](README.md#f197)) runs its own tools by path, while the older commands of `up`
in `packages/porelo_host/lib/src/host_run.dart` (the inventory's `mkdir -p`, the collection's `sha256sum`,
`sudo env … ansible-playbook`) still go by `PATH`. On a rented image the login user's `PATH` is the distribution's, so
nothing is known to be wrong today; on a machine given with `--given` it is whatever that account holds.

## Plan

- **Read in today's code:** every `remote.run` in `host_run.dart` and the commands it builds, and which of them run
  through `sudo`.
- **Red first:** a test against the remote stand-in that every command `up` and `down` run names its programs by an
  absolute path.
