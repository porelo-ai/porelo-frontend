/// How porelo-host is run on a host over root's SSH: with none of the session's environment.
///
/// A root login carries what pam_systemd and sshd set, `DBUS_SESSION_BUS_ADDRESS`, `XDG_*` and `SSH_*` among it, and
/// porelo-host refuses those at its entry; it is given only a path and a locale.
const hostCommandEnvironment = 'env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin LANG=C.UTF-8';

/// The remote command that runs porelo-host with [arguments], as [hostCommandEnvironment] says.
String poreloHostCommand(String arguments) => '$hostCommandEnvironment /usr/sbin/porelo-host $arguments';

/// What `env` exits with when the program it should run is not there.
const _notFound = 127;

/// What a run of [poreloHostCommand] on [host] that ended with [exitCode] says of a porelo-host missing there, or null.
///
/// A setup that stops before installing it leaves the host without `/usr/sbin/porelo-host`; `env` then exits 127, and
/// uutils env's last line names an option fault rather than the missing program, so its words are not the reason.
String? missingPoreloHost(String host, int exitCode) => exitCode == _notFound
    ? 'porelo-host is not installed on $host: its setup stopped before installing it. '
          'Set up this machine… goes on with it.'
    : null;
