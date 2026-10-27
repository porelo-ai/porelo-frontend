# F197 — A Host's Own Folder Beside What All Hosts Share

**Status:** Analyzed; blocked by `porelo-host`'s part of `porelo-project`
[PJ50](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj50), not yet numbered.
**Size:** L - the host dialog's step *The drive*, `HostFiles` and the kept run, and a path both repositories read.

**What must be true.** On *The drive* the person chooses, per host, whether the host has a tresor of its own (as
today) or its own folder `hosts/<name>/` in a tresor several hosts share, beside `shared/`, which every host reads.
The interface writes the host's files (`machine.yml`, its WireGuard key until
[F198](README.md#f198) takes it, the keys for its vault) into the host's place only, and names the person's private
drives the host mounts for the person, as many as the person adds. It works the same with a folder on a drive that
has no tresors.

## Why

`porelo-project` [PJ50](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj50): one tresor per
host is work to keep, and one tresor for every host lets each host read every other host's keys.

## Plan

- **Read in today's code:** `HostFiles.destinationPath` (`packages/porelo_host/lib/src/host_files.dart`) writes
  under `<folder>/porelo-host/`, and `hostDrivePath` with `porelo-host` is the same path on the host; `prepare`
  writes `machine.yml`, `wireguard.key` and `keys/` there. A host is its project: `HostUpRecord` is kept per project
  (`lib/src/app/settings.dart`) and its `arguments` name `--project` and `--tresor`, nothing of a host's own name.
- **The place, one value:** `HostUpRecord` gains where the host's files go - `own` (the tresor's root, today's
  layout, the default so a kept run stays as it is) or `shared` with the host's name; `destinationPath` takes it, and
  `up` passes it to `porelo-host` as one argument agreed with Machines, so both read one path. The host's name is
  the project's, which is unique per person today; the wizard shows it.
- **The person's private drives:** a list on *The drive* (tresor or folder, an optional subfolder), written into
  `machine.yml` as entries marked as the person's; the host's own drive is the one marked as its setup. The shape of
  that list is agreed with Machines in the channel first, since `porelo-host` reads it.
- **What changes for the person:** nothing until they choose `shared`; then a refusal names a `hosts/<name>/` that
  already belongs to another host's kept run.
- **Red first:** `test/ui/host_bundle_test.dart`: with `shared`, `machine.yml` lies in `hosts/<name>/` and nothing
  is written outside it; with `own`, the files stay where they are today.

## Acceptance

- Two hosts in one shared tresor: each one's files are in its own folder only, and `shared/` holds nothing of
  either.
- A kept run from before opens unchanged and writes where it wrote.
- A private drive added in the wizard appears in `machine.yml` as the person's, never as the host's setup.
- Seen to fail: the first test red against today's fixed `porelo-host/`.

## Open questions

- **QF63:** The host's name: always the project's (one host per project, as today), or one the person gives, so one
  project can have two hosts? Recommended: the project's, until a second host per project is asked for.

## To be checked

- With Machines: the argument that names the host's place, the drive list's shape in `machine.yml`, and what `down`
  waits for when several drives are mounted.
- Whether Tresorit's client on the host can sync `hosts/<name>/` alone; if not, the other hosts' folders hold
  nothing but what [F198](README.md#f198) keeps encrypted.
