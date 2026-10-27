# F201 — The Person's Own Drive Mounted In Their Account

**Status:** Backlog; blocked by [F197](README.md#f197) and `porelo-host` [HO38](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho38).
**Size:** M - the host dialog's per-user setup, the kept run, and their tests; the drive roles are `porelo-host`'s.

**What must be true.** The drive leaves the host's setup (step 4 of its new setup): a host comes up with no drive
and no Tresorit login, unless the person chooses a personal drive for their own data. That drive is mounted in the
person's own account on the host, never in Porelo's, where the tasks run, and it is optional.

## Why

The operator's decision (2026-10-27): with the setup files uploaded ([F197](README.md#f197)) and every secret from
`secrets.kdbx` ([F199](README.md#f199)), the drive is no longer a step of the host's setup, and is again what it was
first meant to be, the person's own.

## Plan

- **The wizard:** *The drive* becomes an optional step of the per-user setup: none, or a tresor (later a folder on
  another drive) for the person's data, kept per host in the kept run.
- **At `up`:** with no personal drive, no Tresorit login is asked and nothing is synced; with one, its login is
  asked in the person's terminal at the stop, and it is mounted in the person's account.
- **The person's account is the admin account** the interface already logs in as over ssh (agreed with Machines):
  it exists before `up`, holds the person's own ssh session for the drive's login, and is never Porelo's account,
  so Porelo's tasks cannot read the drive; `up` gives it the linger Tresorit's daemon needs.
- **Red first:** a test that `up` without a personal drive names no drive need, and one that a chosen drive is
  given as the person's, never as Porelo's.

## Acceptance

- Rented without a drive: only the master password and sudo are typed, and the setup comes up.
- Rented again with a personal drive: it is mounted in the person's account and never in Porelo's.
- Seen to fail: the first test red against today's setup, which always mounts the drive.

## To be checked

- With Machines: how the per-user drive is named to the host, and what `down` waits for.
