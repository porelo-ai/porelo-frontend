import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'machines.dart';
import 'wsl.dart';

/// Runs a command in a WSL distribution, as its user or as root, and answers its exit code and
/// what it printed. Injectable, so a test's distribution is whatever it says.
typedef RunInWsl = Future<({int code, String said})> Function(String distribution, List<String> command, {bool asRoot});

/// The fingerprint of the key Porelo's package repository is signed with. **Carried here**, so a key
/// that arrives from the repository is checked against what this build was given, not against
/// itself: a key change needs a new version of the interface.
const poreloKeyFingerprint = 'BF27A2FA637F505CAFBE431768D19D175D904415';

/// Where the repository's key and packages are.
const poreloKeyAddress = 'https://fuinorg.jfrog.io/artifactory/api/security/keypair/porelo-packages/public';

/// Porelo's Debian package repository, with `releases` and `snapshots`.
const poreloDebRepository = 'https://fuinorg.jfrog.io/artifactory/porelo-dist-deb';

/// Porelo's RPM package repository, with `releases` and `snapshots`.
const poreloRpmRepository = 'https://fuinorg.jfrog.io/artifactory/porelo-dist-rpm';

/// The agents offered when Porelo is set up, as their packages are named. **None is chosen in
/// advance**: which agent somebody works with is theirs to say.
const poreloAgents = <({String package, String name})>[
  (package: 'porelo-agent-claude', name: 'Claude Code'),
  (package: 'porelo-agent-pi', name: 'Pi'),
  (package: 'porelo-agent-omp', name: 'Oh My Pi'),
];

/// One check before a WSL distribution is connected to, and what it found.
enum WslCheck {
  /// Windows' build, read here.
  windows('Windows is new enough for WSL2'),

  /// `wsl.exe` answering.
  installed('WSL is installed'),

  /// The distribution's WSL version.
  wsl2('The distribution runs under WSL2'),

  /// Its `/etc/os-release`.
  supported('The distribution is one Porelo supports'),

  /// Whether systemd is its init.
  systemd('systemd runs in it'),

  /// Whether `porelo` is on its path.
  porelo('Porelo is installed in it'),

  /// Whether its daemon answers through the relay.
  daemon('Its daemon answers');

  const WslCheck(this.title);

  /// What is checked, in words.
  final String title;
}

/// What one check found: passed, or failed with why and what to do.
class WslFinding {
  /// Constructor taking the check, whether it passed, and what it found.
  const WslFinding(this.check, {required this.passed, this.words = ''});

  /// The check this is the finding of.
  final WslCheck check;

  /// Whether it passed.
  final bool passed;

  /// Why it failed and what to do, or what was found, in words.
  final String words;
}

/// The system a distribution says it is, from its `/etc/os-release`.
class OsRelease {
  /// Constructor taking each field as `/etc/os-release` names it.
  const OsRelease({required this.id, required this.version, required this.name});

  /// Read from `/etc/os-release`'s text: `ID`, `VERSION_ID` and `PRETTY_NAME`.
  factory OsRelease.parse(String text) {
    final values = <String, String>{};
    for (final line in const LineSplitter().convert(text)) {
      final at = line.indexOf('=');
      if (at <= 0) continue;
      var value = line.substring(at + 1).trim();
      if (value.length >= 2 && (value.startsWith('"') || value.startsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }
      values[line.substring(0, at).trim()] = value;
    }
    return OsRelease(
      id: values['ID'] ?? '',
      version: values['VERSION_ID'] ?? '',
      name: values['PRETTY_NAME'] ?? values['NAME'] ?? 'an unknown system',
    );
  }

  /// `ID`: `ubuntu`, `debian`, `fedora`.
  final String id;

  /// `VERSION_ID`: `26.04`, `13`, `43`.
  final String version;

  /// `PRETTY_NAME`, as a person reads it.
  final String name;

  /// Whether Porelo supports it: Ubuntu 26.04 or later, Debian 13, Fedora 43 or 44.
  bool get supported => switch (id) {
    'ubuntu' => _atLeast(version, 26, 4),
    'debian' => version == '13',
    'fedora' => version == '43' || version == '44',
    _ => false,
  };

  /// Whether its packages come through `apt`; `dnf` else.
  bool get usesApt => id == 'ubuntu' || id == 'debian';

  static bool _atLeast(String version, int major, int minor) {
    final parts = version.split('.');
    final a = int.tryParse(parts.first) ?? 0;
    final b = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return a > major || (a == major && b >= minor);
  }
}

/// The Windows build number from `Platform.operatingSystemVersion`, as `"Windows 10 Pro" 10.0
/// (Build 19045)` says it, or null where it says none.
int? windowsBuild(String operatingSystemVersion) =>
    int.tryParse(RegExp(r'Build (\d+)').firstMatch(operatingSystemVersion)?.group(1) ?? '');

/// WSL2 needs Windows 10 version 2004, build 19041, or later; every Windows 11 is later.
const int firstWsl2Build = 19041;

/// The lines that set Porelo up in a distribution, each shown before anything runs.
class SetupLine {
  /// Constructor taking what runs, whether as root, and what for.
  const SetupLine(this.command, {required this.asRoot, required this.why});

