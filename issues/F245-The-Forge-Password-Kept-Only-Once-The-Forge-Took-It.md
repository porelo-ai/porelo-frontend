# F245 — The Forge Password Kept Only Once The Forge Took It

**Status:** Accepted.
**Size:** S - the lasting forge password checked against the forge's rules when typed, kept in the secrets file only after the forge accepted it, and a refusal said in the forge's words.

**What must be true.** A lasting forge password that is typed is checked against the forge's rules before it is sent: at least 8 characters, Forgejo's default `MIN_PASSWORD_LENGTH`, which the host does not change. It is kept as `shared/forge-password` in the secrets file only after the host's helper says the forge set it. A password the forge refuses is not kept, the next try asks again, and the person reads why in plain words.

## Why

Operator's walk 23, the first bring on VM A (2026-10-30): about 6 characters were chosen. `SecretsFile.forgePasswordLine` (`packages/porelo_host/lib/src/secrets_file.dart`) kept them before sending, and every later try sent them again without asking. Forgejo on the prepared host answered `PATCH /api/v1/admin/users/<account>` with 400, twice, and the terminal said only "the forge answered 400 setting <account>'s password" (`porelo-host-forge-password` in porelo-host).

## Plan

- The feed asks for the password twice (typed blind), refuses fewer than 8 characters or a mismatch before sending, and keeps nothing yet.
- The new password is sent as today, on standard input to `sudo -n /usr/local/sbin/porelo-host-forge-password`. Only that helper's success adds it to the secrets file. The add happens in the same terminal, with the master password already typed, so nothing is asked twice.
- A password already kept is sent as today. If the forge refuses a kept one, the feed offers to replace it: asked once, the old entry removed only after the new one was accepted.
- The helper's refusal is shown in its own words. Agent Machines is asked to have `porelo-host-forge-password` return Forgejo's message (for example "password is too short") with the status, never the password.
- **Red first:** a test that a 6-character password is refused before anything is sent or kept; a test with a stand-in helper answering a refusal, where `shared/forge-password` is not added; and one where it answers success, where it is.

## Test

Only the change: the tests above with stand-in `keepassxc-cli` and helper, and the feed's own tests. The VM test covers only the bring's forge-password step on one VM against the walk's host.

## To be checked

- The forge-password step has not been exercised on a VM in this worktree.

## Deferred

- Four existing feed tests create temporary folders directly in the real home directory, which is read-only in
  this worktree's execution environment; changing their unrelated setup is outside this task.
- The keepassxc-cli stand-in does not yet distinguish adding an entry from editing an existing entry.
- Plain-words forge refusals wait for the host helper to include Forgejo's safe refusal message with its status; the helper currently returns only the status.
