# F352 — A Rental State Kept Beyond One Computer

**Status:** Idea.

**What must be true.** OpenTofu's state of a rented host can be reached from more than the computer that rented it: in the organization's repository, or at the provider.

## Why

[F166](README.md#f166) keeps the state local, encrypted with a key from the person's vault. Another admin on another computer then has neither.

## To be checked

- Which of the two places, given that the state holds the host's private key.
