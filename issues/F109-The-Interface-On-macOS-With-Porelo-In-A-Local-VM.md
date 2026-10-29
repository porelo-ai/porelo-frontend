# F109 — The Interface On macOS, With Porelo In A Local VM

**Status:** Estimated.
**Size:** XL - a third desktop build, its signing and its package, and a VM set up from the window;
it splits into three issues of L or smaller, as *Plan* says.

**What must be true.** A person on a Mac installs the interface and works with a Porelo that runs in
a local Linux VM on that Mac, set up from the window, as [F102](README.md#f102) does for Windows with WSL; and with
Porelo on remote machines over ssh, as on Linux.

## Why

Many developers work on a Mac. Porelo does not run natively on macOS and will not soon, so on
a Mac it runs in a Linux VM, and the interface on the Mac is how a person works with it.

## The shape

- **The VM: Lima.** Free (Apache-2.0), driven from the command line (`limactl`), on Apple's
  Virtualization framework, with Ubuntu images, and it forwards a unix socket of the guest to one on
  the Mac (`portForwards` with `guestSocket` and `hostSocket`). It is the one VM the window sets up,
  on Apple silicon and on Intel; UTM, Parallels, OrbStack and any other VM are reached over ssh as a
  remote machine. The interface drives `limactl` as it drives `wsl.exe` on Windows.
- **Porelo in the VM is the Mac's architecture:** its arm64 packages on Apple silicon, once they are
  published, and its amd64 packages on an Intel Mac.
- **How the interface reaches it:** the daemon's socket in the VM, `/run/user/<uid>/porelo/porelod.sock`,
  forwarded by Lima to a socket on the Mac, which the interface opens as it opens a local socket on
  Linux: no ssh, no open port. Terminals and commands go `limactl shell <name> …` in a pseudoterminal.
- **Set up from the window, as [F102](README.md#f102)'s WSL wizard:** a VM is made from Lima's Ubuntu template with the
  socket forward in its configuration; Porelo is installed in it with the same lines `doc/getting-started.md`
  gives, each shown before it runs, the repository's key checked against the fingerprint the interface
  carries; lingering on; `porelo setup` as the VM's user.
- **Any other VM** (UTM, Parallels, OrbStack, a Lima set up by hand) is reached as a remote machine
  over ssh, which the macOS build does as the Linux build does: `dart:io` opens unix sockets on macOS.
- **The build:** Flutter's macOS release, a universal binary (arm64 and x86_64), in a `.dmg` with its
  SHA-256 and the build's attestation, in `porelo-dist-macos` in Artifactory, `<channel>/<version>/`,
  as `porelo-dist-windows`. **Not signed by a Developer ID for now**: there is no Apple Developer
  account. The download page says how to open it past Gatekeeper (Control-click → Open, or System
  Settings → Privacy & Security → Open Anyway), how to check it first by `SHA256SUMS` and the
  attestation, and that Intel Macs run it untested. The packing step is shaped so that signing and
  notarising slot in once an account exists, as the Windows MSIX signs only where its secrets are.
- **Where it is built and tested:**
  - **Built on GitHub's hosted macOS runner**, in the Build on `main`: about $0.062 a minute for this
    private repository, so a build of about 15 minutes is about $1. It runs the unit tests and the
    leg over ssh against a leased machine, as the Linux job does.
  - **The VM leg cannot run there:** GitHub's macOS runners are VMs themselves and run no VM inside.
    For a release, a Mac with Apple silicon is rented through `porelo-machines` for the release's
    whole test window. On it, Porelo's arm64 packages run in an ARM Lima VM
    with their acceptance legs, and this interface, built natively for macOS, is tested against that
    VM. The window's length and cost are posted before the rental and need the operator's word.

## Plan

Three issues, in this order; this one is split before any is built:

1. **The macOS build (L).**
   - `flutter create --platforms=macos .` adds `macos/`; its entitlements switch the App Sandbox
     off (the interface starts `ssh`, `limactl` and a pseudoterminal) and keep the hardened runtime
     a later notarisation needs, with a keychain group for `flutter_secure_storage`. The build signs
     ad hoc, as Flutter does, which Apple silicon needs to run it at all.
   - `lib/src/app/desk.dart`: a `MacDesk` beside `LinuxDesk` and `WindowsDesk` (`Desk.of` on
     `'macos'`): the configuration where Linux keeps it, `$XDG_CONFIG_HOME/porelo`, else
     `~/.config/porelo`, which is where the IntelliJ plugin reads `frontend.json` on a Mac too; `open`
     instead of `xdg-open`.
   - `lib/src/app/pty.dart` becomes per system. A probe made `pty.dart`'s calls from C on macOS
     26.4.1 (Apple M1 Pro) and measured:
     - **The constants differ:** `O_CLOEXEC` `0x1000000`, `O_NOCTTY` `0x20000`,
       `POSIX_SPAWN_SETSID` `0x400`, `TIOCSWINSZ` `0x80087467`, `PATH_MAX` 1024 (Linux: `0x80000`,
       `0x100`, `0x80`, `0x5414`, 4096); `O_RDWR`, `ENOENT`, `EACCES` and `SIGHUP` are the same.
       `posix_spawn_file_actions_t` and `posix_spawnattr_t` are pointers there (8 bytes), so the
       256 and 512 bytes allocated today hold them.
     - **`pipe2` is missing from macOS's libc**, so `_Libc`'s lookup throws and no terminal opens at
       all. On macOS the status pipe is `pipe` with close-on-exec set by `fcntl`, as the probe made
       it.
     - **The size set on the master before the child starts fails** with "Inappropriate ioctl for
       device" (`ENOTTY`), and the child starts at `0 0`; set after the start, it arrives as
       `SIGWINCH` (`44 120`). `_setSize` ignores `ioctl`'s result today, so this would be silent:
       it checks the result, and on macOS the size is set before the spawn on the slave, opened here
       with `O_NOCTTY` and closed after the spawn.
     - **The rest works as on Linux:** `posix_openpt`, `grantpt`, `unlockpt`, `ptsname_r`;
       `POSIX_SPAWN_SETSID` accepted; the child's standard input a terminal and its controlling
       terminal, as a session leader whose group holds the terminal; Ctrl+C arriving as `SIGINT`;
       the code reported on descriptor 3.
     - **The code after a Ctrl+C that the command traps differs:** when it exits 7 from its trap,
       macOS's `/bin/sh` survives and reports 7 on descriptor 3, while Linux's is killed with it,
       reports nothing, and `waitpid` reads 130. Both are a code the session ended with. The Ctrl+C
       test in `pty_test.dart` interrupts a `sleep` that traps nothing, which is inferred to end 130
       on both.
   - `lib/src/app/notifications.dart`: `osascript`'s `display notification` instead of `notify-send`.
   - `lib/src/app/device_key.dart`: `storageOn('macos')` is user-scoped (the Keychain), as on Linux.
   - The unix socket path on macOS holds at most 104 bytes, not 108; the forward's local socket
     path is checked against it.
   - `.github/workflows/build.yml`: a job "macOS" on `macos-15`: analyze, the unit tests, the build,
     `tool/macos-package.sh` (the `.dmg` with `hdiutil`, `SHA256SUMS`; `codesign`, `notarytool` and
     `stapler` only where a Developer ID's secrets are set, which today they are nowhere), the
     attestation, and the upload to `porelo-dist-macos`. `doc/index.md` gains a macOS section beside
     Windows'. Red first: a `MacDesk` test for its folders and opener, and `pty_test.dart` run on the
     macOS runner, which fails today on Linux's constants.
2. **A VM over ssh from the Mac (S).** Nothing new beyond the build: the leg over ssh in the Build's
   macOS job, against the leased machine. Red first: that leg on the macOS runner before step 1's
   pty constants.
3. **A Lima VM set up and reached from the window (L).**
   - `lib/src/app/lima.dart`, as `wsl.dart`: `limactl list --json` for the VMs, `limactl start` from
     a template the interface carries, `limactl shell` for commands; the socket forward written into
     the VM's configuration.
   - **The forward, measured** with Lima 2.2.1 in a VM made by `limactl create --vm-type=vz --rosetta
     --set '.portForwards += [{"guestSocket": "/run/user/{{.UID}}/porelo/probe.sock", "hostSocket":
     "{{.Dir}}/sock/probe.sock"}]' template:ubuntu-26.04` (Ubuntu 26.04.1 aarch64, 175 s to its
     first start with the download), the guest's socket held by a lingering user service: it answers
     at once, after 60 s with no session, after the service's restart and after the VM's (18 s);
     50 MB pass at 19 MB/s; the Mac's path is 45 bytes.
   - **A stopped daemon and a stopped VM look different on the Mac's socket:** while the service is
     stopped, the socket still accepts and closes at once with nothing; while the VM is stopped, the
     socket file is gone (`ENOENT`). So the window tells "Porelo is not running in the VM" from "the
     VM is stopped" by `limactl list --json`, never by the connection alone.
   - **Inside that VM, measured:** systemd 259, cgroup v2 with `cpuset cpu io memory pids` delegated
     to the user, rootless Podman 5.7.0 with netavark, aarch64 and amd64 containers (amd64 through
     Rosetta's binfmt), and Porelo 0.5.0's amd64 package, its key and index signature checked,
     answering `porelo --version` (7 s) and `porelod --version` (2 s) under Rosetta.
   - **Refused inside that VM:** nftables in a user and network namespace, as a task's firewall is
     made, stopped at `unshare: write failed /proc/self/uid_map: Operation not permitted`, while
     rootless Podman ran. The firewall is Porelo's, and an Idea in `porelo` reads what differs from
     our Ubuntu 26.04 VM and what Porelo needs; until then a task with its firewall is not known to
     run in a Lima VM, and step 3 waits on it.
   - `lib/src/app/machines.dart`: a kind `lima` beside `wsl`, its socket the forwarded one.
   - `lib/src/app/lima_setup.dart`, as `wsl_setup.dart`: Lima missing (installed by the person, with
     Homebrew's line shown), no VM, no Porelo, no daemon - each said and offered; the VM's
     architecture follows the Mac's, `aarch64` or `x86_64`, and Porelo's package with it.
   - `Session.command` through `limactl shell`.
   - Red first: `test/features/lima_machine.feature`, with a stand-in `limactl` as [F102](README.md#f102)'s tests have
     a stand-in `wsl.exe`; then the VM leg on the Mac rented for a release's test window.

## Acceptance

- **On a Mac, the `.dmg` installs and opens after the one Gatekeeper step the download page names,
  and is the project's:** its checksum and attestation beside it, checked as the page says. Seen to
  fail: an app not signed even ad hoc, which Apple silicon refuses to start.
- **From the window, a Lima VM is made, Porelo set up in it, and its daemon reached** through the
  forwarded socket: a project followed, work started, a terminal attached and typed into, a push
  approved at the gate. Seen to fail: today's build, which has no macOS target.
- **A remote machine is reached over ssh from the Mac** as from Linux. Seen to fail: the pty with
  Linux's constants, which opens no terminal on macOS.
- **Built and its unit tests run in the Build on `main`**, the `.dmg` published in `porelo-dist-macos`.

## To be checked

- **Porelo is published for amd64 only** (the deb repository's `Architectures: amd64 i386`,
  read on 2026-10-21), so until arm64 packages are published there is nothing to install in
  an ARM VM. A gap the probe below shows in an ARM VM is closed before the arm64 build is made.
  Porelo's amd64 build answers `--version` under Rosetta, as measured; whether its daemon runs a
  task there is not, and it stays a stop-gap only. (Agent Frontend's)
- **What the probe kit could not answer**, after its run on a Mac with Apple silicon (its scripts
  live outside the repository, and each step is started with `bash`, since an unpacked archive
  keeps no execute bit):
  - whether setting the size on the slave before the spawn arrives as the child's first size on
    macOS, which only the app built for macOS can show;
  - whether `pipe` with `fcntl` leaves a window in which another isolate's spawn inherits the status
    pipe, and whether `POSIX_SPAWN_CLOEXEC_DEFAULT` closes it in the child instead;
  - that the Ctrl+C test ends 130 on the macOS runner, read on its first run there;
  - everything on an Intel Mac, which nobody has measured.

  (Agent Frontend's)
- **`ioctl` is variadic, and on Apple's arm64 a variadic argument is passed on the stack**, while
  `pty.dart` looks `ioctl` up with a fixed signature. The window size would then not arrive.
  Known, not measured. The probe calls `ioctl` correctly from C, so only the app built for macOS
  can show it; Dart's FFI `VarArgs` is the likely fix. (Agent Frontend's)
- **Lima's socket forward with Porelo's real daemon**: the probe measured `guestSocket` and
  `hostSocket` with an echo service, held 60 s with no session and without `static: true`; the
  daemon's own socket, `Watch` held open across an idle hour, and what `static: true` changes are
  not measured. (Agent Frontend's)
- **GitHub's macOS minute price** on the bill; the issue corrected if it differs. The Mac rented for
  a release window is `porelo-machines`' work. (Agent Frontend's)
- **`flutter_secure_storage` on macOS** without the App Sandbox: the keychain group its entitlement
  needs. (Agent Frontend's)
