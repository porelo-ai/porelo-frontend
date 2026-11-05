# F389 — A Refused Forward Says Which Credential

**Status:** Backlog.
**Size:** S - words in place of a raw line, once the daemon says them.

**What must be true.** A forward that the upstream refuses shows which credential was used, or that none is declared for the address, and names `porelo credentials declare` and `porelo credentials check`. It does not show git's raw command line.

## Why

A real test showed `'git --git-dir ... push --end-of-options git@github.com:<organization>/<repository>.git ...' failed with exit code 128: ERROR: Permission to <organization>/<repository>.git denied to deploy key`. No credential was declared for that address, so ssh chose by itself and offered a key the forge knows as a deploy key without that right. The line names neither what went wrong for the person nor what to do.

## Plan

- Agree in the room how the daemon says it; the window shows those words where the raw line stands today.

## Acceptance

- A refused forward with no credential for its address says so, and names both commands.
- A refused forward with one says which was used.
- No git command line reaches the window for this refusal.

## Decided while building

## Open questions

## To be checked
