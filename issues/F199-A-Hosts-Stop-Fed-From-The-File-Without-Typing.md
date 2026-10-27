# F199 — A Host's Stop Fed From The File Without Typing

**Status:** Analyzed; blocked by [F198](README.md#f198) and by `porelo-host`
[HO37](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho37).
**Size:** M - the stop's terminal in the host dialog, the certificate's signing in it, and their tests, on a
contract with `porelo-host`.

**What must be true.** At a host's stop, the person types the master password of `secrets.kdbx` once, in the
terminal the interface opens, and the host gets what its stop asks - the drive's login, its vault passphrase, its
WireGuard key - from the file, on standard input, without the person typing any of them. Only the drive's one-time
code is still typed, at the host's own prompt. A secret the file lacks is asked as today.

## Why

`porelo-project` [PJ51](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj51): today each of
these is typed at every `up`, and a new host has a new vault.

## Plan

- **Read in today's code:** *Needs you* → *Complete setup on the host* opens a terminal running ssh into
  `porelo-host-stop` on the host, which asks the e-mail, the Tresorit password and code, and the vault passphrase in
  turn; `HostSession.needs` names what the stop waits for.
- **The terminal's command becomes one pipeline on this desktop**, so the interface never holds a secret
  (decided): the master password is asked once by the packaged `keepassxc-cli`, whose entries go through the pipe to
  `ssh <admin>@<host> sudo porelo-host-stop --stdin [--email ADDRESS] NEED...`, one line per secret,
  `<need> [<name>] <value in base64>` (agreed with Machines for the host's side); the stop asks only what is missing and the
  one-time code at its own prompt. The needs are `drive`, `vault` or `vault-new`, `keys` with `key <name>` lines,
  `wireguard` and `forge-certificate`.
- **The forge's certificate is signed here (decided):** the host makes its key and sends only its request; the same
  terminal signs it with the CA key from the file and hands the certificate back, so the CA key never leaves the
  desktop. The request's and the answer's form on the wire come from Machines.
- **Nothing written:** the entries pass through the pipe only, never into a file, argument, environment or log here
  or on the host; the terminal's own scrollback shows none.
- **Red first:** a test of the command the interface builds for the stop terminal: it names the entries and the host,
  and no secret value can appear in it, against a fixture file.

## Acceptance

- A host set up with the file: at the stop the person types the master password and the code, nothing else, and
  the host's drive and vault come up.
- A file without the vault passphrase: the stop asks it as today.
- Seen to fail: the command test red against today's interactive stop.

## To be checked

- How one unlock yields several entries inside the pipe: `keepassxc-cli open`'s shell fed from the pipe, or
  `export` filtered to the named entries without a file; posted before anything changes.
- With Machines: the certificate request's and answer's form, and that the stop never echoes or keeps what it reads.
- Whether one terminal can carry both the pipeline and the one-time code's prompt, or the code needs a second step.
