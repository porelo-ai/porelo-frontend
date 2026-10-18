# F128 — The Leased Machine Trusted By The Key Its Lease Names

**Status:** Backlog; blocked by
[BT11](https://github.com/porelo-ai/porelo-buildtools/blob/main/issues/README.md#bt11).
**Size:** S - one line in `tool/e2e.sh` in place of the keyscan, the leg refusing a lease without
the key, and one run of the leased leg.

**What must be true.** The integration leg reaches a rented machine only if it answers with the host
key its lease names, the one the run made for it. A machine that answers with any other key is not
reached, and the leg stops before it runs a test.

## Why

[BT11](https://github.com/porelo-ai/porelo-buildtools/blob/main/issues/README.md#bt11) gives every
rented machine a host key made per run on the runner, passed in the server's `user_data`, and has
the tools' `Ssh` accept that key only. This leg does not reach its machine through `Ssh`: the tools'
`lease` writes `build/leased.properties`, and `tool/e2e.sh` then speaks OpenSSH to the machine,
trusting whatever key it is handed first:

    ssh-keyscan -H "$address" >>~/.ssh/known_hosts

The interface refuses any other key after that, but the first one is taken on trust, so [BT11](https://github.com/porelo-ai/porelo-buildtools/blob/main/issues/README.md#bt11) closes
the gap for the tools and leaves it open here.

## Plan

- **The lease file** carries the host key's public half as [BT11](https://github.com/porelo-ai/porelo-buildtools/blob/main/issues/README.md#bt11) writes it, `hostkey=ssh-ed25519 AAAA…`,
  beside `address`, `user` and `socket`.
- **`tool/e2e.sh`** writes `<address> <that key>` into `~/.ssh/known_hosts` in place of the keyscan,
  and stops with a message naming the lease file when the key is missing or empty.
- **Nothing in the interface changes:** it already refuses a host whose key is not known.

## Acceptance

- **A leased run** reaches its machine with no keyscan, green in the Build's leased leg.
- **A lease file without the key** stops the leg before it reaches the machine, saying so; run once
  by hand with the line removed.
- **A wrong key** in the lease file stops the leg at its first ssh, before a test; run once by hand
  with another key put in.
