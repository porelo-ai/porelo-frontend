# F197 — The Host's Files Uploaded Over Its Own Ssh

**Status:** Analyzed; re-cut from a drive layout (a step of the host's new setup, after [F199](README.md#f199)),
blocked by `porelo-host` [HO36](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho36).
**Size:** M - `porelo_host`'s `copy` step and `HostFiles`, the host dialog's step *The drive*, and their tests; one
path both repositories read.

**What must be true.** The host's setup files, `machine.yml` and the project's bundle, both made on the desktop,
reach the host over the ssh its setup already has, into a place only root reads, and the host reads them there.
The secrets already come from `secrets.kdbx` ([F199](README.md#f199)); nothing else changes for the person. The desktop keeps its copy of `machine.yml` on the person's drive, so a second desktop sets up a host the
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
- **The upload, agreed with Machines:** the `copy` step makes `/etc/porelo-host/setup` (`sudo install -d -m 0700 -o
  root -g root`) and sends `machine.yml` and the bundle, each on standard input with `sudo install -m 0600 -o root -g
  root /dev/stdin /etc/porelo-host/setup/<file>`, then checks each by its SHA-256 on the host, as the collection is
  checked. Porelo's account does not exist yet at `copy`, which runs before the first play, so the host's own
  `roles/porelo/tasks/install.yml` gives the folder and the files the account's group (`0750`, `0640`) once its setup
  has made the account: it reads them and never writes them. `down` removes the folder.
- **The bundle is what the host follows:** `HostFiles.bundleUrl` names it in `machine.yml`'s `project.url`, and
  becomes `/etc/porelo-host/setup/<project>.bundle`; `porelo project follow` reads it as the repository, unchanged.
- **The desktop's copy:** `HostFiles` still writes `machine.yml` to the person's drive for other desktops, under
  the project's name; the bundle is made fresh at each `up` and is not kept there.
- **Red first:** a test of `porelo_host`'s `up` against its remote stand-in: the two files are sent to the agreed
  place with their digests checked, and a mismatch refuses `copy`.

## Acceptance

- Rented once: the setup comes up with the uploaded `machine.yml` and bundle, the drive still mounted.
- A digest that does not match on the host refuses `copy`, naming the file.
- Seen to fail: the test red against today's `copy`, which sends neither.

## To be checked

- That the host's roles read the uploaded files in place of the drive's.
