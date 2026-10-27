# F197 — The Host's Files Uploaded Over Its Own Ssh

**Status:** Analyzed; re-cut from a drive layout (step 2 of the host's new setup), blocked by `porelo-host`'s
step-2 issue, not yet numbered.
**Size:** M - `porelo_host`'s `copy` step and `HostFiles`, the host dialog's step *The drive*, and their tests; one
path both repositories read.

**What must be true.** The host's setup files, `machine.yml` and the project's bundle, both made on the desktop,
reach the host over the ssh its setup already has, into a place only root reads, and the host reads them there.
The drive is still mounted and still holds the secrets until the next steps take them; nothing else changes for the
person. The desktop keeps its copy of `machine.yml` on the person's drive, so a second desktop sets up a host the
same way.

## Why

The operator's decision (2026-10-27): with every secret given on standard input from `secrets.kdbx`
([F198](README.md#f198), [F199](README.md#f199)), the drive would carry only these two files, so uploading them takes
the drive out of the host's setup, step by step, with nothing broken in between.

## Plan

- **Read in today's code:** `porelo_host`'s `up` (`packages/porelo_host/lib/src/host_run.dart`) already has a
  `copy` step after `ssh`: it writes the inventory through `remote.run` (`cat >` on standard input) and the
  collection through `remote.copy`, then checks the collection's digest on the host. `HostFiles.prepare` writes
  `machine.yml` and the bundle into the tresor (`porelo-host/`), where the host's drive role reads them.
- **The upload:** the `copy` step also sends `machine.yml` and the bundle, each on standard input to a root-owned
  place agreed with Machines (proposed: `sudo install -D -m 0600 -o root -g root /dev/stdin
  /etc/porelo-host/setup/<file>`), and checks each by its SHA-256 on the host, as the collection is checked.
- **The desktop's copy:** `HostFiles` still writes `machine.yml` to the person's drive for other desktops, under
  the project's name; the bundle is made fresh at each `up` and is not kept there.
- **Red first:** a test of `porelo_host`'s `up` against its remote stand-in: the two files are sent to the agreed
  place with their digests checked, and a mismatch refuses `copy`.

## Acceptance

- Rented once: the setup comes up with the uploaded `machine.yml` and bundle, the drive still mounted.
- A digest that does not match on the host refuses `copy`, naming the file.
- Seen to fail: the test red against today's `copy`, which sends neither.

## To be checked

- With Machines: the place on the host, its owner and mode, and that the host's roles read it in place of the drive.
