# F391 — The Dead Signer Path Removed

```json
{
  "$schema": "issue-1.json",
  "id": "F391",
  "title": "The Dead Signer Path Removed",
  "state": "Review",
  "size": "S",
  "priority": "Medium",
  "rank": 30,
  "blockedBy": [],
  "covers": "Nothing asks a daemon `ProjectSigners` or `CommitVerdict`, which none serves; a commit made here is still checked against the person's own key."
}
```

**Why this size.** one policy interface, its daemon implementation, two client calls and their models, none with a caller left.

**What must be true.** The window calls no daemon method the served contract does not hold for who signs: nothing asks `ProjectSigners` or `CommitVerdict`, and the live check of the served contract is green on them.

## Why

Signing an access commit went with the checkout that made one. What asked who signs is left without a caller: `SignerPolicy` and `DaemonSignerPolicy`, `CommitSigning`'s policy with `signersFor`, `signingOptions` and `checkArrived`, and the backend's and client's `projectSigners` and `commitVerdict`. No daemon serves either method, so the live check of the served contract is red on both names. Who signs is the organization's to say, and Porelo's to check; no Core side is needed.

## Plan

- Delete `lib/src/app/signer_policy.dart` and `test/support/fake_signer_policy.dart`.
- `lib/src/app/commit_signing.dart`: only `checkOwn` stays, the check that a commit made here is signed with the person's own key, which `project_workspace.dart` runs before a push.
- `lib/src/client/porelo_client.dart`, `lib/src/app/fleet_backend.dart`: `projectSigners` and `commitVerdict` go.
- `lib/src/client/models.dart`: `CommitVerdict` and `ProjectSigners` go; what `checkOwn` takes is `OwnSigner`, the person's key and its allowed-signers line, beside it in `commit_signing.dart`, as no daemon answers it.

## Acceptance

- `test/client/live_daemon_test.dart` "declares every method this client calls" is green against a real daemon.
- A commit made here is still checked to be signed with the person's key before it is pushed.

## Decided while building

- Checked against the VM's daemon 0.5.1~snapshot.4642: the live check is green with the client as it is now. Without the change the test does not compile, as it removes the types the old calls answered, so the red is seen only in the build.
- From the reading: what the removal left is gone too: the signer's login no code read, the wire model with no wire, the check's Git environment and its refusal still worded for a project's signers, and the changelog's line on signed access commits.

## To be checked
