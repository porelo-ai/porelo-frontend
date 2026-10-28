# F199 — A Host's Stop Fed From The File Without Typing

**Status:** Review; published 2026-10-27 with [F198](README.md#f198) and `porelo-host`
[HO37](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho37), not yet run on a rented host.
**Size:** L - the stop's terminal in the host dialog, the central forge's token after `up`, the vault entries' files
moved into the secrets file, and their tests, on a contract with `porelo-host` (grew from M once the entries' files
had to move, agreed with Machines).

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
- **The call, agreed with Machines:** `sudo` on the host asks nothing, since the rented image's login user has
  passwordless sudo, as `up` relies on; so the call needs no `-t`, and the only password typed is the master
  password, here. A `key <name> <value>` line carries the base64 of the whole file the person chose for that vault
  entry, `<name>` as `machine.yml`'s `keys` names it; the host pipes the bytes into `porelo vault put <name>`.
- **The vault entries' files move into the secrets file:** a file chosen on *The drive* for a vault entry is no longer
  copied to the drive but taken into `hosts/<project>/keys/<name>` by the secrets file's script (its bytes base64 in
  the entry's password field), and fed from there as a `key` line.
- **Later needs:** the project store's address and keys of `porelo-host`
  [HO07](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho07) join the stop's lines once that
  issue is built, not in sprint 6e (decided).
- **Nothing written:** the entries pass through the pipe only, never into a file, argument, environment or log here
  or on the host; the terminal's own scrollback shows none.
- **Red first:** a test of the command the interface builds for the stop terminal: it names the entries and the host,
  and no secret value can appear in it, against a fixture file.
- **From its harm reading (eight findings, all taken):** the `keys` lines are the entries `machine.yml` names, kept
  by name in the setup's record, never every entry of the file's group; a need list that is empty, or names `vault`
  with `vault-new`, is refused. `ssh` runs by its path, the far end's call is `/usr/bin/sudo -n` without a login
  shell, whose profile would run with the pipe on its standard input, and the host and the drive's login are checked
  as a user at an address. Echo is off on this desktop before the drive's login connects. Every value is checked as
  whole base64 and encoded before the first line goes. The secrets file's script checks everything (vault entry
  files reached through no link, with content; an entry kept with other bytes; the drive's key) before its first
  change, and removes the drive's key last. A refusal of `up` that asks on its own call (`forge-central-token:`,
  `keys:`) waits under *Needs you* behind *Complete setup on the host*, as the user that refusal names (after a restart *Go on* runs `up`, which refuses the same way); Start opens
  the secrets file and names it with no drive folder too.
- **From the reading of those fixes (ten findings, nine taken):** echo stays on for the drive's login, since ssh
  hands this terminal's modes to the far end's and the e-mail typed there would not show, and goes off before the
  file is opened; `keys` with no entry named is refused but beside `vault-new`; an empty value or encoding is no
  base64; a kept host key that is none, or an empty entry, is refused before any change; *The drive* refuses an empty
  vault entry file and one in a folder reached through a link, as the script does; with host files given by hand the
  file gives no VPN key, as those files carry the person's own. **Declined, with the reason:** the feed's own exit
  trap turns echo back on while `ssh -T` still runs, but nothing reads this terminal then.

- **What `porelo-project` [PJ78](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj78) changes (nothing reworked yet):** the stop is fed by act: the host admin's root stop takes only the VPN key and the forge's certificate; a project admin's bring and a developer's join take their vault, keys and tokens in their own account, with no `sudo`; built as [F214](README.md#f214).

## Acceptance

- A host set up with the file and a drive holding only `machine.yml`: at the stop the person types the master
  password and sudo, nothing else, and the host's vault comes up.
- A file without an entry the stop needs: the terminal names the missing entry and sends nothing; a host's new vault
  passphrase is made into the file in that terminal before the pipe, so a first host needs no typed passphrase.
- Seen to fail: the command test red against today's interactive stop.

## To be checked

- How one unlock yields several entries inside the pipe. Measured with the snap's `keepassxc.cli` 2.8.0 on a
  probe file in a plain folder of the home: `open` takes the password from the pipe but runs no command from it
  (its prompt needs a terminal); `export -f csv` after one unlock prints every entry with its group path, whose root
  is the localized root group's name (`Passwörter/shared`), so a filter matches on the path below the root. Still to
  settle: what filters the CSV to the named entries and turns them into the stop's lines without holding the whole
  export anywhere but the pipe, posted before anything changes.
