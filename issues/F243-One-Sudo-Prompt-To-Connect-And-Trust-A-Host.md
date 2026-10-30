# F243 — One Sudo Prompt To Connect And Trust A Host

**Status:** Accepted.
**Size:** M - the own VPN and the host's CA set up by one privileged run that checks the CA itself, so the person types sudo once.

**What must be true.** A bring or a join on a machine with no record of the host asks for the sudo password once. One privileged run brings this machine's VPN to the host up and fetches the host's CA through it. It checks the CA's SHA-256 against `ca_sha256` from the pasted host values itself and installs the CA only on a match. On a mismatch it takes the VPN down again and changes nothing, saying both fingerprints.

## Why

Operator's finding in walk 23, Step 7 of 7 of *Put walk6-demo on a server* on VM A (2026-10-30): *Connect this laptop to walk9server* and *Connect and trust walk9server* each open a terminal and ask for the same sudo password; one prompt is wanted. Today `lib/src/ui/own_host_vpn.dart` runs the VPN twice ([F232](README.md#f232)): first without a CA, then the CA is fetched over ssh in the person's own account and checked in the interface, then the VPN is set up again with the CA.

## Plan

- One generated script, run once with sudo in one terminal, does in order:
  1. brings the VPN up and checks a fresh handshake;
  2. reads the host's CA certificate through the VPN;
  3. compares its SHA-256 with the `ca_sha256` given to it as an argument (a public digest, no secret);
  4. on a match only, installs it as today's VPN step does, into the system store and Firefox's policy;
  5. on a mismatch, takes the VPN down, removes what it wrote, and exits with both fingerprints.
- The CA is read as the invoking user, inside the same script: `runuser -u "$SUDO_USER"` with the person's pinned ssh options and `known_hosts` from the pasted `ssh_host_key`. The private key never reaches root's environment. Should Agent Machines' host serve the CA in its TLS chain at `forge.<host>.porelo.internal:3000`, reading it there with `openssl s_client` replaces the ssh fetch. The digest check is the same either way.
- The interface records the host only after the script's success, as today.
- **Red first:** a test that the generated script installs the CA only after its own digest check and takes the VPN down on a mismatch; a widget test that a first bring opens one sudo terminal, not two.

## Test

Only the change: the tests above, the generated script run against a stand-in `wg-quick`, `ssh` and CA stores in a scratch root, and the bring and join dialogs' own tests. The VM test covers only the first bring's connect step on one VM.
