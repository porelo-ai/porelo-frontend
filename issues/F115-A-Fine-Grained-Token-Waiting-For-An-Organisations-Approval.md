# F115 — A Fine-Grained Token Waiting For An Organisation's Approval

**Status:** Analyzed; blocked by the test organisation at GitHub that the operator sets up (the one
[F59](README.md#f59) needs), which must require approval of fine-grained tokens.
**Size:** S - one more case in the forge's refusals and its scenario, after one measurement.

**What must be true.** A fine-grained GitHub token whose access to an organisation's repositories
waits for that organisation's approval is said as waiting, with where an owner approves it, not as
refused or as lacking a right.

## Why

An organisation may require its owners to approve a fine-grained token before it reaches the
organisation's repositories. Until then GitHub refuses what the token asks, and the interface would
name a missing right that the token in fact has. The refusals the interface explains today name the
right a token lacks (*Contents*, *Administration*) and deploy keys switched off by the
organisation's setting, but not this one.

## Plan

- **Measured first:** at the test organisation, with "require approval" for fine-grained tokens on,
  a token asking for one of its repositories before an owner approved it: GitHub's status and words
  for the repository itself, its keys and a push, kept as fixtures in `test/app/forge_test.dart`.
- **`GitHubForge._why`** (`lib/src/app/forge.dart`): that answer said as "This token waits for
  <organisation>'s approval: an owner approves it under the organisation's Settings → Personal
  access tokens → Pending requests." with GitHub's own words in brackets, as the other refusals;
  ahead of the missing-right cases, so a pending token is never told to add a right it has.
- **Where it shows:** wherever a token's refusal shows today (the forge page's `repository-says`,
  the binding's `binding-problem`, `default-problem`), with nothing new to place.
- **Red first:** `forge_test.dart` with the measured answer, which today is said as a missing right
  or GitHub's words alone; then a scenario in `project_from_repository.feature`.

## Acceptance

- **A pending token is said as waiting for the organisation's approval,** with where an owner gives
  it. Seen to fail: the test with GitHub's measured answer.
- **Measured against GitHub:** a token made and left pending at the test organisation, its repository
  chosen in the forge page. Seen to fail: the walk's step at GitHub, before and after the approval.

## To be checked

- **GitHub's answer for a pending token,** status and message, for a repository read, its keys and a
  push. (Agent Frontend's)
