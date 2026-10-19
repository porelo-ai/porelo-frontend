# F140 — The Host's Files Written Into The Person's Drive

**Status:** Accepted, to be analysed after the issues in hand.

**What must be true.** Where the interface runs, it writes the files the host reads from the
person's drive - the WireGuard key today - straight into that drive's folder on the desktop, which
the desktop already syncs. The person copies nothing by hand. It holds for every kind of drive:
Tresorit's, and OneDrive's ([F139](README.md#f139)).

## To be checked

- **Finding the drive's folder** on Linux and on Windows: the Tresorit app's folder; for OneDrive the
  OneDrive folder on Windows, or GNOME Online Accounts' Microsoft 365 through gvfs on Linux. How each
  is found without guessing, and what the interface says when none is found: the file to copy and
  where, as today.
- **Writing there:** the folder of the project's tresor or library, the file's name the host reads,
  and nothing written over that the person put there.
- **By the drive's kind:** a drive encrypted end to end (Tresorit, and others like it) takes the key
  as it is. One that is not (OneDrive) gets it encrypted, and the host decrypts it with a secret
  that reaches it only at the stop, on standard input as every answer does, never through the drive.
  Which encryption, where that secret is kept on the desktop, and that it is never written to the
  drive.
- **What the interface says of each kind:** that a drive not encrypted end to end holds the key
  encrypted, and who could read what lies there otherwise.
- **The machine file** `porelo-host/machine.yml` in the project's tresor, beside `wireguard.key`,
  which the host reads with `porelo project inventory --machine-file` (porelo-host's HO02). Its
  `keys` paths are relative to it, and the keys it names lie beside it. The interface writes it
  from what the person gave there, and never a key that is not the drive's to hold.
- **The host's side** is porelo-host's: reading the encrypted key and decrypting it with what the
  stop gave, and reading the machine file.
