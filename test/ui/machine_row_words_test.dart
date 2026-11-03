import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/machines_page.dart';

void main() {
  String words({bool up = false, String? said, String? problem}) => machineRowWords(
    where: 'orchard',
    tunnelUp: up,
    tunnelWords: said,
    tunnelProblem: problem,
    fleet: 'not connected yet',
  );

  // Harm: a person reads the word null on a host that is simply up.
  test('a connection that is up and has nothing to say reads connected', () {
    expect(words(up: true), 'orchard · Connected');
  });

  // Harm: the same long refusal stands twice in one row.
  test('a problem is said once', () {
    expect(words(said: 'refused', problem: 'refused'), 'orchard · refused');
  });

  // Harm: a machine with no connection of its own loses what is known of it.
  test('with no connection, what the machine answered stands', () {
    expect(words(), 'orchard · not connected yet');
  });
}
