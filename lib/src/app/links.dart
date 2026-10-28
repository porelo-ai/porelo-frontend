import 'desk.dart';

/// Opens an address in this desktop's browser. Injectable, so a test records what it would open.
typedef OpenLink = Future<void> Function(Uri address);

/// What opens a link here: the desktop's own opener, quiet where there is none.
OpenLink openLink = _withTheDesktop;

/// Quiet where nothing opens it: the address is on screen to be copied by hand.
Future<void> _withTheDesktop(Uri address) => desk.open(address.toString());

/// A web address a terminal's program marked as a link.
class TerminalLink {
  /// Constructor taking the address and whether the machine marked it as its login's page.
  const TerminalLink(this.address, {this.isTheLogin = false});

  /// Where it points.
  final Uri address;

  /// Whether the machine marked it as its login's own page — the one whose reply comes back to the
  /// machine by itself (`id=porelo-login`). Read from the mark, never from the address.
  final bool isTheLogin;

  /// Whether only the task's own container reaches it: the gate's name as the task sees it, a
  /// loopback address, or a name without a dot. A browser here opens such an address somewhere else
  /// or nowhere.
  bool get onlyInsideTheTask {
    final host = address.host.toLowerCase();
    return host == 'host.containers.internal' ||
        host == 'localhost' ||
        host == '::1' ||
        host.startsWith('127.') ||
        !host.contains('.') && !host.contains(':');
  }

  @override
  bool operator ==(Object other) => other is TerminalLink && other.address == address && other.isTheLogin == isTheLogin;

  @override
  int get hashCode => Object.hash(address, isTheLogin);
}

/// The link an OSC 8 hyperlink carries, or null for the sequence that ends one, or for anything
/// that is not a web address — a terminal's link is never a way to run something here.
TerminalLink? hyperlinkOf(String code, List<String> arguments) {
  if (code != '8' || arguments.length < 2) return null;
  final address = Uri.tryParse(arguments.sublist(1).join(';'));
  if (address == null || !(address.isScheme('https') || address.isScheme('http'))) return null;
  // OSC 8's parameters are key=value pairs separated by colons.
  final marked = arguments.first.split(':').contains('id=porelo-login');
  return TerminalLink(address, isTheLogin: marked);
}
