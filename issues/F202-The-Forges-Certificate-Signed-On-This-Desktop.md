# F202 — The Forge's Certificate Signed On This Desktop

**Status:** Backlog; blocked by [F199](README.md#f199) and `porelo-host`
[HO35](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho35).
**Size:** M - a second step in the stop's terminal, the CA made once into the file, and their tests, on a contract
with `porelo-host`.

**What must be true.** Once the host's VPN is up, the person opens its forge in the browser and signs in, with
nothing done by hand: the host's certificate is signed on this desktop by the lasting CA kept in `secrets.kdbx`, so
the CA's key never reaches the host, and a second host needs no new CA in the browser (step 5 of the host's new
setup).

## Why

Split from [F199](README.md#f199) (decided): the host takes `forge-certificate` only from `porelo-host`
[HO35](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho35), in sprint 6h, so that issue is tested
whole in 6e.

## Plan

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
- **Nothing written:** the CA key passes from `keepassxc-cli` to `openssl` on a pipe only, never into a file,
  argument, environment or log here or on the host.
- **Red first:** a test of the command the interface builds for the signing step: it names the request, the entry and
  the extensions, and no key or certificate value can appear in it, against a fixture file.

## Acceptance

- After the VPN, `https://forge.porelo.internal/` opens and signs in with the lasting password: no hosts line, CA
  import or password file by hand, and the CA's key never reached the host.
- A second host needs no new CA in the browser; a certificate for another name signed by the CA fails `openssl verify`.
- Seen to fail: the command test red before the signing step exists.

## To be checked

- That the CA key reaches `openssl` only on a pipe, never as a file, also on the desktop's own temporary folder.
