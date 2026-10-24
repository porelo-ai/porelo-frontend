# F152 — Secrets For A Host Typed Only In A Terminal

**Status:** Estimated.
**Size:** M - the stop in `porelo-host` and in the dialog, a terminal, the walk's stand-in.

**Order.** The first of the host flow's issues ([F152](README.md#f152), [F154](README.md#f154) to
[F157](README.md#f157)), after the stand-ins of [F162](README.md#f162).

**What must be true.** The interface takes no secret into a form of its own; a secret is typed into
a terminal on the machine it is for. When `porelo-host up` stops for the drive login or a new
vault's passphrase, the interface opens an ssh terminal on the host. At `drive` it runs Tresorit's
own `tresorit-cli login`, which asks for the password and then the one-time code by its own
prompts; a new vault's passphrase is set by `porelo vault init` in that terminal. Then `up` goes on.
The host dialog's fields for them go.

## Why

The host dialog asks for the Tresorit login and the vault passphrase in its
own form and pipes them to `porelo-host up` on standard input. That puts secrets into the
interface's widgets and misses Tresorit's second-factor prompt, which
`tresorit-cli login --email <e-mail> --password-on-stdin` asks in the terminal after the password.

## Plan

- **Today**, read in the code: at the stop, `porelo-host up` (`packages/porelo_host`) ends 75 with a
  `person` line naming only `needs`; the dialog (`host_dialog.dart`, `_askForTheStop`) asks the
  e-mail, password, one-time code and passphrase in its own fields, and `HostSession.resume` writes
  them as JSON on the standard input of `up --answers-on-stdin`, whose `_answer` pipes them into
  `tresorit-cli login --password-on-stdin` and `porelo vault init|unlock --passphrase-stdin` over ssh.
  The interface does not know the host's address at the stop: only the `up` and `give-back` lines
  carry one.
- **`porelo-host`:** the `person` line carries `address` and `account`, fields `Step` already
  has. `--answers-on-stdin`, `Answers` and `_answer` go; an option left over is refused as unknown
  (64). A second `up` goes on by itself once the person has done the step on the host: the play
  only reads `tresorit-cli -p status` and `porelo vault status` as the account and never logs in
  or opens anything, so it passes the stop once both are done, the vault still open.
- **The stop in the dialog:** the fields go. It says what the host needs and offers one button,
  *Open a terminal on the host*, which runs `runInATerminal` (`unlock_terminal.dart`) on a machine
  made for that moment and never stored: kind `host`, `account@address` from the `person` line,
  the dialog's setup identity, so `pinnedHostSshOptions` pins the key `up` trusted. Its command,
  in the account's login shell with `XDG_RUNTIME_DIR` set, is one terminal with only what the
  stop names: `tresorit-cli login` for `drive`, `porelo vault init` for `vault-new`, `porelo vault
  unlock` for `vault`, joined by `&&`. The
  e-mail is checked against an address's form and quoted, never spliced.
- **Tresorit's own login, measured** with client 3.5.1300.4870 in a VM account, the credentials
  typed by the operator: `--email` and a password option are compulsory, so the command is
  `tresorit-cli login --email <e-mail> --password-on-stdin`, the e-mail taken in the dialog, which is
  no secret. In a terminal it asks `Password:` without echo, then `Enter your one-time password: `
  when the account has a second factor, **and that code shows as it is typed**. A login that
  succeeds prints nothing, and `tresorit-cli -p status` then names the e-mail under `Logged in as:`;
  `logout` prints nothing and the field reads `-` again.
- **So the terminal says what it does:** before the login, that the one-time code will show on the
  screen; after each command, one line of what came of it and what comes next ("Logged in to
  Tresorit; the vault comes next"), so a silent success does not leave a bare prompt. When the terminal is put away, the dialog runs `up` again, and what that says is the
  answer; nothing is concluded from the terminal's own end.
- **The walk:** [F162](README.md#f162)'s stand-in `ssh` gains its `-t` form, running a stand-in
  that asks as `tresorit-cli` and `porelo vault` do and writes nothing of what is typed.
- **Tests, their harm, red first:** a secret in the interface: no field of the stop takes a
  password, code or passphrase, and `up` is started with nothing on its standard input (today the
  answers go there). A command that does the wrong thing: an e-mail carrying a quote is refused, not
  run. `porelo-host`: the `person` line names address and account, and `--answers-on-stdin` ends 64.
  The review is Codex `xhigh`: it handles secrets.

## Acceptance

- At the host stop for `drive` or a new vault, the interface opens an ssh terminal to the host with
  the pinned host key and setup identity, runs `tresorit-cli login` and `porelo vault init` or
  `unlock` there, and runs `porelo-host up` again once the terminal step succeeds.
- Seen to fail: no form field in the host dialog takes a password, second-factor code or vault
  passphrase, and no secret is sent on `porelo-host`'s standard input.

## To be checked

- Nothing in this repository calls `porelo vault init` or `unlock --passphrase-stdin` once this
  is built; porelo documents `--passphrase-stdin` as for automation only.
