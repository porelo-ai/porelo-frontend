# F567 — Revoking The Last Device Says What It Costs

```json
{
  "$schema": "issue-1.json",
  "id": "F567",
  "title": "Revoking The Last Device Says What It Costs",
  "state": "Review",
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

## Built

- **Cause:** the confirmation on the Vault page said the same sentence for every device, the last one included.
- `revokeCost` in `vault_devices.dart` judges a revocation from the machine's own list of ways in (`Keyslots`): a
  device is the last when no other device is listed. Then the confirmation says that afterwards only the passphrase
  opens the vault, typed at the machine with `porelo vault unlock`, that it stays shut after every restart until
  someone types it there, and that without it the entries are lost for good.
- **Whether a passphrase is set** is offered by porelo: `Keyslots` lists the passphrase as the slot with `recovery`
  true, and a vault made from a share alone has none. **Whether anyone still knows it** nothing can say, so the dialog
  says plainly that the window cannot tell. porelo needs nothing new for this issue.
- On a machine other than this computer the last device is not revoked from the window: the dialog says what it
  would cost and how to do it at the machine (`porelo vault revoke <id>`), with *Close* and no *Revoke*. The only way
  into a vault with no passphrase is not revoked from the window at all, as porelo itself keeps it (`LAST_WAY_IN`).
- Tests, each seen red with a deliberate break restored from a copy: `test/app/vault_devices_test.dart` *what revoking
  a device costs, said before it is done* (four tests); `test/ui/vault_revoke_test.dart` *a machine elsewhere's last
  device is not revoked from here, and the dialog says how at the machine* and *a machine elsewhere's device that is
  not the last is revoked from here*; `test/features/enrolled_devices.feature` *revoking the last device says before it
  is done what only the passphrase opens afterwards* and *revoking a device that is not the last says nothing of the
  passphrase*. With the old sentence for every device, the three last-device unit tests, the window-elsewhere test and
  the last-device scenario went red; with every device counted the last, the not-the-last unit test, widget test and
  scenario went red.
