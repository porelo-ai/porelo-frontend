import 'package:porelo_host/porelo_host.dart' show LimitFactors, hostLimits;

export 'package:porelo_host/porelo_host.dart' show LimitFactors;

/// The factors each machine gave, by its name as the window shows it: read once per connection, kept across a lost
/// one, so what must run before the next read (a tunnel, a relay, the first call) runs with what the machine last
/// gave, and a machine not read yet, or one that gives none, with all four at 1.0.
class MachineLimits {
  final _given = <String, LimitFactors>{};
  final _lines = <String, String>{};

  /// The name of this computer's own machine, whose factors govern the limits tied to no machine; null until known.
  String? get local => _local;
  set local(String? machine) {
    _local = machine;
    _publish();
  }

  String? _local;

  // The host package, used in this process too, follows this computer's own factors, as porelo-host does when the
  // window starts it with their line.
  void _publish() => hostLimits = of(null);

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
    _publish();
  }

  /// Forgets what [machine] gave, as for one that answered it gives none.
  void forget(String machine) {
    _given.remove(machine);
    _lines.remove(machine);
    _publish();
  }
}

/// The window's one record of what each machine gave.
final machineLimits = MachineLimits();

/// What a Porelo program the window starts here, such as the planner or porelo-host, is given before its own
/// arguments: this computer's limits line, unchanged, as `--limits`, where its own machine gave one.
List<String> limitsArgumentsHere() => switch (machineLimits.lineOf(null)) {
  final line? when line.isNotEmpty => ['--limits', line],
  _ => const <String>[],
};

/// The person's own decisions about how long something holds, from their account's config.yml as its `porelod` read it:
/// whole days, each 1 to 3650.
class AccountSettings {
  /// Constructor taking each of the five, in days.
  const AccountSettings({
    required this.certificateDays,
    required this.cardDays,
    required this.renewNoticeDays,
    required this.askedAboutDays,
    required this.keptDays,
  });

  /// The longest a task certificate may live (task.certificate_days).
  final int certificateDays;

  /// How long an identity card lives (identity.card_days).
  final int cardDays;

  /// How long before a card ends its renewal is said (identity.renew_notice_days).
  final int renewNoticeDays;

  /// How long a question asked about is remembered (messages.asked_about_days).
  final int askedAboutDays;

  /// How long run records are kept (records.kept_days).
  final int keptDays;

  /// Reads one from an AccountSettings() reply; a field that is missing or out of 1 to 3650 is refused, never
  /// replaced by its default.
  factory AccountSettings.from(Map<String, dynamic> map) {
    int days(String name) {
      final value = map[name];
      if (value is! int || value < 1 || value > 3650) {
        throw FormatException('AccountSettings gave $name as ${value ?? 'nothing'}, not whole days from 1 to 3650');
      }
      return value;
    }

    return AccountSettings(
      certificateDays: days('certificateDays'),
      cardDays: days('cardDays'),
      renewNoticeDays: days('renewNoticeDays'),
      askedAboutDays: days('askedAboutDays'),
      keptDays: days('keptDays'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AccountSettings &&
      other.certificateDays == certificateDays &&
      other.cardDays == cardDays &&
      other.renewNoticeDays == renewNoticeDays &&
      other.askedAboutDays == askedAboutDays &&
      other.keptDays == keptDays;

  @override
  int get hashCode => Object.hash(certificateDays, cardDays, renewNoticeDays, askedAboutDays, keptDays);
}

/// What each machine's account settings are, as it last gave them.
class MachineSettings {
  final Map<String, AccountSettings> _given = <String, AccountSettings>{};

  /// What [machine] last gave; this computer's own for null; null where none were given, which nothing replaces by a
  /// default.
  AccountSettings? of(String? machine) => _given[machine ?? machineLimits.local];

  /// Whether [machine] gave its settings.
  bool gave(String machine) => _given.containsKey(machine);

  /// Keeps what [machine] gave.
  void keep(String machine, AccountSettings settings) => _given[machine] = settings;

  /// Forgets what [machine] gave.
  void forget(String machine) => _given.remove(machine);
}

/// The window's one record of each machine's account settings.
final machineSettings = MachineSettings();

/// [limit], a wait for an answer from outside, as [machine]'s factors make it; this computer's own for null.
Duration serviceWait(Duration limit, {String? machine}) => machineLimits.of(machine).service(limit);

/// [limit], a wait for a program, container or machine, as [machine]'s factors make it; this computer's own for null.
Duration machineWait(Duration limit, {String? machine}) => machineLimits.of(machine).machine(limit);

/// [every], how often something is looked at again, as [machine]'s polling factor makes it; this computer's for null.
Duration pollEvery(Duration every, {String? machine}) => machineLimits.of(machine).poll(every);

/// [pause], a wait before something failed is tried again, as [machine]'s retries factor makes it.
Duration retryWait(Duration pause, {String? machine}) => machineLimits.of(machine).retryPause(pause);

/// [tries] of something that failed, as [machine]'s retries factor makes them: rounded up, never fewer than one.
int retryTries(int tries, {String? machine}) => machineLimits.of(machine).tries(tries);

/// [tries] of a step that waits for a program or machine, as [machine]'s machines factor makes them: as many more as
/// the wait between them stays the same, never fewer than one.
int machineTries(int tries, {String? machine}) => machineLimits.of(machine).machineTries(tries);

/// [seconds], a whole-second wait handed to a program such as ssh, as [machine]'s machines factor makes it, rounded up.
int machineSeconds(int seconds, {String? machine}) => machineLimits.of(machine).machineSeconds(seconds);
