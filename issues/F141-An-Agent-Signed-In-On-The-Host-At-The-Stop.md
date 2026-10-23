# F141 — An Agent Signed In When A Task Needs It On The Host

**Status:** Review; published in `0.5.1~snapshot.176`, for the operator's test on a rented host.
**Size:** M - the completed host becomes a fleet machine whose SSH paths all keep the host setup
pin; task start uses the machines page's sign-in.

**What must be true.** `porelo-host up` installs agents and starts no task. A person starts tasks
on the host as on any machine; when starting needs a sign-in, the machines page's existing
sign-in runs on that host, with its browser reply forwarded here. Every SSH to the host keeps
only the key `porelo-host` pinned and uses the identity given to setup.

## Plan

- **The completed command names the host.** The final `up` done line carries `address`, `account`
  and `socket`, with no other host fact. The socket uses digits returned by `id -u` over the same
  SSH as the account; a failed or invalid lookup refuses completion. Waiting lines have no host
  destination and stderr prints no agent sign-in command.
- **The host is a machine.** [F135](README.md#f135)'s dialog adds a machine of kind `host`,
  retaining the private key path as `identity`. Task start uses `shell.dart`'s
  `_logInWithTheAgent` when `starting.needsASignIn`. Its terminal and reply forward use that
  machine, as do the daemon tunnel, task terminals and commands.
- **The host key is the one `porelo-host` pinned.** Its ssh is given `porelo-host`'s own
  `known_hosts` with `StrictHostKeyChecking=yes`, never the person's own file, and the identity the
  person gave `up`. So the interface trusts no other key than `up` did, and writes no
  `known_hosts` of the person's.
- **Only host setup pins trust.** `host_keys.dart` refuses an attempt to trust a managed host's
  key on screen and cannot write one for it. An unsupported `agent-login:` need is an unknown need:
  it is shown verbatim, with no sign-in, no *Go on* and no automatic second `up`.
- **An agent whose login is a device flow or a pasted code** asks for no forward. The same terminal
  serves it.
- **Tests:**
  - the done line has exactly the address, account and socket; invalid UIDs refuse completion;
  - every host SSH path leads with the pinned options and has no later trust option;
  - the stored identity round-trips and a wrong type refuses access without a cast;
  - host-key trust is refused, and the login's forward stays scoped to its terminal;
  - the setup dialog never signs an agent in or reruns `up` at an unknown stop.

## Built so far

- **The completed host names its destination:** `HostRun.up` reads `id -u` as the account over
  the same remote, requires one line of digits and emits the final `up` done step with exactly
  `address`, `account` and `socket`. `Step` and `HostSession` read these fields. Waiting lines
  carry no destination; stderr prints no per-agent SSH line.
- **A host is a fleet machine**, kind `host`, holding the destination and the private key path
  `identity`, read field by field from settings and retained in the known fields. Agent sign-in
  happens at a task's start on that machine, through `shell.dart`'s `_logInWithTheAgent` when
  `starting.needsASignIn`. `HostLogin` and `LoginDestination` are folded into `Machine`.
- **One trust policy for every SSH to the host**, `pinnedHostSshOptions` in
  `packages/porelo_host/lib/src/ssh.dart`: the host command's own `known_hosts`, strict checking,
  no global keys, key command, DNS trust, key updates or shared connection, and the setup identity.
  It leads the daemon tunnel, temporary connection and vault trials, Windows relay, terminal,
  login reply forward, machine commands, daemon start and stop, UID lookup and diagnostic
  configuration query. The pinned trust path is quoted in OpenSSH's configuration syntax so a
  profile path with spaces stays one file. No later trust option changes it. The person's SSH configuration still supplies a `ProxyJump`.
- **Only host setup can pin a host key:** `host_keys.dart` returns a refusal without scanning or
  writing a key for a machine of kind `host`; the dialog shows that refusal with no trust button.
- **Seen red:** the daemon tunnel, a command on the machine, a task terminal and a login's reply
  forward each built without the pinned options; `host_keys.dart` offering trust for a `host`
  machine; a trial's copy of the machine dropping `kind` and `identity`; the done line without one
  of its three fields or with another.
- **Measured in `frontend` on ubuntu26.04** (porelo `0.5.1~snapshot.320.1+local`), standing in for
  a host as a machine of kind `host`: the argv the code builds ran `porelo --version` there and
  raised the tunnel, through which the daemon answered with `org.fuin.porelo.Tasks1`. With another
  key pinned the tunnel ended 255, "REMOTE HOST IDENTIFICATION HAS CHANGED", before any login. The
  stub's `porelo vault login` over the same pinned options signed it in.
- Left: the browser's reply forward with a real agent's task-start sign-in, and the interface
  against a rented host.

## Acceptance

- After setup, add the host and start a task there with an unsigned-in stub agent. Task start
  offers the existing machine sign-in, using the setup identity and pinned host key; completion
  lets task start proceed. A different pinned key refuses SSH before sign-in.
- A real agent's browser reply is forwarded only while that sign-in terminal is open.

## To be checked

- The task-start sign-in and browser reply on a real host, with no task started by `up`.
