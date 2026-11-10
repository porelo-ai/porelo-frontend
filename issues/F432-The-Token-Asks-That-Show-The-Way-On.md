# F432 — The Token Asks That Show The Way On

```json
{
  "$schema": "issue-1.json",
  "id": "F432",
  "title": "The Token Asks That Show The Way On",
  "state": "Review",
  "size": "S",
  "priority": "Medium",
  "rank": 19,
  "blockedBy": [],
  "covers": "A refusal with this computer's vault shut says so and opens it; the second token ask is one click."
}
```

**Why this size.** a refused organization change says when this computer's Porelo-Vault is shut, with the button that opens
it, and the second token ask of *Put it on a machine…* is one click.

**What must be true.** When an organization change is refused while this computer's Porelo-Vault is shut, the refusal
is followed by one line that says so and *Open this computer's Porelo-Vault*. When *Put it on a machine…* hears the
machine wait for a token and this computer's vault declares one, the same dialog offers *Give it the token from this
computer's Porelo-Vault* at once, one press.

## Why

The second move (2026-11-08), findings 4 and 8. The operator decided: the host keeps no token, the second ask becomes
one click (E6); 4b among the small fixes (E10). Core names the shut vault in its own refusal (4a).

## Plan

- `lib/src/ui/organization_page.dart` `OrganizationConfirmDialog`: on a refusal with `connections.vaultOpen` false,
  the line and the button that opens the vault.
- The *Put it on a machine…* dialog: where the answer waits for a token and the declared source is this computer's
  vault, the button that gives it straight from there, with `_giveTokenFrom`'s words after.
- Red first: a refusal with the vault shut shows the line and the button; with it open, neither; the waiting answer
  offers the one-click token.

## Acceptance

- A refused change with a shut vault names it and opens it in one press.
- The second token ask is one press where the vault declares the token.
