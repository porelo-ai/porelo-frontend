# F196 — The Public Ssh Key Follows Its Private One

**Status:** Implementing.
**Size:** S - the step *Your ssh keys* in the host dialog and its tests, on [F195](README.md#f195)'s check and icons.

**What must be true.** On *Your ssh keys*, choosing or typing the private key fills the public key
field with the same name and `.pub` whenever that file exists, also over a value kept from an
earlier run. A public key that does not belong to the chosen private key is refused at the field as
soon as either field changes, with the same icons as [F195](README.md#f195): a check mark when the
two belong together, an error icon with the reason when not.

## Why

Today the public field follows only when it is empty or still holds the previous private key's
`.pub`, and only when the private key is chosen with **Choose…**, not typed. In a re-test the person
chose a new private key and the public field kept the earlier run's key, so they had to find the
`.pub` by hand, and nothing said the two did not belong together.

## Plan

- `lib/src/ui/host_dialog.dart`: a listener on the private key fills the public key with
  `<private>.pub` whenever that file exists, also over a kept value, whether the private key was
  chosen or typed; the old rule, which followed only after **Choose…** and only from an empty or
  matching field, goes.
- Whether the two belong together is asked of `ssh-keygen -l -f <private>`, in a process of its own:
  it reads the private key's fingerprint without its passphrase, so the private key never enters the
  interface. Measured: a key without a passphrase, one with a passphrase and an unencrypted PEM key
  all answer, also without a `.pub` beside them. Where it cannot say (an encrypted PEM key, a key type
  `HostFiles.signingFingerprint` does not read, no `ssh-keygen`), nothing is refused.
- The answer stands in the public key field with [F195](README.md#f195)'s marks, and a refused pair
  holds **Next**. A kept pair is checked when the dialog opens; each check is numbered, and an answer
  about a pair the fields no longer hold is dropped.
- Red first: `test/ui/host_bundle_test.dart`, "the public ssh key follows its private one and a key
  of another pair is refused".

## Acceptance

- Choosing or typing a private key fills its `.pub` over the earlier public key, and the pair shows
  the check mark.
- A public key of another pair is refused at the field with both fingerprints, and **Next** stays
  held.
- Seen to fail: the test red before the change, and red again with the public key following only an
  empty field, with the check mark shown for another pair, and with **Next** not held.

