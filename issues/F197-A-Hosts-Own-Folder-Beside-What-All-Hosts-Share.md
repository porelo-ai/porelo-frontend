# F197 — A Host's Own Folder Beside What All Hosts Share

**Status:** Analyzed; blocked by `porelo-host`
[HO36](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho36), its part of `porelo-project`
[PJ50](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj50).
**Size:** L - the host dialog's step *The drive*, `HostFiles` and the kept run, and a path both repositories read.

**What must be true.** A host's files lie in its own folder `hosts/<project>/` beside `shared/`, which every host
reads, in a tresor of the host's own or one several hosts share, as the person chooses per host.
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
- **One layout only (decided):** `destinationPath` writes under `<folder>/hosts/<project>/`, in a tresor of the
  host's own too, and `porelo-host` ([HO36](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho36)) reads the same path; the host's name is always its project's, one host per
  project (decided). A folder that still holds the old `porelo-host/` is refused with a sentence naming the new place,
  never migrated: no host is rented now, and nothing kept needs moving.
- **The person's private drives:** a list on *The drive* (tresor or folder, an optional subfolder), written into
  `machine.yml` as entries marked as the person's; the host's own drive is the one marked as its setup. The shape of
  that list is agreed with Machines in the channel first, since `porelo-host` reads it.
- **Red first:** `test/ui/host_bundle_test.dart`: `machine.yml` lies in `hosts/<project>/` and nothing is written
  outside it; a folder with the old `porelo-host/` is refused before anything is written.

## Acceptance

- Two hosts in one shared tresor: each one's files are in its own folder only, and `shared/` holds nothing of
  either.
- A folder holding the old `porelo-host/` is refused, naming `hosts/<project>/`.
- A private drive added in the wizard appears in `machine.yml` as the person's, never as the host's setup.
- Seen to fail: the first test red against today's fixed `porelo-host/`.

## To be checked

- With Machines: the drive list's shape in `machine.yml`, and what `down` waits for when several drives are
  mounted.
- Whether Tresorit's client on the host can sync `hosts/<name>/` alone; if not, the other hosts' folders hold
  nothing but what [F198](README.md#f198) keeps encrypted.
