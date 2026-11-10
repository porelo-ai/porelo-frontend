# F146 — The Host's VM Pool Switched On

```json
{
  "$schema": "issue-1.json",
  "id": "F146",
  "title": "The Host's VM Pool Switched On",
  "state": "Idea",
  "size": "-",
  "priority": "Medium",
  "rank": 40,
  "blockedBy": [],
  "covers": "The host's pool of small test VMs switched on on `porelo_host` and in the host dialog, with its systems and accounts."
}
```

**What must be true.** A person bringing a host up chooses whether it runs a pool of small test VMs,
which systems and how many accounts, on `porelo_host`'s command line and in the host dialog.

## How it stands

`HostRun._inventoryVariables` in `packages/porelo_host/lib/src/host_run.dart` writes the v2 server
inventory with `porelo_host_name`, `porelo_host_network` and
`HostPreparationSettings.roleSettings` (`packages/porelo_host/lib/src/server_contract.dart`),
without `porelo_host_account` or `porelo_host_tresor`.
`packages/porelo_host/bin/porelo_host.dart` accepts neither `--tresor` nor the promised `--vm-pool`
options; `HostDialog` in `lib/src/ui/host_dialog.dart` has no VM pool choices.

## The shape

- **The first server inventory carries one more key**, as agreed with
  `porelo-host`: `porelo_host_vm_pool`, absent by default (no pool), else a
  JSON object `{"systems": ["ubuntu", "fedora"], "accounts": 4}`: `systems` a list of strings, each
  of `ubuntu` and `fedora` at most once; `accounts` an integer from `1` to `8` per system. Written
  by `HostRun._inventoryVariables(HostPlan)` in `packages/porelo_host/lib/src/host_run.dart`, left out
  when unset.
- **Set by the person** with `--vm-pool ubuntu,fedora` and `--vm-pool-accounts N` on `porelo_host`,
  and by the same two in the host dialog; both fill `HostPlan`.
- **Checked here before anything is written**: each system known and at most once, `accounts` `1` to
  `8`, `--vm-pool-accounts` refused without `--vm-pool`. The role's own refusal stays the second
  check.
- **Each pool account is one small VM**, reverted to its base snapshot after each run, on the host;
  nothing of that is the interface's.

## Acceptance

- Both `porelo_host` and the host dialog write `porelo_host_vm_pool` into `inventory.yml` with the
  chosen `systems` and `accounts`, and write no key when the pool is unset.
- Seen to fail: an unknown or repeated system, `accounts` outside `1` to `8`, or
  `--vm-pool-accounts` without `--vm-pool` is refused before anything is written, and never reaches
  the inventory.
