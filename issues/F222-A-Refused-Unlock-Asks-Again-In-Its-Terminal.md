# F222 — A Refused Unlock Asks Again In Its Terminal

**Status:** Implementing; built, not yet published.
**Size:** XS - the unlock terminal asks again after a refused password, up to three times, and its test.

**What must be true.** A wrong password in the vault's unlock terminal (the master password where
[F221](README.md#f221) applies, the vault passphrase elsewhere) is asked again in
the same terminal, up to three times, before the terminal ends; it does not end the session at the first refusal with
only Done left.

## Why

Seen in an operator's round: one wrong entry at *Vault passphrase:* ended the terminal with "that passphrase does
not open …/vault.bin - nothing was cached", exit 70, and the dialog offered only Done; trying again meant starting
Unlock the vault anew from Needs you.

## Plan

- The unlock line runs its command in a loop in the terminal's shell: on the refusal's own exit it says the password
  was not taken and asks again, at most three times; any other end ends it as today.
- **Red first:** a stand-in that refuses once and then opens leaves the terminal at exit 0 after the second entry.

## Acceptance

- A mistyped password can be typed again in the same terminal.
- After three refusals the terminal ends as today, saying so.
