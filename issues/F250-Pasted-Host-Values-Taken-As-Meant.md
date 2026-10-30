# F250 — Pasted Host Values Taken As Meant

**Status:** Accepted.
**Size:** XS - pasted public host values with extra blanks inside a key taken as meant, and a refusal naming the field that is wrong.

**What must be true.** The public host values pasted into a bring or join are read as meant when a chat or a mail added blanks: inside `ssh_host_key` and `wireguard_public_key`, runs of blanks between fields count as one, and leading and trailing blanks go. When a value is still wrong, the refusal names that field and what it should look like, not only "Paste the complete public host values".

## Why

Operator's walk 23 on VM A (2026-10-30): the JSON copied from a chat held two blanks after `ssh-ed25519` in `ssh_host_key`. The field said only "Paste the complete public host values", which did not say which value was wrong or why.

## Plan

- `PreparedHost.read` (`packages/porelo_host`), which the bring and join dialogs call, normalises blanks inside the two key fields before checking them. The digests (`ca_sha256`), the address and the names are taken as given.
- The bring dialog (`lib/src/ui/project_bring_dialog.dart`, `_host`) stops replacing the reader's refusal with "Paste the complete public host values…" and shows it; each check names its field: for example "ssh_host_key must be one line, ssh-ed25519 and its base64, with no comment".
- **Red first:** a test that `ssh-ed25519  AAAA…` with two blanks is accepted as the one-blank line; a test that a wrong `ca_sha256` is refused naming `ca_sha256`.

## Test

Only the change: the tests above and the reader's own tests. No VM run.

## Deferred

- Other dialogs that might hide PreparedHost.read's field-named refusal need a separate review.
