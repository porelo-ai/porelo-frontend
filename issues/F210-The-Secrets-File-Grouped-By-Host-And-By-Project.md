# F210 — The Secrets File Grouped By Host And By Project

**Status:** Review; blocked by nothing.
**Size:** S - the entry names in one class, a one-time move, and their tests against the real `keepassxc-cli`.

**What must be true.** The secrets file keeps a host's entries under `hosts/<host>/` (its WireGuard key, its CA key and certificate) and a project's under `projects/<project>/` (its vault passphrase, its keys' files); entries kept by an earlier version are moved there once, in the person's own terminal, and nothing is lost.

## Why

Today every entry is under `hosts/<project>/` ([F198](README.md#f198)), since one host carried one project. Now a host carries several projects, and a project's secrets are its admin's, in their own account.

## Plan

- **The names:** `SecretsFile.hostKey`, `vaultPassphrase` and the keys' entries (`packages/porelo_host/lib/src/secrets_file.dart`) take a host or a project, each as it belongs; `forgeCaKey`/`forgeCa` move from `shared/` to `hosts/<host>/` ([F212](README.md#f212)).
- **The move:** a step in the stop's terminal script that, where an old entry exists and the new one does not, copies it with `keepassxc-cli` on a pipe and removes the old; nothing on a command line, as every entry is handled today.
- **Red first:** `packages/porelo_host/test/secrets_file_test.dart` against a fixture file with today's names: after one run, every value is under its new name and the old names are gone.

## Acceptance

- A file of today's shape opens with every entry under `hosts/<host>/` or `projects/<project>/`, values unchanged.
- A second run changes nothing.
- Seen to fail: the move test red before the names change.
