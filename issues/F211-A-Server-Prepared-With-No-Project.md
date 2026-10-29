# F211 — A Server Prepared With No Project

**Status:** Review; blocked by [F208](README.md#f208), [F209](README.md#f209), [F210](README.md#f210) and [F212](README.md#f212).
**Size:** L - the host dialog cut to the host admin's act, three new functions on a prepared host, on contracts with `porelo-host`.

**What must be true.** A host admin prepares a server under *Machines* with no project: rented, its VPN, its forge (on by default, off where a central forge is used), its homeserver, its CA; then registers a project for its admin, admits project admins by hand from their public keys, and gives the server back. The values a project admin needs are shown for them to write into the project's access file.

## Why

Decided: setting up a host and putting a project on it are two acts, by two people. Today's host dialog (`lib/src/ui/host_dialog.dart`) does both in one `up` for one person.

## Plan

- ***Prepare a server…*** (`host-admin`), in the title bar's *Machines* group beside *Watch another machine…* (`Home.appBar`): today's host dialog without *The project*: *Where it is rented*, *Your ssh keys*, *Your secrets file*, and the network `<n>` proposed as one no known host uses. It runs `porelo-host up` with no project; the stop asks only `wireguard` and `forge-certificate` ([F199](README.md#f199)'s feed, the root act); the forge runs by default and is switched off where the host's people use a central forge ([F145](README.md#f145)).
- **Afterwards:** the host admin's own VPN ([F209](README.md#f209)), and a panel *For the project admins* with the host's address, endpoint, WireGuard public key, network, ssh host key fingerprint, `ca_sha256` and the homeserver's name, each copyable.
- ***Register a project…***: the project's name, its admin's account, the project's signing key; runs `porelo-host-project add` over the host admin's root ssh; *Take the project off* runs `remove`, whose refusal while anything is unpushed is shown in its words.
- ***Admit a project admin…***: the account name and the person's key block (*Copy my public keys*, [F216](README.md#f216)), checked as an ssh and a WireGuard public key with no comment; runs `porelo-host-person add` with the role `project-admin`, both keys on standard input; *Lock* runs `lock`, and
  *Purge*, a second decision, `purge`.
- ***Give the server back*** as today.
- **Red first:** a widget test that *Prepare a server…* runs `up` with no `--project` and its stop feeds only `wireguard` and `forge-certificate`.

## The contract with porelo-host

- **The inventory, `porelo_host_inventory_version: 2`:** `porelo_host_name` (`<host>`, one DNS label
  of 1 to 63 lower-case letters, digits or hyphens, a letter or digit at each end), `porelo_host_network` (`<n>`, 0 to 255; the host is `10.73.<n>.1/24`),
  `porelo_host_distribution`, `porelo_host_vpn_peer_public_key`, `porelo_host_vpn_peer_address` (the host admin's
  laptop, in `10.73.<n>.0/24`, not `.1`) and `porelo_host_forge`; no account, project or authorized key.
- **The end of `up`:** once, after its last `ok`, one line of the step protocol
  `{"v": 1, "state": "host", "host": {…}}`; the same object in `/etc/porelo-host/host.json`: `address`,
  `endpoint` (`<address>:51820`), `wireguard_public_key`, `network`, `ssh_host_key`, `ca_sha256` (lower-case hex of
  the CA's DER) and `homeserver`. Each field is checked here and a missing one refused by name; an unknown one is
  ignored; the ssh host key's fingerprint is computed here.
- **The helpers** run as `ssh root@10.73.<n>.1 /usr/local/sbin/porelo-host-person …` or `porelo-host-project …` with
  the rental's key. Each success is one JSON line on stdout; a refusal is `porelo-host-person: <words>` or
  `porelo-host-project: <words>` on stderr with nothing changed, exit 64 (input), 65 (the records or the forge say
  no), 69 (something needed is missing) or 73 (cannot write), shown in its words.
  - `porelo-host-person add <user> --role project-admin`, the key block on standard input: one laptop per line,
    `<laptop> <ssh-ed25519 AAAA…> <WireGuard public key>[ <10.73.n.m>]`, one space apart, no comment; `<laptop>`
    has 1 to 32 lower-case letters, digits or hyphens, a letter or digit at each end, the WireGuard key is 44 base64 characters ending in `=`; without
    an address the host takes the lowest free from `.2`. It answers
    `{"person":…,"role":"project-admin","laptops":[{"laptop":…,"vpn_address":…}]}`.
  - `porelo-host-person lock <user>` answers `{"person":…,"locked":true}`, `purge <user>` `{"person":…,"purged":true}`.
  - `porelo-host-project add <project> <admin> --signed-by '<ssh-ed25519 AAAA…>'` (no comment) answers
    `{"project":…,"admin":…,"organization":…,"publisher":"porelo-publisher-<project>"}`; `remove <project>`
    `{"project":…,"removed":true}`. While the project's organization holds a repository, `remove` takes the central
    forge's token as the only line of standard input; the interface runs it in a terminal, the token piped from the
    secrets file's `shared/forge-central-token` with the master password typed there. A repository with no central
    home is refused, so its only copy is never deleted.

## Acceptance

- A host prepared from here answers over its VPN with its forge and homeserver, and holds no project.
- A project registered and a project admin admitted show up in the host's records as `porelo-host` reads them.
- No secret is typed into a field of the interface; keys are public halves only.
- Seen to fail: the widget test red while the dialog still asks for a project.

## To be checked

- The contract above against porelo-host's local commits as they arrive.
