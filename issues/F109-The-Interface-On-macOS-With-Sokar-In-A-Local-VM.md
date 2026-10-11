# F109 — The Interface On macOS, With Sokar In A Local VM

**Status:** Analyzed.
**Size:** XL - a third desktop build, its signing and its package, and a VM set up from the window;
it splits into three issues of L or smaller, as *Plan* says.

**What must be true.** A person on a Mac installs the interface and works with a Sokar that runs in
a local Linux VM on that Mac, set up from the window, as F102 does for Windows with WSL; and with
Sokar on remote machines over ssh, as on Linux.

## Why

Many developers work on a Mac. Sokar does not run natively on macOS and will not soon (`sokar-project`
[PJ25](https://github.com/sokar-ai/sokar-project/blob/main/issues/README.md#pj25) stays parked), so on
a Mac it runs in a Linux VM, and the interface on the Mac is how a person works with it.

## The shape

- **The VM: Lima.** Free (Apache-2.0), driven from the command line (`limactl`), on Apple's
  Virtualization framework, with Ubuntu images, and it forwards a unix socket of the guest to one on
  the Mac (`portForwards` with `guestSocket` and `hostSocket`). UTM and Parallels are driven by hand
  or paid; OrbStack needs a paid licence for work; Apple's framework alone means writing a VM manager.
  The interface drives `limactl` as it drives `wsl.exe` on Windows.
- **How the interface reaches it:** the daemon's socket in the VM, `/run/user/<uid>/sokar/sokard.sock`,
  forwarded by Lima to a socket on the Mac, which the interface opens as it opens a local socket on
  Linux: no ssh, no open port. Terminals and commands go `limactl shell <name> …` in a pseudoterminal.
- **Set up from the window, as F102's WSL wizard:** a VM is made from Lima's Ubuntu template with the
  socket forward in its configuration; Sokar is installed in it with the same lines `doc/getting-started.md`
  gives, each shown before it runs, the repository's key checked against the fingerprint the interface
  carries; lingering on; `sokar setup` as the VM's user.
- **Any other VM** (UTM, Parallels, a Lima set up by hand) is reached as a remote machine over ssh,
  which the macOS build does as the Linux build does: `dart:io` opens unix sockets on macOS.
- **The build:** Flutter's macOS release, a universal binary (arm64 and x86_64), in a `.dmg` signed
  with a Developer ID certificate and notarised, with its SHA-256 and the build's attestation, in
  `sokar-dist-macos` in Artifactory, `<channel>/<version>/`, as `sokar-dist-windows`.
- **Where it is built and tested:**
  - **Built on GitHub's hosted macOS runner**, in the Build on `main`: about $0.062 a minute for this
    private repository, so a build of about 15 minutes is about $1. It runs the unit tests and the
    leg over ssh against a leased machine, as the Linux job does.
  - **The VM leg cannot run there:** GitHub's macOS runners are VMs themselves and run no VM inside.
    It runs on a Mac that is a machine: the operator's, by hand before a release, or a rented Mac
    mini (Scaleway, M4 16 GB, €0.22 an hour or €149 a month, with a 24-hour minimum a lease) as a
    self-hosted runner, rented for the day of a release.

## Plan

Three issues, in this order; this one is split before any is built:

1. **The macOS build (L).**
   - `flutter create --platforms=macos .` adds `macos/`; its entitlements switch the App Sandbox
     off (the interface starts `ssh`, `limactl` and a pseudoterminal) and keep the hardened runtime
     notarisation needs, with a keychain group for `flutter_secure_storage`.
   - `lib/src/app/desk.dart`: a `MacDesk` beside `LinuxDesk` and `WindowsDesk` (`Desk.of` on
     `'macos'`): the configuration where Linux keeps it, `$XDG_CONFIG_HOME/sokar`, else
     `~/.config/sokar`, which is where the IntelliJ plugin reads `frontend.json` on a Mac too; `open`
     instead of `xdg-open`.
   - `lib/src/app/pty.dart`: the libc constants are Linux's (`_oCloexec`, `_tiocswinsz`,
     `_spawnSetsid`, the status layout); they become per system, with macOS's values.
   - `lib/src/app/notifications.dart`: `osascript`'s `display notification` instead of `notify-send`.
   - `lib/src/app/device_key.dart`: `storageOn('macos')` is user-scoped (the Keychain), as on Linux.
   - The unix socket path on macOS holds at most 104 bytes, not 108; the forward's local socket
     path is checked against it.
   - `.github/workflows/build.yml`: a job "macOS" on `macos-15`: analyze, the unit tests, the build,
     `tool/macos-package.sh` (the `.dmg`, `codesign`, `notarytool`, `stapler`, `SHA256SUMS`), the
     attestation, and the upload to `sokar-dist-macos`. Red first: a `MacDesk` test for its folders
     and opener, and `pty_test.dart` run on the macOS runner, which fails today on Linux's constants.
2. **A VM over ssh from the Mac (S).** Nothing new beyond the build: the leg over ssh in the Build's
   macOS job, against the leased machine. Red first: that leg on the macOS runner before step 1's
   pty constants.
3. **A Lima VM set up and reached from the window (L).**
   - `lib/src/app/lima.dart`, as `wsl.dart`: `limactl list --json` for the VMs, `limactl start` from
     a template the interface carries, `limactl shell` for commands; the socket forward written into
     the VM's configuration.
   - `lib/src/app/machines.dart`: a kind `lima` beside `wsl`, its socket the forwarded one.
   - `lib/src/app/lima_setup.dart`, as `wsl_setup.dart`: Lima missing (installed by the person, with
     Homebrew's line shown), no VM, no Sokar, no daemon - each said and offered.
   - `Session.command` through `limactl shell`.
   - Red first: `test/features/lima_machine.feature`, with a stand-in `limactl` as F102's tests have
     a stand-in `wsl.exe`; then the VM leg on a real Mac.

## Acceptance

- **On a Mac, the `.dmg` installs, opens without Gatekeeper's warning, and is the project's:** signed by
  its Developer ID, notarised, its checksum and attestation beside it. Seen to fail: the same `.dmg`
  unsigned, refused by Gatekeeper.
- **From the window, a Lima VM is made, Sokar set up in it, and its daemon reached** through the
  forwarded socket: a project followed, work started, a terminal attached and typed into, a push
  approved at the gate. Seen to fail: today's build, which has no macOS target.
- **A remote machine is reached over ssh from the Mac** as from Linux. Seen to fail: the pty with
  Linux's constants, which opens no terminal on macOS.
- **Built and its unit tests run in the Build on `main`**, the `.dmg` published in `sokar-dist-macos`.

## Open questions

- **An Apple Developer account for signing and notarising:** the Apple Developer Program costs $99 a
  year; as an organisation (porelo.ai) it needs a D-U-N-S number. Without it the `.dmg` is unsigned,
  and a person must allow it in System Settings each time. Whose account, and is it wanted now?
  (the operator's)
- **Where the VM leg runs:** on the operator's Mac by hand before a release, or on a rented Mac mini
  (about €149 a month, or €0.22 an hour with a 24-hour minimum) as a self-hosted runner. (the operator's)
- **Lima as the one VM the window sets up**, others reached over ssh only. (the operator's)
- **Intel Macs:** the universal binary runs there too, but no leg proves it; supported, or Apple
  silicon only? (the operator's)

## To be checked

- **Lima's socket forward in a VM made by `limactl start`**: the field names and that `static: true`
  keeps it up with no session, measured. (Agent Frontend's)
- **Scaleway's 24-hour minimum for the M4**, read from Scaleway's own terms, and GitHub's macOS
  minute price on the bill. (Agent Frontend's)
- **`flutter_secure_storage` on macOS** without the App Sandbox: the keychain group its entitlement
  needs. (Agent Frontend's)
