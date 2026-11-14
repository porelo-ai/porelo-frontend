# F552 — The Carried Collection Is Readable And Its Absence Said

```json
{
  "$schema": "issue-1.json",
  "id": "F552",
  "title": "The Carried Collection Is Readable And Its Absence Said",
  "state": "Implementing",
  "size": "S",
  "priority": "Highest",
  "rank": 2,
  "blockedBy": [],
  "covers": "The Linux package installs the carried porelo-host collection readable by everyone (0644), not root's alone, so Set up a machine runs its check; and a collection that cannot be read or whose digest differs is said as such, never as one that holds no check."
}
```

**Why this size.** One packaging script and its staging script, one reading function and the wizard's sentence, with
their tests; no contract.

**What must be true.** In the installed window, *Set up a machine* runs the check the carried collection holds. If the
collection is missing, unreadable or not the pinned one, the step says which, instead of saying it holds no check.

## Plan

- **Seen in the installed package.** `/usr/lib/porelo-frontend/porelo-host-<version>.tar.gz` is installed `root:root`
  with mode 0600, so the window, running as the person, cannot read it; step 6 of *Set up a machine* then says "The
  collection carried here holds no check, so preparing runs without one." The other bundle files are 0755 or 0644.
- **Where the mode comes from.** `pinned_fetch` (`.github/actions/pinned-jdk/pinned.sh`) downloads into a `mktemp`
  file (0600) and renames it; `tool/fetch_collection.sh` copies it with `cp`, which keeps that mode, and moves it to
  `build/collection/`; `tool/package.sh` copies it into the bundle with `cp`, and nfpm's `type: tree` takes the mode
  from disk. The fix: `tool/package.sh` installs it with `install -m 0644`, and `tool/fetch_collection.sh` leaves its
  result 0644 (`chmod 0644` before the final `mv`). `pinned.sh` is the shared copy and is not changed here.
- **Absence said as absence.** `readCarriedHostCheck` (`packages/porelo_host/lib/src/host_check.dart`) answers `null`
  alike for no file, an unreadable file (`FileSystemException`), a digest that differs and a collection with no check;
  `_check` in `lib/src/ui/server_setup_wizard.dart` words every `null` as "holds no check". It answers which of the
  four it met, and the wizard says it: an unreadable collection names its path and that it cannot be read, a
  different digest says the collection is not the pinned one. Whether preparing may go on without a check stays as
  today for "no check" alone.
- **Red first.** In `packages/porelo_host/test/`, `readCarriedHostCheck` is given a collection of the pinned digest
  made unreadable (`chmod 000`, skipped when the test runs as root, since root reads it anyway) and one with a wrong
  digest; each is answered as what it is, not as "no check". It fails on today's code. `test/packaging_test.dart` gains a check that `tool/package.sh` installs the collection 0644, read from
  the script with comments stripped, as it reads the template.
- **Windows.** `tool/windows-prepare.ps1` checks the collection beside `porelo-host.exe` by its digest; the MSIX is
  installed read-only for every user, so the mode flaw does not apply. Checked by reading `windows-package.ps1` for how
  it copies the file.

## Acceptance

- A package built by `tool/package.sh` carries the collection as 0644 (read in the `.deb` with `dpkg-deb -c`), and the
  installed window's step 6 shows the check. The reading test is seen red on today's code; the packaging test is seen
  red with `cp` put back.

## To be checked

- That `windows-package.ps1` copies the collection without narrowing its access, by reading it and the trial's
  install listing.
