# F197 — The Host's Files Uploaded Over Its Own Ssh

**Status:** Review; published 2026-10-28 (Build green on `1c53dc5`), carried by `porelo-host` 0.5.6 with
[HO36](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho36), not yet run on a rented host.
**Size:** M - `porelo_host`'s `copy` step and `HostFiles`, the host dialog's step *The drive*, and their tests; one
path both repositories read.

**What must be true.** The host's setup files, `machine.yml` and the project's bundle, both made on the desktop,
reach the host over the ssh its setup already has, into a place only root reads, and the host reads them there.
The secrets already come from `secrets.kdbx` ([F199](README.md#f199)); nothing else changes for the person. The
desktop keeps its copy of `machine.yml` in the interface's own folder; the drive has no part in the host's setup.

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
- **The desktop's copy:** `HostFiles` keeps `machine.yml` in the interface's own data folder, under the project's
  name, no longer on a drive (the drive has nothing to do with the host's setup, decided); the bundle is made fresh
  at each `up` and is not kept.
- **Red first:** a test of `porelo_host`'s `up` against its remote stand-in: the two files are sent to the agreed
  place with their digests checked, and a mismatch refuses `copy`.
- **Built:** `porelo-host up --machine-file … --bundle …` uploads both (both or neither). The setup's record keeps
  the folder (`setupFolder`) and passes both paths on every `up`, resume and `down`; a record from before it names
  none, and its host reads the drive as before. *The drive* no longer writes anything into the synced folder; it is
  read only for a VPN key it held from before, which moves into the secrets file. With the interface writing the
  files, every setup takes the host's key from the secrets file and waits for the VPN; only a record from before,
  with neither a drive folder nor a setup folder, had host files given by hand, and its stop gives no VPN key from
  the file.
- **From its harm reading (eleven findings, ten taken):**
  - **On the host:** both files are read and hashed before anything is rented, and one named without the other is
    refused. They are staged in a `0700` folder of the login user and checked there before anything is placed. They
    are placed with `/usr/bin/sudo /usr/bin/install` and checked again where they stay; a mismatch there removes
    them. The staging folder goes on every ending.
  - **On this desktop:** the interface's own folder refuses a link on its way, its folders are kept `0700`, and a
    machine file of its own earlier attempt is replaced. The arguments normalize the folder, and an older record
    without a signing key keeps the field's own.
  - **The secrets file:** a key the drive still holds stops the start, and the opened file's cache follows the
    secrets file's and the drive's key's own state.
  - **Tests:** the digest check's order is asserted on what was run, and the setup folder's links are tested.
  - **Declined, with the reason:** a local file swapped between its hash and its copy is caught by the check on the
    host, which refuses it. The older commands of `up` that run by `PATH` (`mkdir`, `sha256sum`,
    `sudo ansible-playbook`) are [F205](README.md#f205)'s, an Idea.
- **From the reading of those fixes (seven findings, all taken):** the opened file's cache is kept as the opening left
  it, so the master password is asked once; a link above the interface's own folders (`hosts`, the project's, its
  `porelo-host`) is the person's and taken; an earlier machine file goes only once every other file has passed, and
  is compared by its bytes; a placing the host refuses removes the place too; folders there from before are
  tightened; and tests now see the staging folder go and the drive's key change the cache.
- **From a third reading (two findings, both taken):** the interface's own folders are looked at from the top down,
  since a link at `hosts` hides behind a folder below it to a walk from the bottom; and the test of an opening that
  changes nothing new moves a drive key, so a cache taken before opening would ask again.

## Acceptance

- Rented once: the setup comes up with the uploaded `machine.yml` and bundle, and reads nothing from a drive.
- A digest that does not match on the host refuses `copy`, naming the file.
- Seen to fail: the test red against today's `copy`, which sends neither.

## To be checked

- That the host's roles read the uploaded files in place of the drive's.
