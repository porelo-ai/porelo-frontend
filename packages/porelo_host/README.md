# porelo_host

The interface's host lifecycle and private bundle utilities, implemented in pure Dart for Linux and Windows.
`HostRun` keeps provider rental identity and SSH host-key pinning separate from the served server-setup contract.
`ServerPreparation` is the typed boundary for SSH-only setup; without its implementation, setup fails before renting.

A saved legacy rental can be given back by its validated provider identity, after an explicit confirmation that
its data is no longer needed. Recovery never opens its obsolete SSH credentials or runs its old setup. Normal
teardown retains a server if its down play fails. A successful provider response is required before give-back
is reported.

`HostFiles` creates bundles only from commits signed by the verified project-admin signer set. `HostFileWriter`
stages complete files privately, protects them with Linux permissions or current-user Windows ACLs, and refuses
a conflicting destination. The upload boundary checks file names, digests and ownership without following links.
No helper generates person or laptop keys, installs local trust, or prompts for host secrets.

The package build still carries the collection identified by `lib/src/collection.dart` beside `porelo-host`.
`porelo-host --collection-info` exposes that identity for packaging. The final Core and host setup adapters and
a real interoperability check are required before signed-state setup can be used from the shipped command.
