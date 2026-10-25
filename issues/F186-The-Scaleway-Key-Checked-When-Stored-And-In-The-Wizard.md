# F186 — The Scaleway Key Checked When Stored And In The Wizard

**Status:** Implementing.
**Size:** M - `packages/porelo_host/bin/porelo_host.dart`, `packages/porelo_host/lib/src/scaleway.dart`, and `HostDialog` in `lib/src/ui/host_dialog.dart`.

**What must be true.** `porelo-host key set scaleway` checks the key's format before any network
call (refusing `SCW…` access keys and any non-UUID value), asks Scaleway once against the offers
endpoint, prints `accepted` or `refused by Scaleway: <message>`, and stores nothing on refusal.
`porelo-host key set scaleway --from-file FILE` reads the key from an owner-only regular file
(`SECRET_KEY` from `NAME=VALUE` lines, or the whole file content), strips surrounding whitespace and
the final newline, checks it the same way, and never echoes it. Step 1 of the server wizard (*Where
it is rented*) checks the kept Scaleway key before advancing to step 2.

## Plan

- **Where it is today.**
  - `_key` in `packages/porelo_host/bin/porelo_host.dart` (lines 146–187) supports only
    `porelo-host key set PROVIDER` (reading a line from the terminal) and
    `porelo-host key forget PROVIDER`. It accepts any non-empty string without checking whether it is
    a UUID or a `SCW…` access key, never calls Scaleway before writing to `SecretStore`
    (`packages/porelo_host/lib/src/secret_store.dart`), and has neither `--from-file` nor a
    non-interactive `key check` subcommand.
  - `ScalewayProvider` (`packages/porelo_host/lib/src/scaleway.dart`, lines 23–42 and 143–154)
    already queries `GET /baremetal/v1/zones/$zone/offers?name=EM-I220E-NVME` with `X-Auth-Token`
    during `up`, which is the first point today where a wrong key is noticed: after *Put it on a
    server*, once every step has been filled out.
  - In `HostDialog._steps` (`lib/src/ui/host_dialog.dart`, lines 668–682), step 1 (*Where it is
    rented*) has a synchronous `check:` (`_required([_scaleway, _account], ...)`) and no
    `beforeNext` callback, so the wizard advances to step 2 even when no Scaleway key is stored or
    the stored key is invalid.
- **Steps.**
  1. In `packages/porelo_host/lib/src/scaleway.dart`, add Scaleway key validation and live checking:
     - Format check before any network call: if the trimmed value starts with `SCW` (case-sensitive
       or uppercase prefix), refuse with `"that is the access key (SCW…); the secret key is a UUID"`;
       if it does not match the UUID pattern (`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`),
       refuse with `"that is not a secret key; the secret key is a UUID"`; either way make zero HTTP
       requests.
     - Live check: call `GET https://api.scaleway.com/baremetal/v1/zones/fr-par-1/offers?name=EM-I220E-NVME`
       with `X-Auth-Token: <key>` (read-only, creates nothing). On HTTP `2xx`, succeed (`accepted`).
       On HTTP `401` or `403`, refuse with `"refused by Scaleway: <message>"` (`Exit.refused`, code
       `65`). On network error or `5xx`, fail with `Exit.unreachable` (code `69`). Never include the
       secret key in any output, error, or exception string.
  2. In `packages/porelo_host/bin/porelo_host.dart`:
     - Extend `porelo-host key set scaleway` to support `--from-file FILE`: verify with
       `FileSystemEntity.type(..., followLinks: false)` that `FILE` is a regular file and on Linux
       that `(stat.mode & 0x3f) == 0` (owner-only, `mode & 077 == 0`), refusing otherwise (`Exit.refused`,
       code `65`); read the file, extract `SECRET_KEY`'s value if the file consists of `NAME=VALUE`
       lines (lines containing `=`) or take the whole content otherwise, and strip surrounding
       whitespace and the final newline (`\r?\n`).
     - In `porelo-host key set scaleway` (both interactive and `--from-file`), run the format check
       and the Scaleway offers check before calling `secrets.set('scaleway', value)`. On acceptance,
       store the stripped UUID, print `accepted`, and exit `0` (`Exit.done`); on refusal, store
       nothing, print the refusal on `stderr`, and exit `65` (`Exit.refused`) or `69`
       (`Exit.unreachable`).
     - Add non-interactive `porelo-host key check scaleway`: read the stored key from `SecretStore`
       (`secrets.get('scaleway')`), run the same format and Scaleway offers check, and exit `0`
       (`Exit.done`) when accepted, `65` (`Exit.refused`, with the reason on `stderr`) when no key is
       stored or Scaleway refuses it, or `69` (`Exit.unreachable`) when Scaleway cannot be reached.
  3. In `HostDialog._steps` (`lib/src/ui/host_dialog.dart`), add a `beforeNext` check on step 1
     (*Where it is rented*) that runs `porelo-host key check scaleway` (and in `HostKeyDialog` in
     `lib/src/ui/host_key_dialog.dart`, surface the acceptance or refusal after `key set`). When
     `key check scaleway` exits non-zero, stay on step 1, show the refusal message, and offer *Set
     Scaleway key* so the person fixes it before filling out the other steps.
