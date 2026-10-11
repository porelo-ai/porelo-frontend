# F115 — A Fine-Grained Token Waiting For An Organisation's Approval

**Status:** Idea.

**What must be true.** A fine-grained GitHub token whose access to an organisation's repositories
waits for that organisation's approval is said as waiting, with where an owner approves it, not as
refused or as lacking a right.

## Why

An organisation may require its owners to approve a fine-grained token before it reaches the
organisation's repositories. Until then GitHub refuses what the token asks, and the interface would
name a missing right that the token in fact has. The refusals the interface explains today name the
right a token lacks (*Contents*, *Administration*) and deploy keys switched off by the
organisation's setting, but not this one.

## The shape

- GitHub's answer for such a token, measured at an organisation that requires approval, first.
- Then the refusal said as waiting for the organisation's approval, with where in GitHub an owner
  approves it, wherever a token lacking a right is said today.
- Red first: a scenario with GitHub's measured answer, which today is said as a missing right.