  /// What runs, as the program and its arguments; shown joined.
  final List<String> command;

  /// Whether it runs as root, after the person said yes to it.
  final bool asRoot;

  /// What it is for, in words.
  final String why;

  /// The line as a person would type it in the distribution: a line for the shell as root is shown
  /// as `sudo sh -c '…'`, since a redirection after a bare `sudo` would be the person's own.
  String get shown {
    final shell = command.length == 3 && command[0] == 'sh' && command[1] == '-c';
    if (!asRoot) return shell ? command[2] : command.join(' ');
    return shell ? "sudo sh -c '${command[2].replaceAll("'", r"'\''")}'" : 'sudo ${command.join(' ')}';
  }
}

/// The checks before a WSL distribution is connected to, and the offer to set Porelo up in one that
/// lacks it.
///
/// **Nothing runs as root but the lines a person said yes to, after they were shown**, and every one
/// of them is recorded with what it answered. A distribution that is stopped is never started, and
/// one without systemd is restarted only after a question of its own, whose answer is no unless
/// the person changes it.
class WslSetup extends ChangeNotifier {
  /// Constructor taking the distribution, Windows' version, and, for a test, how WSL is reached and
  /// a line run.
  WslSetup({
    required this.distribution,
    required this.operatingSystemVersion,
    Wsl? wsl,
    RunInWsl? run,
    this.answers,
    this.record,
  }) : _wsl = wsl ?? Wsl(),
       _run = run ?? _runForReal;

  /// The distribution's name, as `wsl.exe -d` takes it.
  final String distribution;

  /// `Platform.operatingSystemVersion`, from which the Windows build is read.
  final String operatingSystemVersion;

  final Wsl _wsl;
  final RunInWsl _run;

  /// Whether a machine's daemon answers; null where nothing can ask.
  final Future<bool> Function(Machine machine)? answers;

  /// Records a line that ran as root or as the user, with what it answered: the operations record.
  final void Function(String line, String said)? record;

  /// What each check found so far, in order; the last one is where it stopped, when it failed.
  final List<WslFinding> findings = <WslFinding>[];

  /// What the distribution says it is, once read.
  OsRelease? system;

  /// The agents chosen for the setup. Empty until the person chooses.
  final Set<String> agents = <String>{};

  /// Whether a check or a setup line runs now.
  bool busy = false;

  /// What a setup line answered, line by line, while it runs and after.
  final List<String> said = <String>[];

  /// Why the setup stopped, or null.
  String? stopped;

  /// The machine to watch, once every check passed.
  Machine get machine => Machine(name: distribution, socketPath: '', kind: 'wsl', distribution: distribution);

  /// Whether every check passed.
  bool get ready => findings.length == WslCheck.values.length && findings.every((each) => each.passed);

  /// The check that failed, or null.
  WslFinding? get failed {
    for (final each in findings) {
      if (!each.passed) return each;
    }
    return null;
  }

  /// Whether the failure is one the setup offer answers: Porelo missing, or its daemon silent.
  bool get offersTheSetup => failed?.check == WslCheck.porelo || failed?.check == WslCheck.daemon;

  /// Whether the failure is systemd, answered by the separate question with the restart.
  bool get asksForSystemd => failed?.check == WslCheck.systemd;

