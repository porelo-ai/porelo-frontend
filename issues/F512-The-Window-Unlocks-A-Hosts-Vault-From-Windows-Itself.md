# F512 — The Window Unlocks A Host's Vault From Windows Itself

```json
{
  "$schema": "issue-1.json",
  "id": "F512",
  "title": "The Window Unlocks A Host's Vault From Windows Itself",
  "state": "Review",
  "size": "M",
  "priority": "Medium",
  "rank": 85,
  "blockedBy": [],
  "covers": "On Windows the window opens a host's vault itself, over the card's own ssh config: the pin, the agent's key, the share from its signature, and Porelo's vault commands on the host."
}
```

Builds on Core's written rule for how a host vault's opening share is derived from a person's Ed25519 ssh key, with
its fixed test vector (key, host fingerprint, login, signed data, signature blob, share) that Core's own test pins.

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

- That the Windows OpenSSH agent's named pipe answers the agent protocol from Dart without an extra library: the pipe
  is opened with `CreateFileW` and read and written with `ReadFile` and `WriteFile` through `dart:ffi`, one exchange per
  request in an isolate of its own; it has run only against stand-ins, never on Windows.

## Decided

- The person's yes is asked only after the host answered `other-key`, and the share is not held while they decide: it
  is derived again after the yes, for the clear's following `init`.
- `ssh-keyscan` asks for the Ed25519 key alone, at the card's address and port; a host offering no key with the pinned
  fingerprint is asked nothing, and the agent is not asked to sign.
- The agent unreachable reads as waiting for the key, as a key the agent does not hold does; a refused or unverifiable
  signature is a refusal with its own words.
- The host steps are ssh commands of their own, each bounded by the unlocker's deadline and ended when the card is
  disconnected; they carry no connection, so they take no place in the carrier budget.

## Findings

- The window has no place yet for the person's yes to clear a vault another key opened: `WindowsHostUnlocker` takes it
  as `askToClear`, and without it such a vault is kept and the card says that resetting needs the person's yes. A
  command on the card that asks and then runs the unlock again with that yes is a follow-up of size S.
- Nothing in the window starts a rekey yet; `WindowsHostUnlocker.rekey` is there for the change of a card's key.
- The exchange with the agent over its pipe has no bound: an agent that takes the pipe and never answers holds the
  unlock, and a cancel waits on it. A bounded read (overlapped I/O with a timeout, or `CancelSynchronousIo`) is a
  follow-up of size S.
- A cancel that arrives while a host step's ssh is still starting leaves that ssh running without its input; nothing
  was written to it. It is stopped in the same follow-up.
- A rekey is not serialized with an unlock of the same card, and a cancel does not wait for it.
- Temporary copies of the signature and the share in Dart's heap are not all cleared; Dart gives no way to clear every
  copy.
- The pipe is opened without a security quality of service; OpenSSH's client asks for identification only. A process
  holding the pipe's name learns nothing it can use, since the signature is verified against the key.

## How it was built

- `lib/src/app/windows_vault_unlock.dart`: the agent protocol (`REQUEST_IDENTITIES`, `SIGN_REQUEST`) over the named
  pipe, the SSHSIG signed data and blob, the signature verified with Ed25519 before HKDF-SHA256 gives the share, and
  `WindowsHostUnlocker` with the pin, the key, unlock, init, clear only after the yes, and rekey. On Windows the
  tunnels take it in place of Core's unlocker; Linux keeps Core's.
- `test/app/windows_vault_unlock_test.dart`, 15 tests over a stand-in agent that speaks the agent protocol with the
  vector's key and stand-ins of ssh and ssh-keyscan: Core's vector byte for byte (public blob, signed data, SSHSIG
  blob, share); a forged signature derives nothing; a host with another key is asked nothing; each answer of
  `vault unlock` (0, 65, 66, 77, 70 and an exit that disagrees with its line) gives its own state and words; no clear
  without the yes, clear then init after it; the share only on standard input, exactly 32 bytes, in no argument and
  no printed line; a rekey sends the old share, then the new; no key in the agent waits for it; Windows takes this
  unlocker, Linux Core's.
- Red seen by breaking the code on purpose and restoring it from a copy: the HKDF info, the pin check, the rekey's
  order, the choice of unlocker on Windows, the signature's verification, the yes, and the share added as an
  argument each turned their own test red. The tests of the tunnels and the Windows card, which take the unlocker, ran
  green beside them (292 tests).

## Estimate

`F512 size=M est=61 basis=median M 61 (24 records)`
