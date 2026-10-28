# F211 — A Server Prepared With No Project

**Status:** Estimated (operator, 2026-10-28); accepted with `porelo-project` [PJ78](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj78); blocked by [F208](README.md#f208), [F209](README.md#f209), [F210](README.md#f210), [F212](README.md#f212), and `porelo-host` [HO42](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho42), [HO43](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho43) and [HO44](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho44).
**Size:** L - the host dialog cut to the host admin's act, three new functions on a prepared host, on contracts with `porelo-host`.

**What must be true.** A host admin prepares a server under *Machines* with no project: rented, its VPN, its forge (on by default, off where a central forge is used), its homeserver, its CA; then registers a project for its admin, admits project admins by hand from their public keys, and gives the server back. The values a project admin needs are shown for them to write into the project's access file.

## Why

`porelo-project` [PJ78](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj78): setting up a host and putting a project on it are two acts, by two people. Today's host dialog (`lib/src/ui/host_dialog.dart`) does both in one `up` for one person.

## Plan

- ***Prepare a server…*** (`host-admin`), in the title bar's *Machines* group beside *Watch another machine…* (`Home.appBar`): today's host dialog without *The project*: *Where it is rented*, *Your ssh keys*, *Your secrets file*, and the network `<n>` proposed as one no known host uses. It runs `porelo-host up` with no project; the stop asks only `wireguard` and `forge-certificate` ([F199](README.md#f199)'s feed, the root act); the forge runs by default and is switched off where the host's people use a central forge (the operator, 2026-10-28; [F145](README.md#f145)).
- **Afterwards:** the host admin's own VPN ([F209](README.md#f209)), and a panel *For the project admins* with the host's address, endpoint, WireGuard public key, network, ssh host key fingerprint, `ca_sha256` and the homeserver's name, each copyable.
- ***Register a project…***: the project's name, its admin's account, the project's signing key; runs `porelo-host-project add` over the host admin's root ssh; *Take the project off* runs `remove`, whose refusal while anything is unpushed is shown in its words.
- ***Admit a project admin…***: the account name and the person's key block (*Copy my public keys*, [F216](README.md#f216)), checked as an ssh and a WireGuard public key with no comment; runs `porelo-host-person add` with the role `project-admin`, both keys on standard input; *Remove* likewise.
- ***Give the server back*** as today.
- **Red first:** a widget test that *Prepare a server…* runs `up` with no `--project` and its stop feeds only `wireguard` and `forge-certificate`.

## Acceptance

- A host prepared from here answers over its VPN with its forge and homeserver, and holds no project.
- A project registered and a project admin admitted show up in the host's records as `porelo-host` reads them.
- No secret is typed into a field of the interface; keys are public halves only.
- Seen to fail: the widget test red while the dialog still asks for a project.

## To be checked

- `porelo-host`'s exact commands and outputs, once its issues are written: read against them before building.
