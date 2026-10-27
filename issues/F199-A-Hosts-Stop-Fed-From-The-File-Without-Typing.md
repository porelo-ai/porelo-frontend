# F199 — A Host's Stop Fed From The File Without Typing

**Status:** Backlog; blocked by [F198](README.md#f198) and by `porelo-host`
[HO37](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho37).
**Size:** M - the stop's terminal in the host dialog, the central forge's token after `up`, and their tests, on a
contract with `porelo-host`.

**What must be true.** At a host's stop, the person types the master password of `secrets.kdbx` once, in the
terminal the interface opens, and the host gets what its stop asks - its vault passphrase, its WireGuard key, the
keys for its vault - from the file, on standard input, without the person typing any of them (step 2 of the host's
new setup, before the upload of [F197](README.md#f197)). The drive's login is no longer among them: the drive leaves the setup ([F201](README.md#f201)). A secret
the file lacks is said by its entry's name before anything is sent; the stop never prompts for one.

## Why

`porelo-project` [PJ51](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj51): today each of
these is typed at every `up`, and a new host has a new vault.

## Plan

- **Read in today's code:** *Needs you* → *Complete setup on the host* opens a terminal running ssh into
  `porelo-host-stop` on the host, which asks the e-mail, the Tresorit password and code, and the vault passphrase in
  turn; `HostSession.needs` names what the stop waits for.
- **The terminal's command becomes one pipeline on this desktop**, so the interface never holds a secret
  (decided): the master password is asked once by the packaged `keepassxc-cli`, whose entries go through the pipe to
  `ssh <admin>@<host> sudo porelo-host-stop --stdin NEED...`, one line per secret, `<need> [<name>] <value in
  base64>` (agreed with Machines for the host's side); the stop asks only what is missing. The needs are `vault` or
  `vault-new`, `keys` with `key <name>` lines and `wireguard`; `drive` is not one of them (decided), and `--email`,
  which belongs to `drive`, is refused with `--stdin` (exit 64). The forge's certificate is
  [F202](README.md#f202)'s, in sprint 6h.
- **The central forge's token is no need of the stop:** an `up` that reaches the migration of a repository from the
  central forge fails that step naming `forge-central-token`; the interface then sends it alone, `ssh <admin>@<host>
  sudo porelo-host-stop --stdin forge-central-token` with one line `forge-central-token <base64>`, from the file's
  `shared` group, and runs `up` again (decided: this issue takes the step).
- **Nothing written:** the entries pass through the pipe only, never into a file, argument, environment or log here
  or on the host; the terminal's own scrollback shows none.
- **Red first:** a test of the command the interface builds for the stop terminal: it names the entries and the host,
  and no secret value can appear in it, against a fixture file.

## Acceptance

- A host set up with the file and a drive holding only `machine.yml`: at the stop the person types the master
  password and sudo, nothing else, and the host's vault comes up.
- A file without an entry the stop needs: the terminal names the missing entry and sends nothing; a host's new vault
  passphrase is made into the file in that terminal before the pipe, so a first host needs no typed passphrase.
- Seen to fail: the command test red against today's interactive stop.

## To be checked

- How one unlock yields several entries inside the pipe: `keepassxc-cli open`'s shell fed from the pipe, or
  `export` filtered to the named entries without a file; posted before anything changes.
