# F195 — The Signing Key Checked As It Is Chosen

**Status:** Idea.

**What must be true.** On *The drive*, the public key for signing commits is checked against the
project's verified commit as soon as the field changes, chosen or typed, not only when the person
presses **Next**. The result stands at the field with a clear icon: a check mark when the key signed
the commit, an error icon with the refusal when it did not. A result never stays beside a value it
was not about: while a changed key is being checked, the old answer is gone.

## Why

In the re-test of [F194](README.md#f194), the person chose the right key after a refusal, and the
refusal for the wrong key stayed under the field until the next **Next**, so it read as if the right
key had been refused too.
