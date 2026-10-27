# F196 — The Public Ssh Key Follows Its Private One

**Status:** Backlog.
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
