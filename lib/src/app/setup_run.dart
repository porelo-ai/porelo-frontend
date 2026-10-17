import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'connection_trial.dart';
import 'connections.dart';
import 'host_keys.dart';
import 'machine_setup.dart';
import 'machines.dart';
import 'settings.dart';

/// The steps of preparing a machine, in order. Adding a user to a machine prepared before walks
/// the same steps; only what the first one asks differs.
enum SetupStep {
  /// The key it is reached with.
  key,

  /// Where it is, and root logging in.
  where,

  /// Porelo's setup script.
  prepare,

  /// Reaching it as the work user.
  reach,

  /// Making the vault, in a terminal the person types the passphrase into.
  vault,

  /// Optionally turning off root and password login, then watching it.
  harden,
}

/// What a root script is run for, so its lines are shown where that action is.
enum RootAction {
  /// Asking what the machine could install.
  list,

  /// Asking what the setup script would do.
  show,

  /// Running the setup script.
  prepare,

  /// Closing root's way in.
  harden,
}

/// One run of the machine wizard: what was said, what was done, and what is being done now.
///
/// **Held apart from the screen** so going back and forth never loses anything, and **kept in the
/// settings** after every step so a canceled wizard or a closed window picks up where it stopped.
/// What is kept never includes a private key: only where a kept one lives.
class SetupRun extends ChangeNotifier {
  /// Constructor taking what the first page said and what does the work.
  SetupRun({
    required this.name,
    required this.workUser,
    required this.setup,
    this.addingAUser = false,
    this.hostKeys,
    this.trying,
    this.remember,
    this.countKeyslots,
  }) : keyFile = addingAUser ? (setup.existingKeys().firstOrNull ?? setup.sshKeys().firstOrNull ?? '') : '';

  /// Picks a run up again from what [toStored] kept, or null when it is not one.
  static SetupRun? fromStored(
    Map<String, Object?> stored, {
    required MachineSetup setup,
    HostKeys? hostKeys,
    Future<Trial> Function(Machine machine)? trying,
    Future<void> Function(Map<String, Object?>? draft)? remember,
    Future<int?> Function(Machine machine)? countKeyslots,
  }) {
    String text(String key) => stored[key] is String ? stored[key] as String : '';
    // A kept draft is read again as if typed: what reaches root's command line is checked here too.
    if (text('name').isEmpty || !Settings.isUserName(text('workUser'))) return null;
    final run = SetupRun(
      name: text('name'),
      workUser: text('workUser'),
      setup: setup,
      addingAUser: stored['addingAUser'] == true,
      hostKeys: hostKeys,
      trying: trying,
      remember: remember,
      countKeyslots: countKeyslots,
    );
    run
      ..publicKey = text('publicKey')
      ..host = text('host')
      ..prepared = stored['prepared'] == true;
    final kept = text('kept');
    // A kept key that is no longer there is no key: that step is asked again.
    if (kept.isNotEmpty && File(kept).existsSync()) {
      run
        ..kept = kept
        ..keyFile = kept;
    }
    final userKey = text('userKeyFile');
    if (userKey.isNotEmpty && File(userKey).existsSync()) run.userKeyFile = userKey;
    final chosen = stored['chosen'];
    if (chosen is List) run.chosen.addAll(chosen.whereType<String>().where(MachineSetup.isPackageName));
    final step = SetupStep.values.where((each) => each.name == text('step')).firstOrNull;
    run.step = run.kept == null ? SetupStep.key : (step ?? SetupStep.key);
    // Root has to log in again after a pause; that is cheap, and proves the key still works.
    if (run.step.index > SetupStep.where.index && !run.prepared) run.step = SetupStep.where;
    if (run.step.index > SetupStep.reach.index) run.step = SetupStep.reach;
    return run;
  }

  /// What the machine is called, which names its key and its `Host` entry.
  final String name;

  /// The user it runs work as.
  final String workUser;

  /// Whether this only adds a user to a machine prepared before.
  final bool addingAUser;

  /// Makes and checks the key, and runs commands there.
  final MachineSetup setup;

  /// Confirms the host key before the first login, or null where nothing can.
  final HostKeys? hostKeys;

  /// Tries the prepared machine the way watching it will, or null where nothing can.
  final Future<Trial> Function(Machine machine)? trying;

  /// Keeps the run for later, or forgets it with null.
  final Future<void> Function(Map<String, Object?>? draft)? remember;

  /// How many ways into a machine's vault there are, or null when it could not be asked.
  final Future<int?> Function(Machine machine)? countKeyslots;

