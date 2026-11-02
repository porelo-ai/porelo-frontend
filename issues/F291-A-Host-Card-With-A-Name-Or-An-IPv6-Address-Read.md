# F291 — A Host Card With A Name Or An IPv6 Address Read

**Status:** Analyzed.
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

## Plan

- Split the address rule of `PreparedHost.read`: a completion read from the machine's `host.json` keeps the IPv4
  rule; a saved card (no `hostName` given) takes every form `isCardAddress` takes, as `PreparedHost.card` does. The
  saved settings, the host registry change and its receipt then read such a card back.
- The existing-server field takes a host name or an IP address and says so; the settings' given server is checked
  with the card's rule.
- `HostCardSsh` already writes such a card: `HostName` as given (IPv6 without brackets), the known host as
  `[address]:port` off port 22 and as the plain address on 22. Tests pin both forms for a name and an IPv6 address,
  and that the control socket and forwards do not depend on the address form.
- The vault's opening keeps refusing a card on another port or at an IPv6 address in words
  (`FleetBackend.whyNotUnlockable`) until Core's `host unlock` takes them; nothing else is held back by it.
- The project access change's reader is left as it is: *Register the project* and *Add a developer* are replaced in
  the organization model, and their replacements read the organization's host card.
- **Red first:** a settings file and a host registry receipt holding a card at `orchard.example.org` and at
  `2001:db8::7` read back; both fail today with the IPv4 sentence. A card config and known-hosts line for both forms,
  on port 22 and 2222.

## Acceptance

- On a local VM reached by a host name and by its IPv6 address: the card's connection is raised, the forge and
  Element are reached through it, the interface restarted reads the card back, and the host page's actions run.
- A card address Core's card refuses is still refused with words; a completion from a machine still needs IPv4.

## Open questions

- Is it built now on today's paths (card connection, saved cards, *Prepare a server…*), which the rebuilt *Connect*
  and *Add a host* reuse, or only into those rebuilt dialogs? Proposed: now, on the parts the rebuild keeps.

## To be checked

- With Core: whether opening the host vault still goes through `porelo host unlock` in the organization model, and
  when it takes a port and an IPv6 address.
- Which local VM can be reached by IPv6 and by a name (the libvirt network's IPv6 and DNS); measure ssh's
  `ControlPath` and `-L` forwards against an IPv6 literal there.
- Whether Scaleway's completion can name an IPv6-only server; today it takes the IPv4 address alone.
