# F108 — A Machine Over Ssh From Windows

**Status:** soon; decided on 2026-10-11.

**What must be true.** On Windows the interface reaches a Sokar on a machine over ssh, as it does on
Linux: its projects, its work, its terminals and its gate, with the key Windows' own ssh agent holds.

## Why

On Linux a machine over ssh is reached through `ssh -L`, forwarding the daemon's socket to a local
unix socket. `dart:io` opens no unix socket on Windows, so the Windows build shows such a machine as
not reachable ("reached from the Linux build of the interface; this Windows build reaches WSL
distributions only, so far", [F102](F102-A-Sokar-In-WSL-Reached-From-Windows.md)).

## The shape

- **The relay, as for WSL:** `ssh -o BatchMode=yes <host> sokar daemon connect`, started as a process
  with its own byte streams, and Varlink spoken over them through `Backend.relay`. No local socket
  and no forward. `sokar daemon connect` finds the account's socket by itself, as it does under
  `wsl.exe`.
- **The key** comes from Windows' "OpenSSH Authentication Agent" service, filled with `ssh-add`, as on
  Linux from the person's `ssh-agent`. The interface holds no key and asks for no passphrase:
  `BatchMode=yes` turns a key that needs one into a refusal in ssh's words.
- **The trial of a connection** in the wizard tries the relay instead of a forward, and says in words
  what stopped it: no route, an unknown host key, no key that logs in, or no Sokar answering there.
- **The words of the way in:** where the Linux build says "forward raised here", the Windows build
  says the machine is reached over ssh, and a dropped relay reads as a disconnection, as a dropped
  forward does.
- **Already the same on both:** terminals and commands run `ssh -t <host> …` in a pseudoconsole; the
  login reply forward is `ssh -L` on a TCP port; the host key is checked with `ssh -G` and
  `ssh-keyscan`, all of which Windows' OpenSSH ships.
- **Not on Windows:** preparing a new machine as root from the wizard, with keys written under
  `~/.ssh` with Linux's file rights. It stays the Linux build's.

## Acceptance

- **A machine over ssh is reached from Windows:** its projects and its work are shown, a task's
  terminal is attached and typed into, and a waiting push is approved at the gate. Seen to fail:
  today's Windows build, which shows the machine as not reachable. In the operator's Windows test.
- **The relay is proven on Linux** with a stand-in for `ssh` that runs `sokar daemon connect` against
  a real daemon's socket, as the WSL relay is proven.
- **A key that needs a passphrase not in the agent** is refused in ssh's words, and nothing waits for
  input. Seen to fail: a relay started without `BatchMode=yes`, which would wait.

## To be checked

- **Whether `ssh.exe` passes the daemon's zero bytes unchanged** through its standard input and
  output on Windows, as `wsl.exe` was measured to.