  /// Whether the machine has a vault, as its daemon last said; null before it was asked.
  bool? hasVault;

  SetupStep step = SetupStep.key;

  /// The pasted or generated key, before it is kept.
  String privateKey = '';
  String publicKey = '';

  /// The key file root logs in with, when adding a user.
  String keyFile;

  /// Where the admin key was kept, once it was.
  String? kept;

  /// The work user's own key, chosen from `~/.ssh`, or null to have one made for it.
  String? userKeyFile;

  /// Its public half, once it is known.
  String userPublicKey = '';

  /// The server's name or address, as typed.
  String host = '';

  /// Whether root logged in with the kept key, for the host as it is now typed.
  String? loggedInTo;

  /// What the machine could install; null before it was asked.
  List<InstallablePackage>? offered;

  /// What the choice leaves the machine without, said before anything runs; null where it has what
  /// it needs, or nothing was listed to choose from.
  String? get choiceLacks {
    final listed = offered;
    if (listed == null || listed.isEmpty) return null;
    bool has(InstallablePackage each) => each.installed || chosen.contains(each.name);
    // Its kind is the virtual name it provides, without `porelo-`, as the setup script has it. It
    // depends on the transport, so choosing it brings the transport, which the list does not
    // mark; the packages' metadata says so. The filter comes with the
    // transport by the package's own dependency, so it needs no rule here.
    final homeservers = listed.where((each) => each.kind == 'homeserver');
    final transports = listed.where((each) => each.kind == 'transport' && !homeservers.contains(each));
    if (transports.isEmpty && homeservers.isEmpty) return null;
    if (homeservers.any(has)) return null;
    if (!transports.any(has)) {
      return 'With no transport chosen, its work cannot send or receive messages: a project with '
          'messages refuses to start there. Choose ${[...transports, ...homeservers].map((each) => each.name).join(' or ')}.';
    }
    if (homeservers.isEmpty) return null;
    return 'The transport alone carries messages only for a project that names a homeserver of its own '
        'in its project.yml; any other refuses to start. Choose ${homeservers.first.name} for one on '
        'this machine.';
  }

  /// The packages chosen besides what is always installed.
  final Set<String> chosen = <String>{};

  /// What `--show` printed, and for which choice.
  String? shown;
  String? shownFor;

  /// The SHA-256 of the script [shown] came from: what [prepare] runs, and nothing else.
  String? shownDigest;

  /// What the running script printed so far, line by line.
  final List<String> output = <String>[];

  /// Which action [output] belongs to, so it is shown with that action and no other.
  RootAction? outputOf;

  /// Whether the setup script prepared the machine.
  bool prepared = false;

  /// What reaching it as the work user did, line by line.
  final List<String> log = <String>[];

  /// The machine as it will be watched, once it answered.
  Machine? ready;

  /// What `porelo doctor` refused, line by line, when it did not pass; null when it passed or was
  /// not asked. **A machine that answers but fails `doctor` can be watched, and cannot run a task**:
  /// the setup script's exit says only that its steps ran, and `doctor` is the check.
  List<String>? doctorFound;

  /// Whether root and password logins were turned off.
  bool hardened = false;

  /// What is being done right now, in words, or null when nothing is.
  String? doing;

  /// What the last action said, and whether it was a refusal.
  String? said;
  bool saidIsBad = false;

  bool get busy => doing != null;

  /// The admin key's file name under `~/.ssh`: root's, for setting up, never the daily one.
  String get keyName => 'porelo-${Machine.slug(name)}-admin';

  /// The work user's own key's file name: the only key its `Host` entry and the interface use.
  String get userKeyName => 'porelo-${Machine.slug(name)}-${Machine.slug(workUser)}';

  /// The `Host` entry the machine is reached through.
  String get alias => 'porelo-${Machine.slug(name)}';

  /// The choice as one comparable word.
  String get choice => (chosen.toList()..sort()).join(' ');

  /// Whether the step showing is done, so the wizard may go on.
  bool get canGoOn => switch (step) {
    SetupStep.key => kept != null,
    SetupStep.where => loggedInTo != null && loggedInTo == host.trim(),
    SetupStep.prepare => prepared,
    SetupStep.reach => ready != null,
    // Not left while the machine says there is none: a machine left with no vault refused the
    // first credential later, far from where it is made. Where it
    // could not be asked, it is not held up on that.
    SetupStep.vault => hasVault != false,
    SetupStep.harden => false,
  };

