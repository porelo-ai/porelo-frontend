# F224 — Porelo-Host Says Which Server Is Rented Now

**Status:** Analyzed; placed with the bug fixes after the operator's tests of sprints 6 to 6i.
**Size:** S - a read-only `porelo-host find` over the provider's existing `find`, and its tests; about 1 hour.

**What must be true.** `porelo-host find --project NAME --scaleway-project ID [--zone Z]` asks the provider which
server carries the project's tag and prints one JSON line with its id, address and whether it is ready, exit 0; where
none carries it, it says "no server of NAME is rented" and exits 69. It changes nothing: no rent, no ssh, no file
written, no known host taken. The provider's key is read from the keyring as for `up` and `down`, never from the
command line.

## Why

A guide script must not ssh to a server that was given back, whose address may already be somebody else's. Seen in
the operator's round: a server given back from a terminal (`down --give-back-anyway`) stayed listed in the interface,
and `porelo-host`'s `known_hosts` keeps a key after a give-back, so neither tells a given-back server from a live one.
Only the provider does, and its key is `porelo-host`'s alone; the 6e to 6i guide libraries then refuse unless `find`
names the address they are about to use.

## Plan

- `bin/porelo_host.dart`: the verb `find`, with `--project`, `--scaleway-project`, `--zone` only; the provider built
  as for `up` (`scalewayFor`), then `provider.find(tag)` once, and one JSON line out.
- **Red first:** with a stand-in provider, a tagged server prints its line and exits 0; none exits 69; nothing else is
  asked of the provider than its list.

## Acceptance

- On a project with a rented server, `find` names that server's address; after its give-back, `find` exits 69.
- No other request than the provider's list is made.
