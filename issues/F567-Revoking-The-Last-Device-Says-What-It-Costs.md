# F567 — Revoking The Last Device Says What It Costs

```json
{
  "$schema": "issue-1.json",
  "id": "F567",
  "title": "Revoking The Last Device Says What It Costs",
  "state": "Backlog",
  "size": "S",
  "priority": "Highest",
  "rank": 13,
  "blockedBy": [],
  "covers": "Story ST361: revoking the last device of a machine's vault says that afterwards only the passphrase at the machine opens it, that it stays shut after every restart until typed there, and that without the passphrase its entries are lost for good."
}
```

**Why this size.** One dialog on the Vault page, and the count of enrolled devices the page already lists. Whether a passphrase is known is asked of porelo.

**What must be true.** Nobody shuts a vault for good from the window without being told so in plain words first.

## Plan

Found live: on a machine's Vault page the only device (*ssh-agent*, enrolled) has the revoke button, and the
confirmation says only that the device will no longer open the vault.

- When the device is the last one enrolled, the confirmation says three things. Afterwards only the passphrase opens
  the vault (`porelo vault unlock` at the machine). The vault stays shut after every restart until someone types the
  passphrase there. Without the passphrase, the entries are lost for good.
- Whether a passphrase is set or known is asked of porelo. If porelo cannot say, the dialog says plainly that the
  window cannot tell, and Agent Core is asked to report it.
- For a remote machine, the window refuses to revoke the last device and says how to do it at the machine instead.

## Acceptance

- A guard for the last device (the words, and the refusal on a remote machine) and one for a device that is not the last, each red first. The Vault page tests green.