  /// Runs the checks in order and stops at the first that fails.
  Future<void> check() async {
    findings.clear();
    stopped = null;
    busy = true;
    notifyListeners();
    try {
      for (final each in WslCheck.values) {
        final found = await _check(each);
        findings.add(found);
        notifyListeners();
        if (!found.passed) return;
      }
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<WslFinding> _check(WslCheck check) async {
    switch (check) {
      case WslCheck.windows:
        final build = windowsBuild(operatingSystemVersion);
        return build != null && build < firstWsl2Build
            ? WslFinding(
                check,
                passed: false,
                words:
                    'This Windows is build $build. WSL2 needs Windows 10 '
                    'version 2004 (build $firstWsl2Build) or later, or Windows 11; there is no WSL way here.',
              )
            : WslFinding(check, passed: true, words: build == null ? '' : 'build $build');
      case WslCheck.installed:
        final all = await _wsl.distributions();
        return all.isEmpty
            ? WslFinding(
                check,
                passed: false,
                words:
                    'WSL answers with no distribution. Install WSL '
                    'and a distribution from a terminal: wsl --install -d Ubuntu-26.04 — then come back here.',
              )
            : WslFinding(check, passed: true);
      case WslCheck.wsl2:
        final why = await _wsl.whyNotNow(distribution);
        return WslFinding(check, passed: why == null, words: why ?? '');
      case WslCheck.supported:
        final read = await _run(distribution, const <String>['cat', '/etc/os-release'], asRoot: false);
        final release = OsRelease.parse(read.said);
        system = release;
        return release.supported
            ? WslFinding(check, passed: true, words: release.name)
            : WslFinding(
                check,
                passed: false,
                words:
                    '$distribution is ${release.name}. Porelo supports '
                    'Ubuntu 26.04 or later, Debian 13, and Fedora 43 and 44, so nothing is offered to set it up here.',
              );
      case WslCheck.systemd:
        final state = await _run(distribution, const <String>['systemctl', 'is-system-running'], asRoot: false);
        final running = <String>{'running', 'degraded', 'starting'}.contains(state.said.trim());
        return running
            ? WslFinding(check, passed: true, words: state.said.trim())
            : WslFinding(
                check,
                passed: false,
                words:
                    'systemd does not run in it. Porelo runs as a '
                    'user service, so systemd must be turned on, and the distribution restarted.',
              );
      case WslCheck.porelo:
        final version = await _run(distribution, const <String>['porelo', '--version'], asRoot: false);
        return version.code == 0
            ? WslFinding(check, passed: true, words: version.said.trim())
            : WslFinding(check, passed: false, words: 'Porelo is not installed in it.');
      case WslCheck.daemon:
        final answering = await (answers?.call(machine) ?? Future<bool>.value(false));
        return answering
            ? WslFinding(check, passed: true)
            : WslFinding(
                check,
                passed: false,
                words:
                    'Porelo is installed, and its daemon does not '
                    'answer. Setting it up as its user starts it.',
              );
    }
  }

  /// The user the distribution runs as by default: the one Porelo is set up for.
  Future<String> user() async => (await _run(distribution, const <String>['id', '-un'], asRoot: false)).said.trim();

  /// The lines that set Porelo up here, for [user], with the agents chosen. Porelo's own
  /// `getting-started.md` says the same for each package manager.
  List<SetupLine> setupLines(String user, {bool snapshots = false}) {
    final release = system;
    final apt = release?.usesApt ?? true;
    final chosen = <String>[
      for (final agent in poreloAgents)
        if (agents.contains(agent.package)) agent.package,
    ];
    return <SetupLine>[
      SetupLine(
        <String>['sh', '-c', 'curl -fsSL $poreloKeyAddress -o /tmp/porelo.asc'],
        asRoot: true,
        why: "Fetches the key Porelo's packages are signed with.",
      ),
      if (apt) ...<SetupLine>[
        const SetupLine(
          <String>['gpg', '--dearmor', '--yes', '-o', '/usr/share/keyrings/porelo.gpg', '/tmp/porelo.asc'],
          asRoot: true,
          why: 'Keeps the key where apt reads it, once its fingerprint is checked.',
        ),
        SetupLine(
          <String>[
            'sh',
            '-c',
            'echo "deb [signed-by=/usr/share/keyrings/porelo.gpg] $poreloDebRepository ${snapshots ? 'snapshots' : 'releases'} main" '
                '> /etc/apt/sources.list.d/porelo.list',
          ],
          asRoot: true,
          why: "Adds Porelo's package repository.",
        ),
        SetupLine(
          <String>['sh', '-c', 'apt-get update && apt-get install -y porelo ${chosen.join(' ')}'.trim()],
          asRoot: true,
          why: 'Installs Porelo and the agents chosen.',
        ),
      ] else ...<SetupLine>[
        const SetupLine(
          <String>['install', '-D', '-m', '0644', '/tmp/porelo.asc', '/etc/pki/rpm-gpg/porelo.asc'],
          asRoot: true,
          why: 'Keeps the key where dnf reads it, once its fingerprint is checked.',
        ),
        SetupLine(
          <String>[
            'sh',
            '-c',
            "printf '[porelo]\\nname=Porelo\\nbaseurl=$poreloRpmRepository/${snapshots ? 'snapshots' : 'releases'}\\n"
                "enabled=1\\ngpgcheck=0\\nrepo_gpgcheck=1\\ngpgkey=file:///etc/pki/rpm-gpg/porelo.asc\\n' "
                '> /etc/yum.repos.d/porelo.repo',
          ],
          asRoot: true,
          why: "Adds Porelo's package repository, its index checked against the key.",
        ),
        SetupLine(
          <String>['sh', '-c', 'dnf install -y porelo ${chosen.join(' ')}'.trim()],
          asRoot: true,
          why: 'Installs Porelo and the agents chosen.',
        ),
      ],
      SetupLine(
        <String>['loginctl', 'enable-linger', user],
        asRoot: true,
        why: "Keeps $user's services running when no session is open, Porelo's daemon among them.",
      ),
      const SetupLine(
        <String>['porelo', 'setup'],
        asRoot: false,
        why: 'Sets Porelo up for this user and starts its daemon.',
      ),
    ];
  }

  /// The fingerprint of the key fetched to `/tmp/porelo.asc`, or null where none could be read; a file
  /// holding more than one key is answered as how many, with each fingerprint, which no carried one equals.
  Future<String?> fetchedFingerprint() async {
    final shown = await _run(distribution, const <String>[
      'gpg',
      '--show-keys',
      '--with-colons',
      '/tmp/porelo.asc',
    ], asRoot: true);
    // One primary key's fingerprint per `pub` record: the `fpr` after a `sub` is its own subkey's.
    // A file with a second primary key is not Porelo's key, however the first one reads.
    final primaries = <String>[];
    var afterPrimary = false;
    for (final line in const LineSplitter().convert(shown.said)) {
      if (line.startsWith('pub:')) {
        afterPrimary = true;
      } else if (line.startsWith('sub:')) {
        afterPrimary = false;
      } else if (line.startsWith('fpr:') && afterPrimary) {
        final fields = line.split(':');
        if (fields.length > 9 && fields[9].isNotEmpty) primaries.add(fields[9]);
        afterPrimary = false;
      }
    }
    return switch (primaries) {
      [] => null,
      [final only] => only,
      _ => '${primaries.length} keys, ${primaries.join(', ')}',
    };
  }

  /// Runs the setup [lines] in order, after a yes to exactly them. The key is checked against
  /// [poreloKeyFingerprint] right after it is fetched; a key that does not match stops the setup
  /// before anything else is written. Stops at the first line that fails, saying why.
  Future<void> runSetup(List<SetupLine> lines) async {
    busy = true;
    stopped = null;
    said.clear();
    notifyListeners();
    try {
      for (final line in lines) {
        said.add('\$ ${line.shown}');
        notifyListeners();
        final answer = await _run(distribution, line.command, asRoot: line.asRoot);
        if (answer.said.trim().isNotEmpty) said.add(answer.said.trimRight());
        record?.call(line.shown, answer.said);
        notifyListeners();
        if (answer.code != 0) {
          stopped = '"${line.shown}" ended with ${answer.code}. Nothing after it ran.';
          return;
        }
        if (line.command.join(' ').contains('-o /tmp/porelo.asc')) {
          final came = await fetchedFingerprint();
          if (came != poreloKeyFingerprint) {
            stopped =
                'The key that came is not the one this interface carries. Expected '
                '$poreloKeyFingerprint, and it came as ${came ?? 'no key at all'}. Nothing was written.';
            record?.call('check the key', stopped!);
            return;
          }
          said.add('The key is $poreloKeyFingerprint, as expected.');
        }
      }
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// The line that turns systemd on, shown before it runs, as root.
  static const turnSystemdOn = SetupLine(
    <String>['sh', '-c', "printf '[boot]\\nsystemd=true\\n' >> /etc/wsl.conf"],
    asRoot: true,
    why: 'Turns systemd on for the next start of the distribution.',
  );

  /// Turns systemd on and restarts the distribution, after its own yes: everything running in it
  /// ends. The next call into it starts it again, the one time the interface starts a distribution.
  Future<void> turnOnSystemdAndRestart({required Future<int> Function(List<String> arguments) wslExe}) async {
    await runSetup(const <SetupLine>[turnSystemdOn]);
    if (stopped != null) return;
    final ended = await wslExe(<String>['--terminate', distribution]);
    record?.call('wsl.exe --terminate $distribution', 'exit $ended');
    if (ended != 0) stopped = 'wsl.exe --terminate $distribution ended with $ended.';
    notifyListeners();
  }

  static Future<({int code, String said})> _runForReal(
    String distribution,
    List<String> command, {
    bool asRoot = false,
  }) async {
    final arguments = <String>[
      '-d',
      distribution,
      if (asRoot) ...<String>['-u', 'root'],
      '--exec',
      ...command,
    ];
    final result = await Wsl.runWslExe(arguments);
    return (code: result.code, said: decodeWsl(result.printed));
  }
}