  bool get isFirst => step == SetupStep.key;
  bool get isLast => step == SetupStep.harden;

  void next() => _goTo(SetupStep.values[step.index + 1]);
  void previous() => _goTo(SetupStep.values[step.index - 1]);

  void _goTo(SetupStep to) {
    step = to;
    said = null;
    notifyListeners();
    _keep();
    // A machine set up before may have its vault already: asked at once, so the step is left
    // without making a second one.
    if (to == SetupStep.vault && hasVault != true) unawaited(_askAboutTheVaultQuietly());
  }

  /// Something the person typed or ticked: kept, and drawn again.
  void changed() {
    notifyListeners();
    _keep();
  }

  /// What is kept of this run: never a private key.
  Map<String, Object?> toStored() => <String, Object?>{
    'name': name,
    'workUser': workUser,
    'addingAUser': addingAUser,
    'step': step.name,
    'kept': kept ?? '',
    'publicKey': kept == null ? '' : publicKey,
    'host': host,
    'prepared': prepared,
    'chosen': chosen.toList()..sort(),
    'userKeyFile': userKeyFile ?? '',
  };

  void _keep() => remember?.call(toStored());

  /// Forgets the run: it was finished, or the person discarded it.
  Future<void> forget() async => remember?.call(null);

  Future<void> generate() => _doing('Generating a key pair…', () async {
    final pair = await setup.generate('porelo $name');
    privateKey = pair.privateKey;
    publicKey = pair.publicKey;
    return null;
  });

  Future<void> keep() => _doing('Checking the two halves belong together…', () async {
    final pair = KeyPair(privateKey: privateKey, publicKey: publicKey.trim());
    final wrong = await setup.mismatch(pair);
    if (wrong != null) throw MachineSetupFailed(wrong);
    kept = await setup.save(pair, keyName);
    return 'Kept as $kept.';
  });

  Future<void> useKey() => _doing('Reading the key…', () async {
    final file = keyFile.trim();
    publicKey = await setup.publicKeyOf(file);
    kept = file;
    return 'Root logs in with $file, and $workUser will too.';
  });

  /// Logs in as root, asking [confirm] about a host key seen for the first time.
  Future<void> tryRoot(Future<bool> Function(HostKeyCheck check) confirm) => _doing('Logging in as root…', () async {
    final target = host.trim();
    loggedInTo = null;
    final keys = hostKeys;
    if (keys != null) {
      final check = await keys.check('root@$target');
      if (check.problem != null) throw MachineSetupFailed(check.problem!);
      if (!check.known) {
        if (!await confirm(check)) {
          throw MachineSetupFailed('The host key of ${check.host} was not trusted, so nothing logged in.');
        }
        await keys.accept(check);
      }
    }
    final failed = await setup.loginAsRoot(target, kept!);
    if (failed != null) throw MachineSetupFailed(failed);
    loggedInTo = target;
    return 'Logged in as root on $target with $kept.';
  });

  Future<void> listPackages() => _doing('Asking the machine what it can install…', () async {
    final listed = await _root(RootAction.list, MachineSetup.listInstallable());
    if (listed.exitCode != 0) {
      throw MachineSetupFailed('${MachineSetup.whatTheScriptSaid(listed.exitCode)}\n${both(listed)}'.trim());
    }
    offered = MachineSetup.installableIn('${listed.stdout}');
    chosen.removeWhere((name) => !offered!.any((each) => each.name == name));
    final why = '${listed.stderr}'.trim();
    return offered!.isEmpty && why.isNotEmpty ? why : null;
  });

  Future<void> show() => _doing("Fetching Porelo's setup script and asking what it would do…", () async {
    shown = null;
    shownDigest = null;
    final now = choice;
    final result = await _root(RootAction.show, MachineSetup.show(workUser, chosen.toList()..sort()));
    final said = both(result);
    if (result.exitCode != 0) {
      throw MachineSetupFailed('${MachineSetup.whatTheScriptSaid(result.exitCode)}\n$said');
    }
    shown = said;
    shownFor = now;
    shownDigest = MachineSetup.digestIn(said);
    return null;
  });

  Future<void> prepare() => _doing("Running Porelo's setup script as root…", () async {
    final digest = shownDigest;
    if (digest == null) throw const MachineSetupFailed('What the setup script would do has to be shown first.');
    final ran = await _root(
      RootAction.prepare,
      MachineSetup.prepare(workUser, chosen.toList()..sort(), digest: digest),
    );
    if (ran.exitCode != 0) throw MachineSetupFailed(MachineSetup.whatTheScriptSaid(ran.exitCode));
    prepared = true;
    return MachineSetup.whatTheScriptSaid(0);
  });

