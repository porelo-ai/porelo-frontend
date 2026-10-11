# F102 — A Sokar In WSL Reached From Windows

**Status:** stage 1 built; stage 2 built locally on 2026-10-10 and run first on GitHub's Windows
runner from a branch `windows/stage2`; stage 3 later. See *The stages*.

**What must be true.** On a Windows machine with Sokar in a WSL2 distribution, the interface runs as
a Windows application on the same machine. It reaches that Sokar with no ssh and no open port, and
only the Windows user who owns the distribution reaches it.

## Why

`sokard` answers only on its unix socket, `$XDG_RUNTIME_DIR/sokar/sokard.sock`. A unix socket does
not cross the boundary of the WSL2 virtual machine: a Windows program cannot connect to it, not even
through `\\wsl$`, although WSL1 could. Today the interface reaches a machine in one of two ways, "this
computer" (the socket on the same Linux host) and "over ssh" (`ssh -L` to a local socket,
`lib/src/app/tunnel.dart`). Neither works from Windows into WSL without an ssh server in the
distribution.

**Not this:** `sokard` listening on TCP at localhost. WSL2 forwards such a port to Windows, where any
program of any user could drive the daemon: start tasks, approve at the gate, open the vault. Today
the socket's file permissions are the only guard, and an open port would remove it.

## The shape

- **A third way to a machine**, beside "this computer" and "over ssh": **a WSL distribution**,
  reached through `wsl.exe -d <distro> -- sokar daemon connect`. That command, which exists already
  for `ssh host sokar daemon connect`, joins standard input and output to the daemon's socket, so
  nothing else, `socat` included, has to be in the distribution.
  This is how Docker Desktop and Podman Desktop reach their WSL machines. No port
  is opened and no key is needed. `wsl.exe` runs as the Windows user, so only that user reaches the
  distribution.
- **`VarlinkConnection` speaks over any byte stream**: the relay's standard input and output here,
  and a socket file as today. This is the same seam [F37](F37-Reach-A-Machine-Without-An-ssh-Binary.md)
  needs; whichever is built first makes it.
- **The machine switcher and the connection wizard offer the WSL way**, listing the distributions
  with `wsl.exe -l -q`. A distribution without Sokar, or with its daemon down, is said in words.
- **A stopped distribution is never started by the interface.** `wsl.exe -d <distro> -- …` would
  start it, with its memory and CPU, so the interface reads each distribution's state with
  `wsl.exe -l -v`, which starts nothing, and calls into one only when it runs. A stopped one is
  shown as stopped, and the person starts it. The one exception is the restart for systemd, below,
  after its own question.
- **What the interface runs on a machine through ssh today runs through `wsl.exe` as well**: the
  terminal of a task, attaching to it, a sign-in (`sokar vault login`), and the checks the connection
  trial makes.
