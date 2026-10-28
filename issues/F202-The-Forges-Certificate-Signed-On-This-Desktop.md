# F202 — The Forge's Certificate Signed On This Desktop

**Status:** Review; the signing at the stop, the CA kept and trusted here, and its warning published 2026-10-28
(Build green on `46deaa8`), not yet run on a rented host. **Split:** the lasting forge password is no part of this
issue any more; it moved to [F212](README.md#f212), set at each person's first start in [F213](README.md#f213) and
[F216](README.md#f216), as `porelo-project` [PJ78](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj78) decided. What [PJ78](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj78) changes in what is built here (nothing
reworked yet): one CA per host, constrained to its own names and network, as [F212](README.md#f212).
**Size:** L (grown from M once `porelo-host`
[HO35](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho35) was read: the password call, the VPN's
root step and the CA's warning) - a second step in the stop's terminal, the CA made once into the file, and their tests, on a contract
with `porelo-host`.

**What must be true.** Once the host's VPN is up, the person opens its forge in the browser with no warning and
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
- **Built, this desktop trusting the CA:** the stop's script writes the CA's certificate, public, into a private
  temporary folder the dialog names; after a stop that ended well the interface keeps it (`Settings.forgeCa`, one
  certificate in PEM or nothing) and the folder goes. The VPN's root step, given that certificate: puts it into the
  system store (`/usr/local/share/ca-certificates/porelo-host.crt` and `update-ca-certificates`, or Fedora's
  `/etc/pki/ca-trust/source/anchors/` and `update-ca-trust`), a copy into `/etc/firefox/porelo/porelo-host.crt` and a
  `policies.json` naming it where none is there (one of the person's own is left alone, and said), and the line
  `10.73.0.1 forge.porelo.internal # porelo-host` into `/etc/hosts`; each only where it is not there already.
  Taking the VPN down takes that line out again, and nothing else. Seen with stand-in tools and the real
  `install`, `cmp` and `grep`, every path moved into a scratch folder.
- **From the harm reading of both (twelve findings, eleven taken):** the root step reads no file of the person's any
  more: the certificate is its argument, checked here and again as root (one PEM block, base64 lines) in a folder of
  root's own, before the receipt is written; a store whose update fails is taken back and tried again on the next
  `up`; a machine with neither store is told so. `policies.json` is written only where neither a file nor a link is
  there, through a temporary file beside it. The hosts line goes onto a line of its own and the file is changed in
  place, so its owner, mode and label stay; *down* takes out that exact line, by a root step of its own with a fixed
  `PATH`. A kept certificate is refused unless it is one PEM certificate whose body decodes, and the stop's folder
  goes also where the command could not be built. **Declined, with the reason:** a Flatpak Firefox reads no policy
  under `/etc`, so it cannot be reached from the root step; a policy of the person's own is said, never changed.
- **From the reading of that fix (twelve findings, nine taken):** root's check of the certificate now wants a body,
  lines no wider than 76 in ASCII, and a body `base64 -d` decodes; root's temporary files are made in `/tmp` by name,
  never in a `TMPDIR` kept through `sudo`; the line break before the hosts line is checked; *down* leaves `/etc/hosts`
  as it is where its copy without the line was not written, and goes on a signal. Tests now see each part of root's
  check on its own, no store at all, a link to the policy said, a link at a staging name known in advance not
  followed, and *down*'s own `PATH`. **Declined, with the reasons:** a padded line of 78 passes the pattern here, but
  its body never decodes, so it is refused all the same; a step that fails after the store took the CA leaves what it
  put in place, each piece of which the next start finds there or puts in again, since nothing of it is the person's;
  the stop dialog's last catch has no error to test it with, as building the command throws only the two it names.
  `LC_ALL=C` stays in root's check although this computer's `grep` refuses a non-ASCII letter without it.
- **Built, the CA's warning:** the end of the kept certificate is read from its DER (`certificateEnds`, UTCTime and
  GeneralizedTime, compared with what `openssl` reads); from 90 days before it, and after it, the VPN's start and a
  stop that signs the forge's certificate say when it ends and what to do: remove `shared/forge-ca` and
  `shared/forge-ca-key` from the secrets file, and the next stop makes a new CA, which the next VPN start trusts in
  place of the old. A server set up before keeps a certificate of the old one until it is set up again, and the
  warning says so.
- **From the warning's harm reading (seven findings, six taken, one in part):** every element of the certificate is
  read inside its parent, the end must be the validity's last, nothing may follow the certificate, and a month 13 or
  a minute 61 is refused rather than rolled into a later date; the warning names the hour in UTC, says that a server
  set up before is not trusted here until it is set up again, and, at the stop, that this stop makes the new CA
  where the entries are gone; the stop's text has no trailing space. Tests now build certificates by hand for each
  form and each refusal, independent of today's date; beside them, one compares with what `openssl` reads from
  certificates it makes now. Its reading found nothing in the code; it gave the case of a validity outside its part
  and of 30 February. **Declined, with the reason:** fractional seconds and an
  offset in place of `Z` are refused, not read: RFC 5280 forbids both in a certificate's validity, and `openssl`
  writes neither.
- **For sprint 6h:** every host's first inventory says `porelo_host_forge: true`
  (`HostPlan.forge`, on by default), so its forge runs and its stop asks for `forge-certificate`; switching it off
  in the dialog is [F145](README.md#f145)'s.
- **Split off:** the lasting forge password (typed into the file once, then piped into
  `porelo-host-forge-password`) is [F212](README.md#f212)'s, at each person's first start.

## Acceptance

- After the VPN, `https://forge.porelo.internal/` opens with no certificate warning: no hosts line or CA import by
  hand, and the CA's key never reached the host. Signing in with the lasting password is [F212](README.md#f212)'s.
- A second host needs no new CA in the browser; a certificate for another name signed by the CA fails `openssl verify`.
- Seen to fail: the command test red before the signing step exists.

## To be checked

- **Measured on this desktop (2026-10-28, read only):** Firefox is the snap (158.0.1, rev 9113), whose AppArmor profile
  (`/var/lib/snapd/apparmor/profiles/snap.firefox.firefox`) lets it read `/etc/firefox/**` and nothing of
  `/usr/local/share/ca-certificates` or `/etc/ssl`. So `policies.json`'s `Certificates.Install` names a copy of the CA
  under `/etc/firefox` (e.g. `/etc/firefox/porelo/porelo-host.crt`), beside the system store's
  `/usr/local/share/ca-certificates/porelo-host.crt` that `update-ca-certificates` reads; a path under
  `/usr/local/share` would not be read by the snap.
- On Fedora: the system store's `/etc/pki/ca-trust/source/anchors/` with `update-ca-trust`, and where the packaged
  Firefox reads its policy; not measurable here.

- That the CA key reaches `openssl` only on a pipe, never as a file, also on the desktop's own temporary folder.
