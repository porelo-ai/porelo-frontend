# F37 — Reach A Machine Without An ssh Binary

**Status:** Analyzed; blocked by the operator: a mobile client.
**Size:** L - one transport interface over the forward, the trial and the terminal, a `dartssh2`
implementation with its own host key store and keychain, and a leg against a real machine; its
questions decided first. A mobile client itself is not in it, and waits for the operator.

**What must be true.** A person reaches a machine from a device without an `ssh` binary, such as a
phone, and the machine is trusted, authenticated and supervised to the same standard as from the
desktop.

## Why

Every connection runs OpenSSH's `ssh` as a process (see *The interface raises and supervises its
own ssh forward* in [decisions](../doc/decisions.md)): the forward to the daemon
(`lib/src/app/tunnel.dart`), starting the daemon and `id -u` for the connection trial, and working
in a task by hand (`lib/src/app/session.dart`). That inherits the person's `~/.ssh/config`,
ssh-agent, `known_hosts` and hardware keys, and nothing in `lib/` holds a private key. iOS and
Android have no `ssh` binary.

[`dartssh2`](https://pub.dev/packages/dartssh2) 4.1.0, read in its source and not run against a
server, has forwarding to a Unix socket as a byte stream, exec, shell and pty, jump hosts by hand,
host key verification as a callback (any key is accepted without it), custom asynchronous signers,
current keys, ciphers and strict key exchange, on every platform, pure Dart, MIT. It has no client
for a running ssh-agent, no `~/.ssh/config` or `known_hosts`, no FIDO keys or certificates and no
post-quantum key exchange. It changes fast, with breaking releases, and 4.0.0 fixed real security
defects.

A mobile client is more than a transport: a phone ends connections in the background, clearance
questions have deadlines, and notifications need another path.

## The shape

- **`dartssh2` beside `ssh`, never instead of it.** One transport interface with two
  implementations: the desktop keeps `ssh`, a mobile client uses `dartssh2`.
- On a mobile client the interface owns what OpenSSH did: host key trust with its own known-hosts
  store and a first-contact question, key import or generation with a passphrase, storage in the
  platform keychain.
- `VarlinkConnection` accepts any byte stream instead of only `Socket.connect(socketPath)`.

## Plan

- **Already there:** `VarlinkConnection.over` (`lib/src/wire/varlink_connection.dart`) speaks
  over any byte stream, and `Backend.open` (`lib/src/client/sokar_client.dart`) uses it for a
  `relay` command, proven by `test/client/relay_test.dart` through a process. A test over an
  in-memory stream, with no process and no socket file, is still missing.
- **Where `ssh` runs today:** `Tunnel` and `Tunnels` (`lib/src/app/tunnel.dart`, `ssh -L`);
  `tryAMachine` (`lib/src/app/connection_trial.dart`) through `Tunnels.trial`; `Session.command`
  (`lib/src/app/session.dart`, `ssh -t … sokar task attach`), opened as a `SessionChannel`
  (`lib/src/app/pty.dart`).
- **One transport interface:** a byte stream to the daemon, a command run there (starting the
  daemon, `id -u`), and a `SessionChannel` with a pty. The desktop's implementation wraps today's
  code unchanged; `Machine` (`lib/src/app/machines.dart`) says which one a machine takes.
- **The `dartssh2` implementation:** `onVerifyHostKey` always set, against a known-hosts store of
  its own kept owner-only; keys in the platform keychain through `flutter_secure_storage`, as
  `PlatformDeviceKeyStore` (`lib/src/app/keystore.dart`) keeps a device's; the stream to the
  daemon through `sokar daemon connect` or a forward to the Unix socket.
- **Red first:** a test in `test/client/` speaking Varlink over an in-memory stream; then tests
  with an unknown and a changed host key against a fake server; then a leg in `tool/e2e.sh` over
  `dartssh2`.

## Acceptance

- **One transport interface** covers the forward to the daemon, starting it, `id -u` and a pty
  session, and the desktop behaves exactly as before. Seen to fail: the existing scenarios and
  integration legs of the desktop.
- **`VarlinkConnection` speaks over a stream**, and the socket path is only one way to get one.
  Seen to fail: a test that speaks Varlink over an in-memory stream without a socket file.
- **No connection without a host key decision**: an unknown key is asked about with its
  fingerprint, a changed key refuses the connection, a remembered key is stored owner-only;
  `onVerifyHostKey` is never null and `disableHostkeyVerification` is never set. Seen to fail: tests
  with an unknown and a changed host key, and a check of the store's file mode.
- **A private key never leaves the platform keychain unencrypted, and nothing logs a secret.** Seen
  to fail: a test that reads the log and the stored files after a connection and finds no key or
  passphrase.
- **The `dartssh2` transport is exercised against a real machine** in the integration legs, not
  only against a fake. Seen to fail: an integration leg over `dartssh2` that connects, forwards and
  opens a pty.

## Open questions

- **How keys reach a phone**: generated there and authorized on the machine, or imported, and
  whether hardware-backed keys (Secure Enclave, StrongBox) are required through
  `SSHIdentity.custom`. (the operator's)
- **Whether a connection without post-quantum key exchange is acceptable** for a mobile client.
  (the operator's)
- **Which mobile platform first**, and the client beyond the transport (connections ended in the
  background, deadlines, notifications) as issues of its own. (the operator's)

## To be checked

- **How a pinned `dartssh2` is kept current**, given how fast it changes and how recent its
  security fixes are. (Agent Frontend's)
- **The stream to the daemon over `dartssh2`**: exec of `sokar daemon connect`, as the WSL way
  does, or a forward to the Unix socket. (Agent Frontend's)