- **A Windows build of the interface.** Flutter supports Windows, but only the Linux runner exists
  today, and several parts are Linux-only:
  - **The terminal:** `lib/src/app/pty.dart` opens a pseudoterminal with `dart:ffi` against the libc.
    Windows needs ConPTY behind the same seam.
  - **External programs:** `chmod` (three places), `xdg-open` (two), `notify-send` (one), and `ssh`,
    `ssh-add` and `ssh-keyscan`. On Windows: file rights through ACLs, opening through the shell,
    Windows notifications, and the OpenSSH client Windows ships, for machines still reached over ssh.
  - **Local paths:** the settings, the operations record and temporary sockets take Windows places.
    The `/run/user/…` paths name the far side and stay.
  - **Dependencies:** `xterm`, `flutter_secure_storage` (the Credential Manager instead of libsecret)
    and `file_selector` support Windows. `guided_walk` is to be checked.
  - **The project and the build:** a `windows/` runner (`flutter create --platforms=windows`), and a
    profile per platform in `pom.xml`, whose `flutter.target` is `linux` today. `tool/package.sh` and
    `tool/e2e.sh` are Bash. In `build.yml`, a job on a Windows runner, which costs about twice a Linux
    minute.
  - **Two packages:**
    - **An MSIX**, signed with a self-signed certificate at first. Windows installs an MSIX only
      when its certificate is trusted on that machine, so the certificate is imported once on each
      machine that installs it. A certificate Windows trusts by itself comes before the package is
      offered to people outside the project. The version takes four numbers, so
      `0.4.2~snapshot.141` becomes, for example, `0.4.2.141`.
    - **A ZIP with the `.exe` and what it needs**, offered for download on GitHub, for a person
      who may not install anything on their computer: unpacked and started, with no installation.
      The ZIP is not signed. It comes with a `SHA256SUMS` beside it and a build provenance
      attestation made in the Windows job (`actions/attest-build-provenance`, through Sigstore, with
      no certificate of the project's). Before unpacking, a person checks both: `sha256sum -c
      SHA256SUMS` (or `Get-FileHash` in PowerShell, compared with the line), and
      `gh attestation verify <zip> --repo sokar-ai/sokar-frontend`, which shows the ZIP was built
      from this repository by this workflow. The download page says how. The attestation needs
      `id-token: write` and `attestations: write`, for that one job only. The MSIX's signature in
      stage 3 comes on top of both.
    - Where the MSIX is published, beside `sokar-dist-deb` and `sokar-dist-rpm`.

## What the interface checks before it connects

Part of stage 2. When a WSL distribution is added, the interface checks the system, in this order,
and says in words where it stops:

| Check | How | When it fails |
|---|---|---|
| The Windows version | the build number: WSL2 needs Windows 10 2004 or later, or Windows 11 | said in words, and no WSL way offered |
| WSL is installed | `wsl.exe --status` | how to install WSL, as text |
| WSL2, not WSL1 | `wsl.exe -l -v`, the `VERSION` column | WSL1 runs neither podman nor systemd; `wsl --set-version <distro> 2` is named, never run by the interface |
| A supported distribution | `/etc/os-release`: Ubuntu 26.04 or later, Debian 13, Fedora 43 or 44 | "not supported", and no offer to set Sokar up |
| systemd | `/etc/wsl.conf`, and `systemctl is-system-running` | the separate question with the restart, below |
| Sokar and its daemon | `sokar --version`, then `sokar daemon connect` | the offer to set Sokar up, below |

Fedora runs in WSL officially since Fedora 42 (`wsl --install FedoraLinux-<version>`). Its images
usually have systemd on and SELinux off; Ubuntu's do not always have systemd on.

## Setting up Sokar in a distribution that lacks it

Part of stage 2. A person adds a WSL distribution in the wizard, and the interface finds no Sokar
there, or no daemon running. Instead of a raw error it says so in words and offers to set Sokar up,
as `sokar`'s B159 offers a remedy: the remedy shown, asked, done, checked again, and then the
connection goes on.

- **What it runs** is what Sokar's `doc/getting-started.md` says for the distribution's package
  manager. On Ubuntu and Debian: the key to `/usr/share/keyrings/sokar.gpg`, the source line for
  releases (snapshots only when the person asks for them, as that page's "Snapshots" section says),
  `apt install sokar` and the agents chosen. On Fedora: `/etc/yum.repos.d/sokar.repo` and
  `dnf install`.
  Then `loginctl enable-linger <user>` as root, so that `sokard` runs whether or not a session
  is open: `sokar setup` does not turn lingering on, and whether `wsl.exe` opens a login session
  that `sokard` lives in is not measured. Then `sokar setup` as the distribution's user. Each line
  is shown to the person before anything runs.
- **The agents are a choice:** Claude Code, Pi and Oh My Pi, one or more, as `sokar`'s B159 offers a
  list. Nothing is chosen in advance.
- **The repository's key is checked against a fingerprint the interface carries.** A key whose
  fingerprint does not match stops the setup, saying the fingerprint expected and the one that came.
  So a change of the repository's key needs a new version of the interface. The fingerprint is
  only as trustworthy as the interface it comes in: in stage 2, the check of the ZIP above.
- **SELinux:** where it is off, as in Fedora's WSL images, the offer does not insist on Sokar's
  SELinux module. `sokar doctor` already reads WSL2 that way.
- **Root inside the distribution:** `wsl.exe -d <distro> -u root -- …` runs as root with no
  password, for the Windows user who owns the distribution. The interface uses it only after the
  person said yes to exactly the lines shown, never in the background, and records in the operations
  record what it ran and what each line answered.
- **Only on a system Sokar supports,** as the check above reads it. Any other distribution is told
  why in words, with no offer.
- **systemd:** a distribution without systemd (no `[boot] systemd=true` in `/etc/wsl.conf`) needs it
  turned on and the distribution restarted. The interface asks for that with a question of its own,
  saying that everything running in the distribution ends: shells, services and running Sokar
  tasks. The answer is no unless the person changes it. After a yes the interface runs
  `wsl.exe --terminate <distro>`, and its next call starts the distribution again. This is the one
  time the interface starts a distribution.
- **For a person who says no:** the same lines as text to copy.
- **Acceptance:** on a Windows machine with a fresh supported distribution and no Sokar, the
  interface offers the setup, the person says yes, Sokar is installed, and the distribution is
  reached. In the operator's test after stage 2.

## Measured on Windows

On 2026-10-10, on a Windows machine with WSL2, against the published `sokar` `0.4.2~snapshot.268`,
from Windows PowerShell 5.1 through `cmd`, with a NUL-terminated `GetInfo` request in a file on the
Windows side:

    cmd /c "wsl.exe -d Ubuntu -- sokar daemon connect < %USERPROFILE%\getinfo.bin"
    -> {"parameters":{"vendor":"fuin.org","product":"Sokar","version":"0.4.2~snapshot.268", ...,
        "interfaces":["org.varlink.service","org.fuin.sokar.Tasks1"]}}

`od -c` inside WSL showed the bytes arrive unchanged, the closing `\0` included. So `wsl.exe` carries
Varlink's framing both ways: standard input from Windows, and standard output back.

**What this means for stage 2:** Windows PowerShell 5.1 has no `<` and re-encodes text in its
pipes. The interface therefore starts `wsl.exe` as a process with byte streams of its own
(`Process.start`, its `stdin` and `stdout` given to `VarlinkConnection.over`), never through a shell
or a shell pipe.

## The stages

Decided on 2026-10-10: the ZIP first, the MSIX after it.

1. **On Linux, in the next round** (built on 2026-10-10). `VarlinkConnection` speaks over any
   byte stream, and the WSL entry in `frontend.json` (below) is read and kept, shown as not
   reachable on Linux. The relay, `sokar daemon connect`, exists already. Tested as the Linux build
   always is: the whole workflow green on the VM before the push.
2. **On Windows, in the round after.** The Windows build, the WSL way in the switcher and the wizard,
   and terminals, attach and sign-in through `wsl.exe`. The only package is **the ZIP** with the
   `.exe`, made by a Windows job on GitHub's runner. It is pushed on the operator's word, and then
   the operator tests it on a Windows machine with WSL2, against the published snapshots.
3. **The MSIX**, self-signed at first (built on 2026-10-11): signed by `CN=porelo.ai` in the Build's
   job "Windows" with a certificate whose key is held in the repository secrets
   `WINDOWS_SIGNING_PFX` and `WINDOWS_SIGNING_PFX_PASSWORD`, and published beside the ZIP with the
   certificate's public half. A person trusts that certificate once, in `TrustedPeople`, as
   `doc/index.md` says. The package's writes to AppData are not redirected
   (`unvirtualizedResources`), so it reads the same `frontend.json` as the ZIP and the plugin.

**Built in stage 2, and what it settled:**
- **The ZIP** is made by the Build's job *Windows*, beside the Linux packages, with `SHA256SUMS` and
  a build provenance attestation, and published as they are: into Artifactory,
  `sokar-dist-windows/<channel>/<version>/`, with the attestation's Sigstore bundle beside it; a
  release once only. `doc/index.md` says how to check both before unpacking.
- **`wsl.exe -d <distribution> --exec …`, not `-- …`.** After `--`, `wsl.exe` hands the words to the
  distribution's shell, which splits them again; `--exec` runs the program with exactly the
  arguments given. The measurement above ran `sokar daemon connect` with `--`, where no word needs
  quoting, and `--exec` carries the same bytes.
- **The distributions are read without the translated column.** The names come from `wsl.exe -l -q`,
  which run from `-l --running -q`, the version from the last column of `-l -v`; `-l -v`'s state is
  in Windows' language. Each call into a distribution is preceded by that reading, so a stopped one
  is said to be stopped and stays so.
- **A machine over ssh is reached from the Linux build only, so far.** `dart:io` opens no unix
  socket on Windows, so the forward of today does not work there; reaching one through
  `ssh host sokar daemon connect` is the way, built later. A socket entry carried over from Linux is
  said to name a path Windows cannot open.
- **Notifications are not raised on Windows yet**, and that is said once: Windows' own need the
  application registered with the shell, which comes with the MSIX.
- **The files:** `%APPDATA%\sokar\frontend.json`, the plugin's too; the operations record under
  `%LOCALAPPDATA%\sokar`; a file kept to its owner with `icacls`; one window over a loopback port
  named in `%LOCALAPPDATA%\sokar\frontend.port`.

## The machine file, which `sokar-intellij` reads too

The interface keeps its machines in `$XDG_CONFIG_HOME/sokar/frontend.json`, and the IntelliJ plugin
reads the same file. So a new kind of entry is a contract between the two repositories, changed only
after agreement in the channel and in both. Today an entry has `name` and `socket`, and `host` and
`remoteSocket` for a machine behind ssh.

- **A WSL entry:** `{"name": "<label>", "kind": "wsl", "distribution": "<WSL distribution name>"}`.
- **It carries no `socket`.** Today's plugin drops an entry without `socket` silently, so it does not
  open a Linux path on Windows and show a machine that never answers. The socket inside the
  distribution is not stored: it is found on each connection, from the distribution's user id.
- **Entries without `kind`** stay what they are today: a plain socket, or a machine behind ssh when
  `host` and `remoteSocket` are set. An unknown `kind` is kept in the file and shown as not
  reachable by this version, never dropped from the file.
- The plugin's side is `sokar-intellij`'s IJ03, "A Sokar in WSL reached from IntelliJ on Windows",
  blocked by this one.

## Where it touches `sokar`

- **`sokar daemon connect`** is the relay, the one command for it: it joins standard input and
  output to the daemon's socket (`--socket` names another), passes bytes both ways unbuffered,
  exits when either end closes, and says a missing socket on standard error, never on the stream.
  The IntelliJ plugin uses it too. Nothing new for `sokar` to build.
- Nothing else: the interface speaks the same contract over the relay as over a socket.

## Acceptance

- **The interface lists the WSL distributions** of the Windows user and shows, for the one running
  Sokar, its projects and tasks, through `wsl.exe` alone. Seen to fail: on a Windows machine without
  the WSL way, that distribution is not reachable without ssh.
- **A task's terminal is attached and works** (typing, resizing, the way back), through `wsl.exe`.
- **A waiting push is approved at the gate** from the Windows interface, and arrives at the upstream.
- **No ssh and no open port:** while the interface works with the distribution, no `sshd` runs in it
  and `sokard` listens on no TCP port. Seen to fail: a check of the listening sockets during the run.
- **Only the owner reaches it:** a second Windows user on the same machine does not reach the
  distribution's daemon.
- **The machine file keeps every entry:** a WSL entry is written in the shape above, entries without
  `kind` read as before, and an entry of an unknown `kind` survives a load and a save. Seen to fail:
  tests that load and save a file holding all three.
- **Varlink over a byte stream** is proven without a socket file. Seen to fail: a test that speaks
  Varlink over an in-memory stream.
- **The Windows build is tested on GitHub's Windows runner**: unit, feature and documents tests, and
  the ZIP built (stage 2), then the MSIX built and installed (stage 3). This is decided as the one
  exception to "the whole workflow green on the VM before a push", since there is no Windows machine
  here; the Linux build keeps the rule. After stage 2's push, the operator tests the ZIP on a
  Windows machine with WSL2.
- **A stopped distribution stays stopped:** with the distribution stopped, the interface shows it
  as stopped and it is still stopped afterwards. Seen to fail: the same with a call that starts it.

## To be checked

- **The socket under `wsl.exe --exec`, on Windows itself.** `sokar daemon connect` needs no
  `--socket`: with `XDG_RUNTIME_DIR` unset it takes `/run/user/<uid>`, the uid read from
  `/proc/self/status`, where `sokard` listens under systemd, which lingering keeps up with no session
  open. Seen on Linux with an emptied environment and no shell; on Windows, in the operator's test.
- **Where the MSIX is published**, and which certificate replaces the self-signed one.
