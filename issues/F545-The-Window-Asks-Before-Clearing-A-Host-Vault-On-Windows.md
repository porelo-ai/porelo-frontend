# F545 — The Window Asks Before Clearing A Host Vault On Windows

```json
{
  "$schema": "issue-1.json",
  "id": "F545",
  "title": "The Window Asks Before Clearing A Host Vault On Windows",
  "state": "Backlog",
  "size": "S",
  "priority": "Medium",
  "rank": 112,
  "blockedBy": [],
  "covers": "On Windows, a host vault another key opened is cleared and made anew with the person's key only after their yes on the card, asked by the window."
}
```

**Why this size.** S: one command on the card and the yes it passes to the window's own unlocker, with their tests; no
contract changes.

**What must be true.** On Windows, a person whose host vault was opened by another key can say yes on the card to
clearing it and making it anew with their own key; without that yes the vault is kept, as now.

## Plan

- `lib/src/app/commands.dart`: a command on a card whose vault answered `other-key`, worded as the second decision it
  is, saying that every sign-in must be made again.
- `lib/src/app/tunnel.dart`: on the person's yes, the unlock runs again with `WindowsHostUnlocker.askToClear` answering
  yes for that one run; any other unlock keeps the vault.
- Red first: a widget test over a stand-in unlocker in which no clear is run until the command is chosen and confirmed,
  and one run after it.

## Acceptance

- Without the yes, no `vault clear` reaches the host; after it, the host's vault is cleared and made with the person's
  key, and the card reads open.

## Estimate

`F545 size=S est=15 basis=median S 15 (11 records)`
