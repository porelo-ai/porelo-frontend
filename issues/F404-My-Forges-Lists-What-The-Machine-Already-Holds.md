# F404 — My Forges Lists What The Machine Already Holds

**Status:** Backlog.
**Size:** S - *My forges* takes the forge connections the machine's vault declares beside those set up in the window,
each with where it comes from, and marks the organization's forge; no daemon change.

**What must be true.** *My forges* lists every forge this person can reach: those set up in the window, and those the
machine already holds a credential for (declared on the command line, kept in its vault, a file, the environment or
the ssh agent), each saying where it comes from, with the Porelo organization's forge marked. A forge listed this way
asks for no second token.

## Why

The operator's walk on the rehearsal VM (2026-11-06): this computer follows porelo-ai on github.com and its machine
holds a token declared for `https://github.com/porelo-ai/` (`porelo credentials declare`, `porelo vault put`), but
*My forges* says 0: it lists only the forges set up in the window.

## Plan

- What the daemon tells the window already: `Credentials()` answers `connections`, one per declaration, with its
  `match` (a URL prefix, the longest wins), `kind` (`TOKEN`, `SSH_KEY`, `BASIC`, `OAUTH`), `purpose`, `source`
  (`VAULT`, `FILE`, `ENVIRONMENT`, `AGENT`), `present` and `expires`, and never a value; the window reads it already
  (`VaultState.connections`). Nothing new is needed of the daemon.
- `lib/src/app/forge_connection.dart`: the forges listed are the window's own, joined by host with the connections of
  the machine shown whose purpose is `git` or `any`, each with its source; one the window set up and one declared for
  the same host are one forge with both sources.
- `lib/src/ui/forges_page.dart`: the row says where its credential comes from ("declared on this machine, in its
  vault" and so on), whether it is present now, and marks the organization's forge (`organizationForgeAddress`).
- **The test that goes red first:** a forges model test with a machine whose vault declares a token for
  `https://github.com/porelo-ai/`: *My forges* lists github.com once, from the vault, and offers no sign-in that would
  ask for a second token. It guards a person who set up by the command line told to paste a token again.

## Acceptance

- A token declared for the organization's address shows its forge under *My forges*, from the vault, marked as the
  organization's, with nothing to paste.
- A forge set up in the window and declared on the machine is listed once, with both sources.
