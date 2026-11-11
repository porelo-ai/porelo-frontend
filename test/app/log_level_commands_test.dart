import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/window_log.dart';

void main() {
  List<Command> commands({
    LogLevel level = LogLevel.info,
    void Function(LogLevel)? choose,
    LogLevel? plannersLevel,
    String? plannersProblem,
  }) => logCommands(
    windowsLog: '/state/logs/frontend.log',
    plannersLog: null,
    open: (_, _) {},
    level: level,
    choose: choose ?? (_) {},
    plannersLevel: plannersLevel,
    plannersProblem: plannersProblem,
  );

  Command named(List<Command> all, String id) => all.singleWhere((command) => command.id == id);

  // Harm: a person who wants to see more, or less, finds no way to say so, or cannot tell which level is in force.
  test('Logs offers the four levels, the one in force checked, and choosing one chooses it', () {
    final chosen = <LogLevel>[];
    final all = commands(level: LogLevel.warn, choose: chosen.add);

    final levels = all.where((command) => command.id.startsWith('log.level.')).toList();
    expect(levels.map((command) => command.label), [
      'Log level: ERROR',
      'Log level: WARN',
      'Log level: INFO (the usual)',
      'Log level: DEBUG',
    ]);
    expect(levels.map((command) => command.group).toSet(), {logsGroup});
    expect(levels.where((command) => command.checked ?? false).map((command) => command.id), ['log.level.warn']);
    named(all, 'log.level.debug').run();
    expect(chosen, [LogLevel.debug]);
  });

  // Harm: the person believes both logs follow the choice while the planner's does not.
  test('a planner at another level, or one that did not take it, is said beside the levels', () {
    expect(commands().where((command) => command.id == 'log.level.planner'), isEmpty);
    expect(commands(plannersLevel: LogLevel.info).where((command) => command.id == 'log.level.planner'), isEmpty);

    final other = named(commands(plannersLevel: LogLevel.error), 'log.level.planner');
    expect(other.label, 'The planner’s log is at ERROR, not INFO');
    expect(other.unavailable, isNotNull);

    final refused = named(commands(plannersProblem: 'it needs a newer planner'), 'log.level.planner');
    expect(refused.label, 'The planner’s log keeps its own level: it needs a newer planner');
  });

  // Harm: the level chosen is forgotten at the next start, or one never chosen is not INFO.
  test('the level is INFO where none was chosen, and a chosen one is kept for the next run', () async {
    final store = MemorySettingsStore();
    final first = Settings(store);
    await first.load();
    expect(first.logLevel.value, LogLevel.info);

    await first.setLogLevel(LogLevel.debug);
    final next = Settings(store);
    await next.load();
    expect(next.logLevel.value, LogLevel.debug);
  });
}
