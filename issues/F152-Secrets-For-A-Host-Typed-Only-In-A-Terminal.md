# F152 — Secrets For A Host Typed Only In A Terminal

**Status:** Idea.

**What must be true.** The interface takes no secret into a form of its own; a secret is typed into
a terminal on the machine it is for. When `porelo-host up` stops for the drive login or a new
vault's passphrase, the interface opens an ssh terminal on the host where `tresorit-cli login` and
`porelo vault init` or `unlock` ask for the secret, and runs `up` again after.

## Why

[F135](README.md#f135) asks for the Tresorit login and the vault passphrase in the host dialog's
own form and pipes them to `porelo-host up` on standard input. That puts secrets into the
interface's widgets and misses Tresorit's second-factor prompt, which
`tresorit-cli login --email <e-mail> --password-on-stdin` asks in the terminal after the password.

## Acceptance

- At the host stop for `drive` or a new vault, the interface opens an ssh terminal to the host with
  the pinned host key and setup identity, runs `tresorit-cli login` and `porelo vault init` or
  `unlock` there, and runs `porelo-host up` again once the terminal step succeeds.
- Seen to fail: no form field in the host dialog takes a password, second-factor code or vault
  passphrase, and no secret is sent on `porelo-host`'s standard input.

## Open questions

- Whether porelo's `vault init` and `vault unlock --passphrase-stdin` stay, for a host nobody sits
  at, once no interface feeds them from a form.
