# F277 — Commits Signed With The Person's Key

**Status:** Backlog. Estimated and Backlog (operator, 2026-10-30, sprint 6m).
**Size:** M - replace access checkout trust, connect Core's signer policy, and cover existing commit and merge paths as well as registry operations.

**What must be true.** Every commit the interface makes (access file, registry) is signed with the person's key through the SSH agent (`gpg.format ssh`, namespace `git`), never with a key file the interface holds. Verification uses the allowed-signers Core answers for the project (admins' keys, the backup key, admitted persons' keys as `cert-authority` limited to tasks' namespaces and principals, so the task keys they certified are accepted, old keys with `valid-before`), not a list the interface builds.

## Why

One-click joining from signed state (operator, 2026-10-30), building blocks 1 and 4.

## Plan

- **Red first:** extend `test/app/access_checkout_git_test.dart` with an isolated SSH agent and fake Core signer policy. Give Git a conflicting signing configuration and an untrusted key. Publication must use the Core-selected person key through the agent or fail before push. Keep the bare remote unchanged on refusal. This guards against publishing unauthorized access changes.
- Extend `PoreloClient` in `lib/src/client/porelo_client.dart`, models in `lib/src/client/models.dart`, and `FleetBackend`/`PoreloBackend` in `lib/src/app/fleet_backend.dart` for Core's agreed public signer and allowed-signers behavior. The contract is not implemented yet; use a fake in tests. Core owns the authorized key, allowed-signers entries, revocation policy, and historical acceptance verdict. Preserve principals, namespace limits, `cert-authority`, and `valid-before` exactly. Never derive trust from forge keys in the interface.
- Change `AccessCheckout` in `lib/src/app/access_checkout.dart`. Remove the caller-selected public key as the whole trust set, the generated single-key allowed-signers line, fingerprint equality, and reliance on arbitrary Git signing configuration. Supply Core's public person key as `key::` with `gpg.format=ssh` and signing enabled per commit. Verify before checkout advancement and before push using Core's policy. Keep private worktrees, refused-change preservation, and publication-before-bundle ordering.
- Reuse agent signing in `ProjectWorkspace.commitAndPush` and `mergeAndPush` in `lib/src/app/project_workspace.dart`. Require Core's selected person key and verify before pushing. Replace independent key choice and forge-derived signer lists in `lib/src/ui/binding_view.dart` (`_BindingDialogState`) and `lib/src/app/machine_binding.dart` (`MachineBinding`) where they supply signing policy. Update `lib/src/ui/project_developers_dialog.dart` and `lib/src/app/project_bring.dart` where they construct `AccessCheckout`, removing the separate project signing-key requirement for this path.
- Registry writes introduced by [F268](README.md#f268) and [F280](README.md#f280) remain Core operations. Require a confirmed signed revision before reporting publication; do not introduce another unsigned Dart checkout. Backup recovery is a restricted Core operation, not an ordinary selectable signer.
- Extend `test/app/project_workspace_test.dart` for commit and merge publication with the agent as the only signing source. Isolate Git configuration. Distinguish reading accepted history from accepting a new push: consume Core's recorded verdict rather than deciding arrival time from the commit timestamp.

## Acceptance

- Real Git with a test-owned SSH agent produces verifiable SSH signatures in namespace `git` for access commits, workspace commits, and merges. Removing the agent key or supplying conflicting Git configuration cannot publish an unsigned or differently signed commit.
- Fake Core policy admits multiple current signers and a valid task certificate with the required principal and namespace. Unknown signers, wrong namespaces or principals, revoked keys, and expired task certificates fail before advancement or push. No frontend-generated entry broadens trust.
- Historical reads use Core's prior acceptance verdict. A newly arriving commit with a retired key fails even with a backdated timestamp. Missing Core policy or an unsupported method fails closed.
- Registry operations report the signed revision Core confirms. Inspect process arguments and checkout files: only public keys and public verification policy leave Core; no private key file is used for ordinary commits and no secret is recorded.

## To be checked

- Confirm Core's signer-policy reply and how it separates current acceptance from historical verdicts, including KRL handling. The design agrees behavior, not a wire schema.
- Confirm allowed-signers syntax and supported Git/OpenSSH versions for task certificate principals and namespaces. Measure the failure cases with real Git during implementation.
- Check all callers of the changed checkout and workspace methods, including project bring and machine binding, for local signer fallbacks. Confirm Core's registry publication reply exposes the signed revision.

## Test

Only the change: the checkout tests. No VM run.

## Estimate

`F277 size=M est=60 basis=median M 61 (24 records)`
