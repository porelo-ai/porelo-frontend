import 'package:porelo_frontend/src/app/connections.dart';

/// [line] as a person reads it — `ssh -t alice@vm porelo vault init` — as it is run: what follows
/// the host goes to the account's login shell, so the account finds its own `porelo`.
String asRunOverSsh(String line) {
  final words = line.split(' ');
  if (words.first != 'ssh') return line;
  final host = words[1] == '-t' ? 2 : 1;
  return <String>[...words.sublist(0, host + 1), inTheLoginShell(words.sublist(host + 1).join(' '))]
      .join(' ');
}