  /// Chooses a key already in `~/.ssh` for the work user instead of having one made.
  void useUserKey(String? file) {
    userKeyFile = file;
    userPublicKey = '';
    changed();
  }

  Future<void> reach() => _doing('Setting it up for $workUser and connecting…', () async {
    log.clear();
    // The work user's own key: chosen, or made once and found again on a second run.
    var userKey = userKeyFile;
    if (userKey == null) {
      final made = '${setup.sshDirectory}/$userKeyName';
      if (!File(made).existsSync()) {
        await setup.save(await setup.generate('porelo $name $workUser'), userKeyName);
        _logged('Made a key of its own for $workUser: $made.');
      }
      userKey = made;
      userKeyFile = made;
    }
    userPublicKey = await setup.publicKeyOf(userKey);
    final allowed = await setup.asRoot(loggedInTo!, kept!, MachineSetup.authorize(workUser, userPublicKey));
    if (allowed.exitCode != 0) {
      throw MachineSetupFailed('The key could not be allowed for $workUser: ${both(allowed)}');
    }
    _logged('$workUser logs in with its own key only; its password stays locked.');
    _logged(await setup.addHostEntry(alias: alias, host: loggedInTo!, user: workUser, keyFile: userKey));
    final started = await setup.asUser(alias, 'systemctl --user enable --now porelod');
    if (started.exitCode != 0) {
      throw MachineSetupFailed('Porelo did not start as $workUser: ${both(started)}');
    }
    _logged('Porelo runs as $workUser.');
    // The work user's step, never root's: podman reads its hook descriptors per user, so only
    // that account knows whose configuration to write. Without it a task runs with no firewall
    // until the first start registers them, and `porelo doctor` says so.
    final registered = await setup.asUser(alias, 'porelo setup');
    if (registered.exitCode != 0) {
      throw MachineSetupFailed('porelo setup did not register what a task needs: ${both(registered)}');
    }
    _logged("Porelo's hooks are registered for $workUser.");
    final uid = await setup.asUser(alias, 'id -u');
    final id = '${uid.stdout}'.trim();
    if (uid.exitCode != 0 || int.tryParse(id) == null) {
      throw MachineSetupFailed('Which uid $workUser has could not be asked: ${both(uid)}');
    }
    final doctor = await setup.asUser(alias, 'porelo doctor');
    _logged('porelo doctor${doctor.exitCode == 0 ? '' : ' (ended with ${doctor.exitCode})'}:');
    _logged(both(doctor));
    doctorFound = refusedBy(doctor);
    messages = await _canCarryMessages(both(doctor));
    final machine = Machine(
      name: name,
      socketPath: Machine.endpointFor(name),
      host: alias,
      remoteSocket: '/run/user/$id/porelo/porelod.sock',
    );
    final trying = this.trying;
    if (trying != null) {
      final trial = await trying(machine);
      _logged(trial.words);
      if (!trial.reached) throw MachineSetupFailed('It does not answer yet: ${trial.words}');
    }
    ready = machine;
    return _readiness();
  });

  /// Asks `porelo doctor` again, for a finding fixed at the machine since.
  Future<void> askDoctorAgain() => _doing('Asking porelo doctor again…', () async {
    final doctor = await setup.asUser(alias, 'porelo doctor');
    doctorFound = refusedBy(doctor);
    return _readiness();
  });

  /// Whether the machine can carry its projects' messages, in one sentence: the Matrix transport as
  /// `porelo doctor` lists it, and a homeserver on the machine as its unit says; null where neither
  /// could be asked.
  String? messages;

  Future<String?> _canCarryMessages(String doctorSaid) async {
    final transport = doctorSaid.split('\n').where((line) => line.contains('transports')).join(' ');
    final hasMatrix = transport.contains('matrix');
    final unit = await setup.asUser(alias, 'systemctl --user show porelo-matrix-homeserver -p LoadState --value');
    final homeserver = unit.exitCode == 0 && '${unit.stdout}'.trim() == 'loaded';
    return switch ((hasMatrix, homeserver)) {
      (true, true) =>
        'It can carry its projects’ messages: the Matrix transport is installed, and a homeserver can '
            'run here; the first task of a project with messages starts it.',
      (true, false) =>
        'The Matrix transport is installed, but no homeserver is: a project’s messages need one '
            'named in its project.yml, or the package porelo-matrix-homeserver here.',
      (false, _) =>
        'It cannot carry messages: no transport is installed. Choose the Matrix transport (and a '
            'homeserver) when preparing it, or install them later.',
    };
  }

