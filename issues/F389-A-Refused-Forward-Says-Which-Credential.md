# F389 — A Refused Forward Says Which Credential

**Status:** Review.
**Size:** M - a led path in the window on daemon calls not there yet: words, a list of keys, a try, a keep.

**What must be true.** A push refused for its key leads the person through it in the window, with no need to read git's raw line, which does not appear.

1. It says in plain words what happened and which key was used, by fingerprint and what the forge calls it, such as a deploy key; or that no credential is declared for the address.
2. It lists the person's keys, from the ssh-agent, so also from an open KeePassXC, and from files, reading no secret. Beside them: a key not listed? Open KeePassXC, unlock it, refresh.
3. *Try* tests one key alone, by a `git push --dry-run` with only that key, and writes nothing.
4. One click keeps that key for that address and forwards again.
5. For what only a terminal can do, the window opens a terminal with the whole command ready, and the person starts it.

The rule beyond this case: every credential's failure says what happened and what to do now, with a control for it.

## Why

A real test showed `'git --git-dir ... push --end-of-options git@github.com:<organization>/<repository>.git ...' failed with exit code 128: ERROR: Permission to <organization>/<repository>.git denied to deploy key`. No credential was declared for that address, so ssh chose by itself and offered a key the forge knows as a deploy key without that right. A person who reads only that error has nothing to go on; Porelo leads them through it.

## Plan

The contract, agreed with Agent Core: `Approve` refuses with `PushRefused(outcome, address, source, id, fingerprint, forge, command, message)`, `outcome` one of `NO_CREDENTIAL`, `KEY_UNAVAILABLE`, `PUSH_REFUSED`, `forge` `DEPLOY_KEY` or `UNKNOWN`, no raw remote output; `SshKeys` answers agent keys too (`found: AGENT`, `publicKey`); `CredentialTryPush(project, repository, refspec, source, id)` answers `accepted`, `fingerprint`, `message` and writes nothing; `CredentialDeclare` with `source: AGENT` takes one fingerprint as `id`.

- `lib/src/client/`: `PushRefused` read from the refusal's parameters, field by field; `SshKey.publicKey`; `credentialTryPush` and its answer `TriedPush`; `FleetBackend` passes both through. A daemon without `CredentialTryPush` is `FeatureNotSupported` for Try alone.
- `lib/src/app/gate.dart`: `approve` keeps a `PushRefused` with the branch and commit it was for, instead of a line of words; `keys` reads `SshKeys` (and again on refresh); `tryKey` asks `CredentialTryPush` with `refs/porelo/incoming/<name>:refs/heads/<branch>`; `keepKey` declares the key for the refusal's address (`SSH_KEY`, purpose `git`, `AGENT` by fingerprint or `FILE` by path) and only then calls `Approve` again with the same branch and commit.
- `lib/src/ui/gate_view.dart`: the refusal in the review, worded here from its parts (what happened, the address, the key by fingerprint, the forge's word); the keys with where each was found, *Try* and *Keep and forward again* on each, the KeePassXC line beside *Refresh*; *Open a terminal* with the refusal's `command`.
- The terminal is the in-window terminal on that machine, the same on every desktop, never a desktop terminal of its own. A dialog shows the command first, and the terminal opens and runs it only on *Start it*; the keys are read again after it.
- `doc/Backend-API.md` names the refusal and the calls.
- Red first: scenarios in `work_handover.feature` that *Keep* declares exactly the refusal's address with the chosen key and forwards again with the reviewed commit, that *Try* asks with the refused branch and keeps nothing, and that a refusal shows no `git` line; `test/client/push_refused_test.dart` that `PushRefused` and `TriedPush` read every field and an unknown outcome renders. The mock daemon is not extended: the real test is against a daemon with these calls.

## Acceptance

- A refused push with no credential for its address says so; one with a credential says which key, by fingerprint and the forge's word for it.
- The person's keys are listed from the agent and from files, and no secret is read or shown; a key added by unlocking KeePassXC appears on refresh.
- *Try* on a key writes nothing upstream, and says what the forge answered.
- Keeping a key forwards again with that key alone.
- What only a terminal can do opens one with the command ready, and does not start it.
- No git command line reaches the window for this refusal.

## Decided while building

- What only a terminal can do runs in the in-window terminal on that machine, never a desktop terminal.
- From the reading: a key listed twice is not deduplicated, since two rows with one key neither threw on building nor on building again; a refusal with an empty address or key is not guarded, since the daemon always names the address it refused and lists every key by fingerprint or path.

## To be checked
