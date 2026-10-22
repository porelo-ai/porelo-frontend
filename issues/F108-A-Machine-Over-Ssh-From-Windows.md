# F108 — A Machine Over Ssh From Windows

**Status:** Backlog.
**Size:** M - several modules (the machine list, the relay, the trial, commands, the wizard) and
the operator's Windows test; no contract changes.

**What must be true.** On Windows the interface reaches a Porelo on a machine over ssh, as it does on
Linux: its projects, its work, its terminals and its gate, with the key Windows' own ssh agent holds.

## Why

On Linux a machine over ssh is reached through `ssh -L`, forwarding the daemon's socket to a local
unix socket. `dart:io` opens no unix socket on Windows, so the Windows build shows such a machine as
not reachable ("reached from the Linux build of the interface; this Windows build reaches WSL
distributions only, so far", [F102](README.md#f102)).

## The shape

- **The relay, as for WSL:** `ssh -o BatchMode=yes <host> porelo daemon connect`, started as a process
  with its own byte streams, and Varlink spoken over them through `Backend.relay`. No local socket
  and no forward. `porelo daemon connect` finds the account's socket by itself, as it does under
  `wsl.exe`.
- **The key** comes from Windows' "OpenSSH Authentication Agent" service, filled with `ssh-add`, as on
  Linux from the person's `ssh-agent`. The interface holds no key and asks for no passphrase:
  `BatchMode=yes` turns a key that needs one into a refusal in ssh's words.
- **The trial of a connection** in the wizard tries the relay instead of a forward, and says in words
  what stopped it: no route, an unknown host key, no key that logs in, or no Porelo answering there.
- **The words of the way in:** where the Linux build says "forward raised here", the Windows build
  says the machine is reached over ssh, and a dropped relay reads as a disconnection, as a dropped
  forward does.
- **Already the same on both:** terminals and commands run `ssh -t <host> …` in a pseudoconsole; the
  login reply forward is `ssh -L` on a TCP port; the host key is checked with `ssh -G` and
  `ssh-keyscan`, all of which Windows' OpenSSH ships.
- **Not on Windows:** preparing a new machine as root from the wizard, with keys written under
  `~/.ssh` with Linux's file rights. It stays the Linux build's.

## Plan

- **The relay for ssh:** `Machine.relay` in `lib/src/app/machines.dart` gives, on Windows, for a
  machine that `needsATunnel`, `ssh -o BatchMode=yes <host>` with `porelo daemon connect` run in the
  login shell (`inTheLoginShell` in `lib/src/app/connections.dart`, since a plain ssh command has no
  `~/.local/bin` on its `PATH`). `whyNotReachableOn` stops refusing it there. `Machines.backendFor`
  passes it on as today, with no `whyNotNow`.
- **No forward on Windows:** `Tunnels.raiseFor` in `lib/src/app/tunnel.dart` raises nothing for a
  machine reached by a relay, and `machineKind` in `lib/src/ui/machine_switcher.dart` says it is
  reached over ssh instead of "forward raised here".
- **WSL and ssh kept apart:** `onTheMachine` in `lib/src/app/connections.dart` and `Session.command`
  in `lib/src/app/session.dart` read any relay as WSL today (`machine.relay != null` leads to
  `Wsl.runIn`). They ask for the kind `wsl` instead, so a machine over ssh keeps `ssh -t`.
- **What stopped it, in words:** `Backend.open` in `lib/src/client/porelo_client.dart` drains the
  relay's standard error. It keeps its last lines instead, for the words of the
  `VarlinkDisconnected`. `tryAMachine` in `lib/src/app/connection_trial.dart` skips
  `tunnels.trial` for a relay, connects through it, and says no route, an unknown host key, no key
  that logs in, or no Porelo answering, from what ssh said.
- **The wizard:** `_AskForAMachine` in `lib/src/ui/machine_switcher.dart` offers on Windows, beside
  the WSL distribution, a Porelo that already runs on a machine over ssh. Not the set-up as root.
- **Red first:** in `test/app/wsl_test.dart`, "on Windows a WSL distribution is reached, and the
  Linux ways are said not to be" expects the machine over ssh refused; it is turned to expect the
  relay, holding `BatchMode=yes`. Then a test in `test/client/relay_test.dart` with a stand-in for
  `ssh` that runs the joiner against the daemon's socket, and one where it refuses and nothing
  waits.

## Acceptance

- **A machine over ssh is reached from Windows:** its projects and its work are shown, a task's
  terminal is attached and typed into, and a waiting push is approved at the gate. Seen to fail:
  today's Windows build, which shows the machine as not reachable. In the operator's Windows test.
- **The relay is proven on Linux** with a stand-in for `ssh` that runs `porelo daemon connect` against
  a real daemon's socket, as the WSL relay is proven.
- **A key that needs a passphrase not in the agent** is refused in ssh's words, and nothing waits for
  input. Seen to fail: a relay started without `BatchMode=yes`, which would wait.

## To be checked

- **Whether `ssh.exe` passes the daemon's zero bytes unchanged** through its standard input and
  output on Windows, as `wsl.exe` was measured to. (Agent Frontend's, measured in the operator's
  Windows test)
- **Whether ssh's words for each refusal** are the same in Windows' OpenSSH as on Linux, so the
  trial can tell no route, an unknown host key and no key apart. (Agent Frontend's, measured in the
  operator's Windows test)