  String _readiness() => doctorFound == null
      ? 'Ready to watch.'
      : 'It answers and can be watched, but tasks cannot run there yet: see what porelo doctor found.';

  /// What [doctor] refused, or null when it passed: the lines it marks MISSING, UNKNOWN, FAILED or
  /// ERROR, each with the advice that follows it, or everything it said when none is marked.
  /// DEGRADED is left out: a fresh machine is always that for its configuration key, and passes.
  static List<String>? refusedBy(ProcessResult doctor) {
    if (doctor.exitCode == 0) return null;
    final lines = both(doctor).split('\n');
    final marked = RegExp(r'\s(MISSING|UNKNOWN|FAILED|ERROR)\b');
    final found = <String>[];
    for (var i = 0; i < lines.length; i++) {
      if (!marked.hasMatch(lines[i])) continue;
      found.add(lines[i].trimRight());
      while (i + 1 < lines.length && lines[i + 1].trimLeft().startsWith('->')) {
        found.add(lines[++i].trimRight());
      }
    }
    if (found.isNotEmpty) return found;
    final said = lines.where((line) => line.trim().isNotEmpty).toList();
    return said.isEmpty ? <String>['porelo doctor ended with ${doctor.exitCode} and said nothing.'] : said;
  }

  /// The command the person runs in the terminal: as the work user, so the vault is that user's.
  List<String> get vaultCommand => <String>['ssh', '-t', alias, inTheLoginShell('porelo vault init')];

  /// Asks the daemon whether the vault is there now. **Never read out of the terminal**: its exit
  /// says only that the command ran, and `Keyslots` says what is true.
  Future<void> checkVault() => _doing('Asking the machine whether its vault is there…', () async {
    final count = countKeyslots;
    final machine = ready;
    if (count == null || machine == null) return null;
    final slots = await count(machine);
    if (slots == null) throw const MachineSetupFailed('The machine could not be asked about its vault.');
    hasVault = slots > 0;
    return hasVault!
        ? 'The vault is there, and it opens with the passphrase typed.'
        : 'There is no vault yet. Open the terminal again, or make it later at the machine with '
              '`porelo vault init`.';
  });

  /// Asks whether the vault is there without holding the wizard up: a machine slow to answer keeps
  /// the step as it was until it does.
  Future<void> _askAboutTheVaultQuietly() async {
    final count = countKeyslots;
    final machine = ready;
    if (count == null || machine == null) return;
    try {
      final slots = await count(machine);
      if (slots != null) {
        hasVault = slots > 0;
        notifyListeners();
      }
    } on Object {
      // Unknown stays unknown: the terminal is still there to make it.
    }
  }

  Future<void> harden() => _doing('Turning off root and password login…', () async {
    final done = await _root(RootAction.harden, MachineSetup.harden);
    if (done.exitCode != 0) throw MachineSetupFailed('Root login is still on: ${both(done)}');
    hardened = true;
    return 'Logging in as root and with a password is off.';
  });

  /// A root script, its lines shown as they arrive.
  Future<ProcessResult> _root(RootAction action, String script) {
    output.clear();
    outputOf = action;
    return setup.asRootLive(loggedInTo!, kept!, script, (line) {
      output.add(line);
      notifyListeners();
    });
  }

  void _logged(String line) {
    log.add(line);
    notifyListeners();
  }

  /// Runs one action, saying what it is doing while it does, and what it did or why it could not.
  Future<void> _doing(String what, Future<String?> Function() action) async {
    doing = what;
    said = null;
    notifyListeners();
    String? result;
    var bad = false;
    try {
      result = await action();
    } on MachineSetupFailed catch (ex) {
      result = ex.message;
      bad = true;
    } on Exception catch (ex) {
      // Anything else still ends with words rather than a step busy for ever. What a file or
      // process error says names paths and programs, never a key's contents.
      result = 'That did not work: $ex';
      bad = true;
    }
    doing = null;
    said = result;
    saidIsBad = bad;
    notifyListeners();
    _keep();
  }

  /// What a program printed on both streams.
  static String both(ProcessResult result) =>
      <String>['${result.stdout}'.trim(), '${result.stderr}'.trim()].where((each) => each.isNotEmpty).join('\n');
}
