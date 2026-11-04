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

## To be checked

- **The seam:** a `TofuProvider` behind the existing `HostProvider` (`packages/porelo_host/lib/src/provider.dart`):
  `find` and `state` from `tofu output -json`, `create` as `apply`, `release` as `destroy` and then
  `plan -detailed-exitcode` reading no change, so `HostRun`'s order (rent, readiness, trust, ssh,
  the plays, `down`'s kept host) stays as it is. Readiness: whether the provider's `apply` already
  waits for the installed system, or `HostRun` still asks until ssh answers.
- **The provider as the guard,** as `porelo-host`'s plan has it: before `apply`, today's find by
  the tag (`porelo-host=<host>`, from `HostPlan.serverTagFor` in
  `packages/porelo_host/lib/src/host_run.dart`) is kept, and a tagged server the state lacks refuses `up`
  naming it; `down` with an empty state and a tagged server refuses too.
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
- **The state and its key:** the state local, on the computer that rents, encrypted with a key from the person's vault;
  the tag guard above stays. What `up` says when that key is missing here. The state in the organization's repository
  or at the provider is [F352](README.md#f352).
- **Tests without renting:** a `tofu` stand-in answering `init`, `apply`, `output`, `destroy` and
  `plan` from recorded answers. There is no `tool/host_standin.dart` in this checkout.
- **The interface:** the dialog of [F164](README.md#f164) asks for the same values; whether it
  gains anything (a missing `tofu` said in words).
