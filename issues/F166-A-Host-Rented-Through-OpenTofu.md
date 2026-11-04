# F166 — A Host Rented Through OpenTofu

**Status:** Accepted.
**Size:** M - a provider of `porelo-host` driving `tofu`, its secrets only in `tofu`'s environment, the module's checked arrival, and its tests against a stand-in.

**What must be true.** `porelo-host up` rents its host through `porelo-host`'s OpenTofu module
(`porelo-host`'s issue "A Machine Rented And Given Back By OpenTofu") and `down`
gives it back through the same module, one command each as today, so that a host can come from
any provider the module covers. `--given` stays for a machine one has, which `tofu` never touches.

## Why

`porelo-host` calls `tofu` itself, rather than the administrator running it apart.
`ScalewayElasticMetal` in `packages/porelo_host/lib/src/scaleway.dart` implements
`HostProvider` with direct API calls, without OpenTofu.
`packages/porelo_host/bin/porelo_host.dart` refuses `up` unless it prepares an existing server with
`--given` and `--host-name`; the promised rental through OpenTofu is not built.
`HostDialog` in `lib/src/ui/host_dialog.dart` takes no project or synced drive folder.

## To be checked

- **The seam:** a `TofuProvider` behind the existing `HostProvider` (`packages/porelo_host/lib/src/provider.dart`):
  `find` and `state` from `tofu output -json`, `create` as `apply`, `release` as `destroy` and then
  `plan -detailed-exitcode` reading no change, so `HostRun`'s order (rent, readiness, trust, ssh,
  the plays, `down`'s kept host) stays as it is. Readiness: whether the provider's `apply` already
  waits for the installed system, or `HostRun` still asks until ssh answers.
- **The provider as the guard,** as `porelo-host`'s plan has it: before `apply`, today's find by
  the tag (`porelo-host=<host>`, from `HostPlan.serverTagFor` in
  `packages/porelo_host/lib/src/host_run.dart`) is kept, and a tagged server the state lacks refuses `up`
  naming it, as a state not yet synced or written from another computer would; `down` with an empty
  state and a tagged server refuses too. A conflict copy of the state, made by the drive's client,
  refuses both until a person keeps one.
- **The host key:** made by the module (`tls_private_key`) and read from its `host_key` output,
  rather than by `ssh-keygen` here, and still trusted as the only line of the package's own
  `known_hosts`; the private half then lies in the state, encrypted.
- **The secrets:** the Scaleway key from the system's secret store (`porelo-host/scaleway`) and the
  state's passphrase passed only in `tofu`'s environment, never an argument, a file or a line it
  prints; the module needs `SCW_ACCESS_KEY` as well,
  which `key set scaleway` does not keep today: kept beside the secret key, or as a plain setting,
  since it is no secret; and `tofu`'s own output read for anything secret before it is relayed as a step.
- **The module's arrival:** the release's `porelo-host-tofu-<version>.tar.gz` checked against its
  `SHA256SUMS` before it is unpacked, as the collection is; the `tofu` on `PATH` refused unless
  `tofu version -json` names the pinned version, before anything is rented.
- **The state and its key:** the state in the person's
  drive, in the project's folder there (the one the dialog's *Its synced folder on this computer*
  names), encrypted; its key in the system's secret store beside the Scaleway key, entered once on
  another computer, never in a file, an argument or the drive. What `up` says when that key is
  missing here, and when the drive's folder is not synced yet.
- **Tests without renting:** a `tofu` stand-in answering `init`, `apply`, `output`, `destroy` and
  `plan` from recorded answers. There is no `tool/host_standin.dart` in this checkout.
- **The interface:** the dialog of [F164](README.md#f164) asks for the same values; whether it
  gains anything (the state's place, a missing `tofu` said in words).
