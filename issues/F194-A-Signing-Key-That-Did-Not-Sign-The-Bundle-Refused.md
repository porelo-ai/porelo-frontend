# F194 — A Signing Key That Did Not Sign The Bundle Refused

**Status:** Review; in the operator's re-test with `porelo-frontend 0.5.1~snapshot.192`.
**Size:** M - two modules (`HostFiles` and the host dialog's step "The drive") with their tests; no
contract change, since the machine's `Following` answer already carries the pinned fingerprints.

**What must be true.** Before a server is rented, the host dialog refuses a public signing key that did not
sign the commit it puts on the drive, showing the entered key's fingerprint beside the one that signed the
commit, until they match; and the field opens on a key the project's machine already pins, so the person
rarely has to choose.

## Why

The host checks the bundle's commit against `signed_by` in `machine.yml` only after the server is rented and
its setup has run for about 20 minutes, and then refuses with exit 65. The dialog fills the field with
`~/.ssh/id_ed25519.pub`, which is the person's ssh key, not necessarily the key the project's commits are
signed with, so a wrong key goes through every step unnoticed.

## Plan

- **The anchor stays the person's entry.** The field is never filled from the bundle's own signer: that
  reads the anchor out of the repository it verifies, and any signed bundle would pass. It comes from a file
  the person picks, or from a key they pinned earlier on the project's machine.
- **The check, in `packages/porelo_host/lib/src/host_files.dart`.** `createBundle` already clones the followed
  repository with git and holds the verified commit. It gains the chosen public key and, before `bundle
  create`, verifies the commit against it: an allowed-signers file with that one key in the scratch
  directory, then `git -c gpg.ssh.allowedSignersFile=<file> verify-commit <commit>`, with git's environment as
  today. Only an exit 0 with `%G?` `G` passes; a refusal reads the signer's fingerprint from `%GF` and throws
  `HostFilesRefused('The drive: the commit is signed by SHA256:…, not by the chosen key SHA256:…. No server
  was rented.')`; an unsigned commit says so. The chosen key's fingerprint comes from `signingFingerprint`,
  the same function `machine.yml` is written with, so the two cannot differ. Git alone, not
  `porelo project follow --dry-run --signed-by`: the computer running the dialog need not have porelo, and
  the host's own inventory check refuses exactly the same commits, so no `--json` on that command is needed.
- **Swapped fields.** When the refused key is the one in "Public key" (the server login), the refusal adds
  that the two key fields look swapped. Not a refusal of its own: both fields default to
  `~/.ssh/id_ed25519.pub`, and one key for both is valid when it signed the commit.
- **The dialog, in `lib/src/ui/host_dialog.dart`.** `_checkBundle` passes `_signingKey`, and the bundle is
  kept with the key it was checked against (`_bundleKey`, expanded), so a key changed after the drive passed,
  or corrected after a refusal, is checked again. The refusal shows in `_machineProblem` on "The drive",
  where the step stops; nothing is rented.
- **The prefill.** `Followed.signers` already holds the fingerprints the project's machine pins (`_readSource`
  reads it). With no key kept from an earlier run, the field opens on the first public key in `~/.ssh`, by
  name, that matches one of them, instead of `~/.ssh/id_ed25519.pub`; with no match, as today. The few small
  files there are read at once, as the dialog's other file checks are. The check above holds either way.
- **Red first.** In `packages/porelo_host/test/`, a repository with a commit signed by key A and
  `createBundle` given key B: today it answers a bundle; it must refuse, naming both fingerprints. Then in
  `test/ui/host_dialog_test.dart`, the same on "The drive" with no session started and the step not passed.

## Acceptance

- With a key that did not sign the commit, "The drive" stops and names both fingerprints; no host run
  starts and no `machine.yml` is written. With the right key, the step passes and `machine.yml`'s
  `signed_by` is the commit's signer.
- With the server login key in the signing field and a commit it did not sign, the refusal says the fields
  look swapped.
- Seen to fail: with the verification removed, the refusal test is red.
- With a machine pinning a key whose `.pub` lies in `~/.ssh`, the field opens on that file.

## To be checked

- That `git verify-commit` with an ssh allowed-signers file runs the same with Git for Windows (it needs
  `ssh-keygen`). Measured on Linux with git and OpenSSH: a commit signed by key A, checked against key B,
  exits 1 with "No principal matched", and `git log -1 --format='%G? %GF'` answers `U` and A's fingerprint.
