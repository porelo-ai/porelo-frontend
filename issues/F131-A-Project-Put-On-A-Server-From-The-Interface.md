# F131 — A Project Put On A Server From The Interface

**Status:** Idea.

**What must be true.** A person runs `host up` and `host down` from the interface as from the command
line, and sees how far it has got. When `up` stops for the vault, the interface asks for the
passphrase and opens it, so no step needs a terminal. The interface calls the same commands and does
no step of its own; the passphrase is never written to a file on the host, the drive or this computer.

## Why

[PJ40](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj40) puts a whole
project on a server with one command. The operator's requirement adds the interface as a way to
run it, for a person who does not use a terminal.

## What the interface needs from the commands

Named here so the commands can be shaped for it; the plan comes when this is accepted.

- **Progress a program can read:** each step started, done or refused, as one line of a fixed form
  (or JSON), on the command's output, with the step's name and, on a refusal, the command that fixes
  it. Text meant for a person stays beside it, not instead of it.
- **The point where `up` waits for the vault, said as such:** a line naming the host and the account
  whose vault waits, and an exit code of its own, so the interface knows to ask rather than to show
  a failure.
- **Resuming after it:** a second `up` that takes what is done as done and goes on from the vault, as
  the playbook's second play does; the interface runs it after the vault is open.
- **The passphrase without a file:** the interface writes it to the standard input of an ssh that runs
  `porelo vault unlock` on the host, from its own memory; nothing on the host, the drive or this
  computer holds it. `--passphrase-command cat` does not serve, measured by Core: porelo gives that
  command a pipe of its own, closed at once, so the ssh's input never reaches it. It needs `vault
  unlock` to read the passphrase from its own standard input, such as a `--passphrase-stdin`, which is
  porelo's change and the operator's to decide.
- **The drive's login at the same stop:** `up` stops once, for the Tresorit login and the vault
  together, so the interface must take the login too, or the person needs a terminal after all.
  Believed possible, not measured: `tresorit-cli login --email <address> --password-on-stdin` reads the
  password from standard input, by Tresorit's documentation as Agent Machines read it. What a second
  factor on the account asks for is not known; both are measured at the first real `up`.
- **`down`** reports the same way, its last copy of the list into the project's store included, and
  says when the host is gone.

`host up` and `host down` run on the person's computer, on Linux, Windows and macOS, as
`porelo-machines` commands, never as `porelo`'s, since Porelo does not run there yet and does not run
on Windows or macOS at all; so the interface starts them as local programs. The host is rented from
Scaleway Elastic Metal. The playbook runs on the host itself: `host up` copies the collection and the
inventory over ssh, installs `ansible-core` there and runs it locally, so the person's computer needs
only ssh and `host up`, no Ansible and no podman. Neither command exists yet: porelo-machines has only
`lease` and `sweep` today, as a jar; how it reaches the person's computer is the operator's to decide.
