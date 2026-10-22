# F146 — The Host's VM Pool Switched On

**Status:** Idea; blocked by `porelo-host` [HO12](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho12).

**What must be true.** A person bringing a host up chooses whether it runs a pool of small test VMs,
which systems and how many accounts, on `porelo_host`'s command line and in the host dialog.

## The shape

- **The first inventory carries one more key beside `porelo_host_account`**, as agreed with
  `porelo-host` for [HO12](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho12): `porelo_host_vm_pool`, absent by default (no pool), else a
  JSON object `{"systems": ["ubuntu", "fedora"], "accounts": 4}`: `systems` a list of strings, each
  of `ubuntu` and `fedora` at most once; `accounts` an integer from `1` to `8` per system. Written
  by `_inventory(HostPlan)` in `packages/porelo_host/lib/src/host_run.dart`, left out when unset, as
  `porelo_host_tresor` is.
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
