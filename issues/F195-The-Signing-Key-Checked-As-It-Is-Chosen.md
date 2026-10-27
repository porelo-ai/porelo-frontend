# F195 — The Signing Key Checked As It Is Chosen

**Status:** Implementing.
**Size:** S - the host dialog's step *The drive* and its widget tests; no contract and no other module.

**What must be true.** On *The drive*, the public key for signing commits is checked against the
project's verified commit as soon as the field changes, chosen or typed, not only when the person
presses **Next**. The result stands at the field with a clear icon: a check mark when the key signed
the commit, an error icon with the refusal when it did not. A result never stays beside a value it
was not about: while a changed key is being checked, the old answer is gone.

## Why

In the re-test of the refusal of a key that did not sign the commit, the person chose the right key after a refusal, and the
refusal for the wrong key stayed under the field until the next **Next**, so it read as if the right
key had been refused too.

## Plan

- `lib/src/ui/host_dialog.dart`: a listener on the signing key field drops the refusal at once and,
  when the field reads as a public key and the drive and the verified source are there, runs the same
  check **Next** runs (`HostFiles.createBundle`, which clones the verified commit and checks its
  signer). The dialog runs it too when it opens on a kept or pinned key and when a folder is chosen.
- A check from the field holds neither the dialog nor the step; only **Next** does, and **Next**
  checks again unless the field's own check already passed for exactly this key. Each check is
  numbered, and an answer from an older check, or about a key the field no longer holds, is dropped.
- The answer stands in the field: an hourglass while it is checked, a check mark when the key signed
  the commit, an error icon with the refusal as the field's error text when it did not.
- Red first: `test/ui/host_bundle_test.dart`, "the signing key is checked as soon as it changes, and
  its answer goes with it".

## Acceptance

- A key that did not sign the commit is refused at the field, with its error icon and both
  fingerprints, before **Next**.
- Changing the key removes the refusal at once, also while what is typed is not yet a key.
- The key that signed shows the check mark; changing it again removes the check mark at once.
- Seen to fail: the test red before the change, and red again with the refusal kept on a change or
  the check mark shown for another key.
