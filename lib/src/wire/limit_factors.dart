import 'dart:math' as math;

/// The four factors every time limit of the window follows, as porelod read them from its configuration: an answer
/// from outside ([services]), a program or machine at work ([machines]), how often something is looked at again
/// ([polling]) and how a failed step is tried again ([retries]). Each is held in hundredths, as the limits line
/// writes it, so a factor read and written back is the same text.
class LimitFactors {
  const LimitFactors._(this._services, this._machines, this._polling, this._retries);

  /// All four at 1.0: a machine not read yet, or one that gives none.
  static const standard = LimitFactors._(100, 100, 100, 100);

  final int _services;
  final int _machines;
  final int _polling;
  final int _retries;

  /// The services factor as a decimal, for showing it.
  double get services => _services / 100;

  /// The machines factor as a decimal, for showing it.
  double get machines => _machines / 100;

  /// The polling factor as a decimal, for showing it.
  double get polling => _polling / 100;

  /// The retries factor as a decimal, for showing it.
  double get retries => _retries / 100;

  /// Whether all four are 1.0.
  bool get isStandard => _services == 100 && _machines == 100 && _polling == 100 && _retries == 100;

  /// [limit], a wait for an answer from outside, times the services factor, rounded up to a whole millisecond.
  Duration service(Duration limit) => _times(limit, _services);

  /// [limit], a wait for a program, container or machine, times the machines factor, rounded up to a millisecond.
  Duration machine(Duration limit) => _times(limit, _machines);

  /// [interval], how long until something is looked at again, times the polling factor.
  Duration poll(Duration interval) => _times(interval, _polling);

  /// [tries] times the retries factor, rounded up and never less than one.
  int tries(int tries) => math.max(1, (tries * _retries + 99) ~/ 100);

  /// [pause], the wait before a failed step is tried again, times the retries factor.
  Duration retryPause(Duration pause) => _times(pause, _retries);

  static Duration _times(Duration limit, int hundredths) =>
      Duration(milliseconds: (limit.inMicroseconds * hundredths + 100 * 1000 - 1) ~/ (100 * 1000));

  /// The limits line porelod writes: all four, in their order, each with at least one digit after its dot. Passed on
  /// as `--limits` only as read, never rebuilt; this form is for a machine that gave none.
  String get line =>
      'services=${_written(_services)},machines=${_written(_machines)},polling=${_written(_polling)},'
      'retries=${_written(_retries)}';

  static String _written(int hundredths) {
    final whole = hundredths ~/ 100;
    final part = hundredths % 100;
    if (part == 0) return '$whole.0';
    return part % 10 == 0 ? '$whole.${part ~/ 10}' : '$whole.${part.toString().padLeft(2, '0')}';
  }

  static const _names = ['services', 'machines', 'polling', 'retries'];
  static final _decimal = RegExp(r'^(0|[1-9][0-9]{0,2})(\.[0-9]{1,2})?$');

  /// Reads [line], the limits line: comma-separated `name=value`, each of the four names at most once, a name left out
  /// at 1.0, a value a decimal from 0.1 to 100 with at most two digits after its dot. Throws a [FormatException] naming
  /// what is wrong, as Porelo's own reader names it.
  static LimitFactors parse(String line) {
    final given = <String, int>{};
    if (line.isNotEmpty) {
      for (final part in line.split(',')) {
        final at = part.indexOf('=');
        if (at <= 0) throw FormatException("'$part' is no name=value");
        final name = part.substring(0, at);
        final value = part.substring(at + 1);
        if (!_names.contains(name)) throw FormatException("'$name' is no limit");
        if (given.containsKey(name)) throw FormatException('$name is given twice');
        final match = _decimal.firstMatch(value);
        if (match == null) throw FormatException("$name '$value' is no decimal");
        final fraction = (match.group(2) ?? '.').substring(1).padRight(2, '0');
        final hundredths = int.parse(match.group(1)!) * 100 + int.parse(fraction);
        if (hundredths < 10 || hundredths > 10000) {
          throw FormatException('$name ${_shown(value)} lies outside 0.1 to 100');
        }
        given[name] = hundredths;
      }
    }
    return LimitFactors._(
      given['services'] ?? 100,
      given['machines'] ?? 100,
      given['polling'] ?? 100,
      given['retries'] ?? 100,
    );
  }

  // A value out of range is named as the person wrote it, without trailing zeros after its dot.
  static String _shown(String value) =>
      value.contains('.') ? value.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '') : value;

  @override
  bool operator ==(Object other) =>
      other is LimitFactors &&
      other._services == _services &&
      other._machines == _machines &&
      other._polling == _polling &&
      other._retries == _retries;

  @override
  int get hashCode => Object.hash(_services, _machines, _polling, _retries);

  @override
  String toString() => line;
}

/// The factors each machine gave, by its name as the window shows it: read once per connection, kept across a lost
/// one, so what must run before the next read (a tunnel, a relay, the first call) runs with what the machine last
/// gave, and a machine not read yet, or one that gives none, with all four at 1.0.
class MachineLimits {
  final _given = <String, LimitFactors>{};
  final _lines = <String, String>{};

  /// The name of this computer's own machine, whose factors govern the limits tied to no machine; null until known.
  String? local;

  /// The factors [machine] last gave; this computer's own for null, all four at 1.0 where none were given.
  LimitFactors of(String? machine) => _given[machine ?? local] ?? LimitFactors.standard;

  /// The limits line [machine] last gave, unchanged, to pass on to a program started for it; null where it gave none.
  String? lineOf(String? machine) => _lines[machine ?? local];

  /// Whether [machine] gave its factors.
  bool gave(String machine) => _given.containsKey(machine);

  /// Keeps what [machine] gave: [line] as read, and the factors it holds.
  void keep(String machine, String line, LimitFactors factors) {
    _given[machine] = factors;
    _lines[machine] = line;
  }

  /// Forgets what [machine] gave, as for one that answered it gives none.
  void forget(String machine) {
    _given.remove(machine);
    _lines.remove(machine);
  }
}

/// The window's one record of what each machine gave.
final machineLimits = MachineLimits();

/// [limit], a wait for an answer from outside, as [machine]'s factors make it; this computer's own for null.
Duration serviceWait(Duration limit, {String? machine}) => machineLimits.of(machine).service(limit);

/// [limit], a wait for a program, container or machine, as [machine]'s factors make it; this computer's own for null.
Duration machineWait(Duration limit, {String? machine}) => machineLimits.of(machine).machine(limit);

/// [tries] of a step that waits for a program or machine, as [machine]'s machines factor makes them: as many more as
/// the wait between them stays the same, never fewer than one.
int machineTries(int tries, {String? machine}) =>
    _upTimes(tries, machineLimits.of(machine)._machines).clamp(1, 1 << 30);

/// [seconds], a whole-second wait handed to a program such as ssh, as [machine]'s machines factor makes it, rounded up.
int machineSeconds(int seconds, {String? machine}) => _upTimes(seconds, machineLimits.of(machine)._machines);

/// [whole] times [hundredths]/100, rounded up, in whole numbers alone.
int _upTimes(int whole, int hundredths) => (whole * hundredths + 99) ~/ 100;
