# F202 — The Forge's Certificate Signed On This Desktop

**Status:** Implementing; the signing at the stop built. A host set up from here runs no forge until the interface
writes `porelo_host_forge` ([F145](README.md#f145)), asked of the Coordinator (2026-10-28); until then nothing of
this issue is reached on a rented host.
**Size:** L (grown from M once `porelo-host`
[HO35](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho35) was read: the password call, the VPN's
root step and the CA's warning) - a second step in the stop's terminal, the CA made once into the file, and their tests, on a contract
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

- **Built, the signing at the stop:** where the host names `forge-certificate`, the stop's terminal asks it for the
  request (`ssh <admin>@<host> sudo -n porelo-host-stop --request`, no input) before the file is opened. The file's
  script makes the lasting CA once where neither `shared/forge-ca-key` nor `shared/forge-ca` is there (EC P-256, ten
  years, the name constraint, `CA:TRUE,pathlen:0`), refuses where only one is, checks the request's own signature, and
  signs it with `-subj /CN=forge.porelo.internal`, the three extensions and a random serial, every input on a pipe;
  the line is `forge-certificate <base64 of the forge's certificate, then the CA's>`. Seen against the real
  `keepassxc-cli` and `openssl`: no file is made, nothing of the request but its key counts, a second host gets the
  same CA, and no request sends nothing.
- **Still to build:** the lasting forge password (typed into the file once, then piped into
  `porelo-host-forge-password` after `up`); the VPN's root step (the hosts line, the CA in the system store and in
  Firefox's policy, each only where missing); the warning 90 days before the CA ends.

## Acceptance

- After the VPN, `https://forge.porelo.internal/` opens and signs in with the lasting password: no hosts line, CA
  import or password file by hand, and the CA's key never reached the host.
- A second host needs no new CA in the browser; a certificate for another name signed by the CA fails `openssl verify`.
- Seen to fail: the command test red before the signing step exists.

## To be checked

- That the CA key reaches `openssl` only on a pipe, never as a file, also on the desktop's own temporary folder.
