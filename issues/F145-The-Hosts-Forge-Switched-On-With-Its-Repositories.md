# F145 — The Host's Forge Switched On With Its Repositories

**Status:** Idea; blocked by `porelo-host` [HO08](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho08).

**What must be true.** A person bringing a host up chooses whether it runs its own forge, and which
repositories of the central forge move there, in the host dialog or on `porelo_host`'s command line,
and is told where the central forge's token must lie before `up` runs.

## The shape

- **The first inventory carries three keys beside `porelo_host_account`**, as agreed with
  `porelo-host` for [HO08](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho08): `porelo_host_forge` (a boolean, `false` by default),
  `porelo_host_forge_owner` (a string, `porelo` by default) and `porelo_host_forge_repositories`
  (a list of `{name, url}`, empty by default). The inventory is JSON, so each is its own type, never
  a string.
- **Set by the person** with `--forge`, `--forge-owner NAME` and `--forge-repository NAME=URL`
  (repeatable) on `porelo_host`, and by the same three in the host dialog; both fill `HostPlan`.
- **Checked here before anything is written**: a `name` is `^[A-Za-z0-9._-]{1,100}$` and unique; a
  `url` is `https://` with a host and no user info, so no credential rides in the inventory; a
  repository named while the forge is off is refused.
- **The central forge's token** lies in the person's tresor as `porelo-host/forge-central.token`.
  Nothing here reads or writes it; when the forge is on, the dialog says where it must lie, and a
  refusal of the role for its absence is shown in the role's words.
