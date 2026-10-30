# F244 — A Bring Reads A Private Repository With The Follow's Credential

**Status:** Accepted.
**Size:** S - the bundle's clone answered by the same vault entry the machine's follow uses.

**What must be true.** A bring whose project lives in a private repository reads it with the same credential the machine's follow used, so the bundle is made wherever the follow succeeded. The credential's value never appears in an argument, a file or the interface.

## Why

Operator's finding in walk 23, Step 7 of 7 of *Put walk6-demo on a server* on VM A (2026-10-30): "The drive: Git could not read the followed repository and its verified commit or create the project bundle." `HostFiles.bundle` (`packages/porelo_host/lib/src/host_files.dart`) clones the followed URL with plain git and `GIT_TERMINAL_PROMPT=0`. walkadmin's git has no credential for github.com, while the follow read the same repository with the token in the machine's vault. Walk 22 passed most likely because its repository could be read without a token.

## Plan

- The bundle's `git clone` gets `-c credential.helper=` (clearing inherited helpers) and `-c credential.helper='!porelo vault credential --entry=<entry>'`. Core's own credential helper answers from the vault; only the entry's name is an argument.
- `<entry>` is the entry the follow uses for that URL: `git.token.<host>`, else `git.token`, in Core's order. Where neither is listed (`porelo vault list`, names only), the bring says so before the clone: "The machine's vault holds no token for <host>; the follow's credential is needed to read this private repository."
- A public repository still clones without asking anything.
- **Red first:** a test that the clone of a stand-in private remote, which answers only to a helper, succeeds with the helper arguments and no value in any argument; a test that a missing entry is refused by name before cloning.

## Test

Only the change: the tests above with a stand-in `porelo` helper and a local remote, and `porelo_host`'s own tests. The VM test covers only the bring's bundle step of a private repository on one VM.
