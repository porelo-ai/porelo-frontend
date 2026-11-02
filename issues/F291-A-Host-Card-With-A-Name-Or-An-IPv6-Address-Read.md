# F291 — A Host Card With A Name Or An IPv6 Address Read

**Status:** Review.
**Severity:** high.
**Size:** M - one reader of saved cards and its callers, the existing-server field and the card tunnel's files, each
with tests, and a check on a VM by name and by IPv6 address; no contract with another repository changes.

**What must be true.** A host whose card names a host name or an IPv6 address, as Core's card allows, is reached
from this interface exactly as one at an IPv4 address: its connection is written and raised, its saved card reads back
after a restart, a server given by name or IPv6 address is taken, and its host-admin actions run. Where Core cannot
yet serve such a host (opening its vault), the interface says so in words and nothing else stops.

## Why

The card a host carries takes a host name, an IPv4 or an IPv6 address, and `PreparedHost.card` and `HostCardSsh`
take all three. But a card saved in this interface is read back through `PreparedHost.read`
(`packages/porelo_host/lib/src/host_record.dart`), the reader of a preparation's completion, which takes an IPv4
address only. So such a host fails with "The host completion needs a usable IPv4 address." wherever a saved card or
change is read again: the settings' prepared host and given server (`lib/src/app/settings.dart`), the host
registry's change and its receipt (`lib/src/app/host_access_contract.dart`), and a project access change
(`lib/src/app/project_access_contract.dart`). The existing-server field of *Prepare a server…*
(`lib/src/ui/host_dialog.dart`) asks for "the IPv4 address" alone.

## Plan as built

- `PreparedHost.read` takes every form `isCardAddress` takes, and still refuses what no other computer reaches a
  server at: loopback, unspecified and multicast addresses, IPv4-mapped ones among them, and `localhost` names. Saved
  settings, a kept host registry change and its receipt read such a card back.
- A machine reports only its own IPv4 address, so a server given by name or IPv6 address never matched it. A given
  IPv4 address is still compared. For a name or an IPv6 address the pinned host key decides, and the card keeps the
  address the person gave.
- `scp` gets an IPv6 address in brackets. The address checks of the setup upload and the provider terminal take the
  card's rule, so an IPv6 address opening with `::` is no longer refused there.
- The existing-server field of *Prepare a server…* asks for a host name or IP address.
- `HostCardSsh` already wrote such a card as ssh reads it; tests now hold both forms on port 22 and another port.
- The project access change's reader needed no change of its own: it reads through `PreparedHost.read`.

## Acceptance

- Unit and widget tests: a server prepared at a name and at an IPv6 address, read back after a restart; a kept host
  card change reads back; another host key is refused; a given IPv4 address the machine does not report is refused.
- Measured with real OpenSSH and a card this code published, against a local VM's sshd, by an mDNS name on port 22 and
  by the IPv6 literal `::1` on a forwarded port: a command, a forward through the master, a second command over its
  control socket, another host key refused, and `scp` in brackets.

## Limits

- An IPv6-only server cannot be prepared: the host's own play stops without an IPv4 default route. A server with both,
  reached by its IPv6 address, is not stopped by that.
- The host vault is not opened from here for a card on another port or at an IPv6 address: Core's `host unlock` takes
  neither, and the interface says so in words.

## To be checked

- A whole *Prepare a server…* run on a machine given by name, and any run over a real IPv6 network: the local VMs'
  network has no IPv6 route, so the IPv6 measurement above ran through a forward on this computer's loopback.
- Whether opening the host vault stays with `porelo host unlock` in the organization model.
