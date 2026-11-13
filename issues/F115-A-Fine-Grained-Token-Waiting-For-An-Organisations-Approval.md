# F115 — A Fine-Grained Token Waiting For An Organisation's Approval

```json
{
  "$schema": "issue-1.json",
  "id": "F115",
  "title": "A Fine-Grained Token Waiting For An Organisation's Approval",
  "state": "Analyzed",
  "size": "S",
  "priority": "Low",
  "rank": 3,
  "blockedBy": [],
  "covers": "A fine-grained token waiting for an organisation's approval said as waiting."
}
```

**Why this size.** one more case in the forge's refusals and its scenario, after one measurement.

**Blocked by** the test organization at GitHub that the operator sets up (the one [F59](README.md#f59) needs), which
must require approval of fine-grained tokens.

**What must be true.** A fine-grained GitHub token whose access to an organisation's repositories
waits for that organisation's approval is said as waiting, with where an owner approves it, not as
refused or as lacking a right.

## Why

An organisation may require its owners to approve a fine-grained token before it reaches the
organisation's repositories. Until then GitHub refuses what the token asks, and the interface would
name a missing right that the token in fact has. `GitHub._why` in `lib/src/app/forge.dart` has no
case for organization approval; its only permission-specific translation names *Contents: Read and
write* for contents and git requests. Administration checks in the same file name *Administration:
Read and write*.

## Plan

- **Measured first:** at the test organisation, with "require approval" for fine-grained tokens on,
  a token asking for one of its repositories before an owner approved it: GitHub's status and words
  for the repository itself, its keys and a push, kept as fixtures in `test/app/forge_test.dart`.
- **`GitHub._why`** (`lib/src/app/forge.dart`): that answer said as "This token waits for
  <organisation>'s approval: an owner approves it under the organisation's Settings → Personal
  access tokens → Pending requests." with GitHub's own words in brackets, as the other refusals;
  ahead of the missing-right cases, so a pending token is never told to add a right it has.
- **Where it shows:** wherever a token's refusal shows today (the forge page's `repository-says`,
  the project changes dialog's `binding-problem`, `default-problem`), with nothing new to place.
- **Red first:** `forge_test.dart` with the measured answer, which today is said as a missing right
  or GitHub's words alone; then a scenario in `test/features/forge_repositories.feature`.

## Acceptance

- **A pending token is said as waiting for the organisation's approval,** with where an owner gives
  it. Seen to fail: the test with GitHub's measured answer.
- **Measured against GitHub:** a token made and left pending at the test organisation, its repository
  chosen in the forge page. Seen to fail: the walk's step at GitHub, before and after the approval.

## To be checked

- **GitHub's answer for a pending token,** status and message, for a repository read, its keys and a
  push. (Agent Frontend's)
