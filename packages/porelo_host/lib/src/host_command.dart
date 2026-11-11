/// How porelo-host is run on a host over root's SSH: with none of the session's environment.
///
/// A root login carries what pam_systemd and sshd set, `DBUS_SESSION_BUS_ADDRESS`, `XDG_*` and `SSH_*` among it, and
/// porelo-host refuses those at its entry; it is given only a path and a locale.
const hostCommandEnvironment = 'env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin LANG=C.UTF-8';

/// The remote command that runs porelo-host with [arguments], as [hostCommandEnvironment] says.
String poreloHostCommand(String arguments) => '$hostCommandEnvironment /usr/sbin/porelo-host $arguments';
