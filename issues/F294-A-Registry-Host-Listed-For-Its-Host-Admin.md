# F294 — A Registry Host Listed For Its Host Admin

**Status:** Idea.
**Severity:** medium.
**Size:** M - the registry's page items, the machines page, the host commands and the host dialog, with their tests;
no contract with another repository.

**What must be true.** A host admin whom `owners.yml` names for a host sees that host under *Machines*, with
*Admit a project admin…* and *Bring the state to the host*, also when this interface neither prepared nor joined it.
The chosen registry's row on the forge page counts the hosts Core's read accepted.

## Why

*Machines* lists only machines this interface watches and the registry's page items. Those items
(`RegistryReadSource`) take a host from Core's read only when a watched machine has its name, and
`preparedHostCommands` offers Admit and Bring only with a setup record this interface saved while preparing the host.
A host prepared by another way, such as a script or another admin's interface, therefore has no row and no Admit,
and the forge page says "no hosts" while Core's read lists it.

## The shape

- A host of the accepted registry whose `owners.yml` admins include the proven person is a row under *Machines*,
  named and addressed from its verified card, not watched until it is joined.
- Its ⋮ offers Admit, Bring, Lock, Let back in and Delete the account under the same checks as today
  (`HostAccess`), which already need only the registry's host, not a setup record. *Registry publication…* and
  *Run the setup again* stay with a setup record.
- The forge page's registry row counts `Registry.hosts`, Core's accepted hosts.

## Plan

- `lib/src/app/registry_read_source.dart`, `lib/src/app/registry_pages.dart` (`registryMachines`,
  `scopedMachineRows`), `lib/src/app/commands.dart` (`preparedHostCommands`), `lib/src/ui/machines_page.dart`,
  `lib/src/ui/forges_page.dart`, and the host dialog's admit path where it reads the setup record.
- **Red first:** a feature scenario with an accepted registry naming the person host admin of `walk6m`, no setup
  record and no watched machine: *Machines* shows walk6m with *Admit a project admin…*, and the forge row names
  walk6m. Today both fail.

## Acceptance

- A person who is no host admin of the host sees no such row, or the row with Admit unavailable and who may.
- Admitting from such a row files and brings as from a prepared host; a host given back stays refused.

## To be checked

- Whether the same holds for a project of the registry that this computer's daemon does not follow: *Register the
  project* and *Add a developer…* live on a followed project's row today, so a project admin needs the project's
  repository followed first.
