# F199 — A Host's Stop Fed From The File Without Typing

**Status:** Backlog; blocked by [F198](README.md#f198) and by `porelo-host`
[HO37](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho37).
**Size:** M - the stop's terminal in the host dialog, the certificate's signing in it, and their tests, on a
contract with `porelo-host`.

**What must be true.** At a host's stop, the person types the master password of `secrets.kdbx` once, in the
terminal the interface opens, and the host gets what its stop asks - its vault passphrase, its WireGuard key, the
keys for its vault - from the file, on standard input, without the person typing any of them (step 2 of the host's
new setup, before the upload of [F197](README.md#f197)). The drive's login is no longer among them: the drive leaves the setup ([F201](README.md#f201)). A secret
the file lacks is asked as today.

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
  `<need> [<name>] <value in base64>` (agreed with Machines for the host's side); the stop asks only what is
  missing. The needs are `vault` or `vault-new`, `keys` with `key <name>` lines, `wireguard` and
  `forge-certificate`; `drive` is not one of them (decided).
- **The forge's certificate is signed here (decided):** the host makes its key and sends only its request; the same
  terminal signs it with the CA key from the file and hands the certificate back, so the CA key never leaves the
  desktop. On the wire, as agreed with Machines: `ssh <admin>@<host> sudo porelo-host-stop --request` prints the
  waiting request as one PEM block (exit 65 when none waits); `openssl x509 -req -days 365` signs it with the CA key
  on a pipe from `keepassxc-cli`, setting every extension itself and copying none from the request
  (`subjectAltName=IP:10.73.0.1,DNS:forge.porelo.internal`, `basicConstraints=critical,CA:FALSE`,
  `extendedKeyUsage=serverAuth`, address and name from the inventory the interface wrote); the answer is the line
  `forge-certificate <base64 of the certificate's PEM, then the CA's>` in the `--stdin` pipeline.
- **The lasting CA is made once in that terminal:** `nameConstraints=critical,permitted;DNS:porelo.internal,
  permitted;IP:10.73.0.0/255.255.255.0`, `basicConstraints=critical,CA:TRUE,pathlen:0`, ten years, its key straight
  into `secrets.kdbx`.
- **Nothing written:** the entries pass through the pipe only, never into a file, argument, environment or log here
  or on the host; the terminal's own scrollback shows none.
- **Red first:** a test of the command the interface builds for the stop terminal: it names the entries and the host,
  and no secret value can appear in it, against a fixture file.

## Acceptance

- A host set up with the file and a drive holding only `machine.yml`: at the stop the person types the master
  password and sudo, nothing else, and the host's vault comes up.
- A file without the vault passphrase: the stop asks it as today.
- Seen to fail: the command test red against today's interactive stop.

## To be checked

- How one unlock yields several entries inside the pipe: `keepassxc-cli open`'s shell fed from the pipe, or
  `export` filtered to the named entries without a file; posted before anything changes.
- That the CA key reaches `openssl` only on a pipe, never as a file, also on the desktop's own temporary folder.