- **Tests, their harm, red first.**
  - *Harm 1 (secret leakage):* a secret key read from a terminal or `--from-file` is echoed to
    `stdout`, `stderr`, or an exception message when a check fails.
    - In `packages/porelo_host/test/porelo_host_test.dart`, pass a sentinel secret string through
      `key set scaleway` and `key set scaleway --from-file` across every path (`SCW…`, non-UUID,
      401/403 refusal, network failure, bad file permissions, and 200 acceptance) and assert that
      neither `stdout` nor `stderr` ever contains the sentinel string. Break the error message to
      include the input value first and watch the test fail.
  - *Harm 2 (storing bad or unstripped keys, or reading world-readable files):* storing a key with a
    trailing newline or a `SCW…` access key causes renting to fail later with `401`, or `--from-file`
    reads a `0644` file readable by other users.
    - In `packages/porelo_host/test/porelo_host_test.dart`:
      1. Feed a valid UUID with a trailing `\n` via `--from-file` ( both plain and `ACCESS_KEY=...\nSECRET_KEY=<uuid>\n`
         formats) with a fake `ScalewayExchange` returning `200`, and assert the value stored in
         `SecretStore` has no `\n`.
      2. Feed `SCW12345...` and a non-UUID string, and assert zero HTTP calls are made to
         `ScalewayExchange`, exit code is `65`, and `SecretStore` remains empty.
      3. Return `401` from `ScalewayExchange` for a well-formed UUID, and assert exit code is `65`
         and `SecretStore` remains empty (or keeps its previous key unchanged).
      4. On Linux, pass a `--from-file` with mode `0644` and assert exit code is `65` before any
         HTTP call.
      Break each check first and watch the corresponding test fail.
  - Words, colors, and layout get no test.

## Acceptance

- `porelo-host key set scaleway` refuses a `SCW…` access key or non-UUID before contacting Scaleway,
  saying `"that is the access key (SCW…); the secret key is a UUID"`.
- For a UUID, `porelo-host key set scaleway` checks Scaleway's offers endpoint once, stores the key
  and prints `accepted` on `2xx`, and stores nothing and exits `65` with `"refused by Scaleway: ..."`
  on `401`/`403`.
- `porelo-host key set scaleway --from-file FILE` refuses a file that is not a regular owner-only
  file, extracts `SECRET_KEY` from `NAME=VALUE` lines or reads the whole file, strips whitespace and
  the final newline, and never prints the key on `stdout` or `stderr`.
- Step 1 of the server wizard runs `porelo-host key check scaleway` before advancing and blocks on a
  missing or refused key in step 1 instead of failing after *Put it on a server*.
