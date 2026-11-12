# F512 — The Window Unlocks A Host's Vault From Windows Itself

```json
{
  "$schema": "issue-1.json",
  "id": "F512",
  "title": "The Window Unlocks A Host's Vault From Windows Itself",
  "state": "Backlog",
  "size": "M",
  "priority": "High",
  "rank": 85,
  "blockedBy": [],
  "covers": "On Windows the window opens a host's vault itself, over the card's own ssh config: the pin, the agent's key, the share from its signature, and Porelo's vault commands on the host."
}
```

Waits on Core writing down how a host vault's opening share is derived from a person's Ed25519 ssh key, with a fixed
test vector (key, host fingerprint, login, signed data, signature blob, share) that Core's own test pins.

**Why this size.** M: one module of the window that speaks the ssh agent protocol over a named pipe, derives the
share and runs the host's vault commands through the card's config, with its tests; one contract, Core's rule and
vector, which it pins.

**What must be true.** On Windows, a person who connects a host's card has its vault opened as on Linux, with the key
KeePassXC holds and no confirmation per use; a vault opened by another key is cleared only after the person's own yes.

## Why

Core's `porelo host unlock` does not run on Windows, so a card connected there
([F290](README.md#f290)) leaves its host's vault shut. The window does Core's steps itself, over the card's own
`ssh -F <card config>`, which pins the host key and names the card's key.

## Plan

`lib/src/app/windows_vault_unlock.dart` (new), a `HostUnlocker` the window takes on Windows in place of
`CoreHostUnlocker`:

1. **The pin.** `ssh-keyscan` of the card's address and port; its key's `SHA256:` fingerprint must equal the card's
   `--host-key` fingerprint, or nothing more is done.
2. **The key.** The card's Ed25519 key, asked of the Windows OpenSSH agent on its named pipe
   (`\\.\pipe\openssh-ssh-agent`) through the agent protocol: listed (`REQUEST_IDENTITIES`) and matched by its public
   blob; absent, the card waits for the key as now.
3. **The share.** The agent signs (`SIGN_REQUEST`) the SSHSIG over `host=<SHA256:fingerprint> account=<login>`, with
   namespace `porelo-vault` and hash `sha512`; the signature is verified against the key before it is used. The share is
   HKDF-SHA256 with the whole binary SSHSIG blob as input key material, an empty salt, info `porelo-vault-share-v1`,
   32 bytes. It is never logged, never in an argument, and held no longer than the call.
4. **Unlock.** `porelo vault unlock --share-stdin --json` on the host, its standard input exactly the 32 bytes. Exit 0
   with `{"vault":"open"}` is open; 66 absent; 77 opened by another key; 65 not a host vault.
5. **Absent:** `porelo vault init --share-stdin --json` with the same 32 bytes.
6. **Another key:** only after the person's yes, `porelo vault clear --yes --force --json`, then init as in 5.
7. **Rekey:** `porelo vault rekey --share-stdin --json` with 64 bytes on standard input, the old share then the new.

Each runs as `ssh -F <card config> -T -- <card> <command>` in the login shell, under the window's carrier budget.

**Red first** (unit tests over fakes of the pipe, the agent and ssh):
- the derivation pins Core's written test vector: key, public blob, fingerprint, login, signed data, SSHSIG blob and
  share hex;
- each exit code (0, 65, 66, 77, and any other) gives its own state and words;
- no `vault clear` without the person's yes;
- the share appears in no log line and in no process argument, only on standard input.

## Acceptance

- On Windows, with the stand-ins: a host vault absent is made, one closed is opened, one opened by another key is left
  alone until the person says yes; a host whose scanned key does not match the card's pin is not asked anything.
- The derived share equals Core's vector byte for byte.
- In the operator's Windows test: Connect against a real host opens its vault with KeePassXC's database open and no
  confirmation asked.

## To be checked

- That the Windows OpenSSH agent's named pipe answers the agent protocol from Dart without an extra library.

## Estimate

`F512 size=M est=61 basis=median M 61 (24 records)`
