import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import 'collection.dart';
import 'provider.dart';
import 'remote.dart';
import 'ssh.dart' show quoteForAShell;
import 'steps.dart';
import 'state.dart';
import 'host_record.dart';
import 'host_files.dart';
import 'host_act.dart';
import 'server_contract.dart';

/// What one host of one project is made from.
class HostPlan {
  /// Constructor taking the project, the account and the files that go up.
  const HostPlan({
    this.project = '',
    this.account = '',
    this.hostName,
    this.adminLogin,
    this.preparationSettings = const HostPreparationSettings(),
    this.recoveryOnly = false,
    this.existingRentalTag,
    this.adminSigners = const [],
    required this.publicKey,
    this.collection,
    this.collectionSha256,
    this.loginUser = 'ubuntu',
    this.distribution = 'snapshots',
    this.machineFile,
    this.bundle,
    this.forge = true,
  });

  /// The name for a server prepared independently of a project.
  final String? hostName;

  /// Core's proven login whose card key is pinned after preparation.
  final String? adminLogin;

  /// The runner limits and local forwarding choices supplied to preparation.
  final HostPreparationSettings preparationSettings;

  /// The existing provider tag; a missing match must never create a second rental.
  final String? existingRentalTag;

  /// Whether only a legacy rental's explicit give-back may run.
  final bool recoveryOnly;

  /// Core's verified host-admin public signers.
  final List<String> adminSigners;

  /// The rental and lock identity, shared by up and down.
  String get name => hostName ?? project;

  /// The separate lock namespace for servers prepared without a project.
  static String serverLockName(String name) => 'host-$name';

  /// Checks server-only inputs before anything is rented or released.
  void check({bool forSetup = true}) {
    lockNameForTag(tag);
    if (hostName == null) return;
    checkHostName(hostName!);
    if (recoveryOnly) return;
    if (project.isNotEmpty || account.isNotEmpty || machineFile != null || bundle != null) {
      throw const FormatException(
        'A server prepared without a project takes no account, project, machine file or bundle.',
      );
    }
    if (loginUser != 'root') throw const FormatException('A prepared server uses root with the rental key.');
    if (forSetup) {
      preparationSettings.check();
      if (adminLogin == null) throw const FormatException('The verified host admin login is required.');
      checkAdminName(adminLogin!);
      try {
        HostFiles.signingFingerprint(publicKey);
      } on HostFilesRefused {
        throw const FormatException('The person identity must be a valid public key.');
      }
    }
    if (!const ['snapshots', 'releases'].contains(distribution)) {
      throw const FormatException('Unknown host distribution.');
    }
  }

  /// The project's name: the host's name, and the tag it is found by.
  final String project;

  /// The account the first play makes, which runs Porelo.
  final String account;

  /// The person's public key, which logs in as [loginUser] and then as [account].
  final String publicKey;

  /// A test collection's tarball; absent to use the carried collection.
  final String? collection;

  /// The expected digest, required with a test collection.
  final String? collectionSha256;

  /// The image's own user with sudo, which the first steps run as.
  final String loginUser;

  /// Where Porelo's package comes from: `releases` or `snapshots`. `snapshots` until a release of
  /// Porelo carries `vault status`, which the host's plays ask; 0.5.0 has none.
  final String distribution;

  /// This desktop's `machine.yml`, uploaded into the setup's place on the host; null where the drive still carries it.
  final String? machineFile;

  /// The project's bundle, uploaded beside it as `<project>.bundle`.
  final String? bundle;

  /// Whether the host runs a forge of its own: on unless the person turned it off, since a host whose people use
  /// a central forge needs none.
  final bool forge;

  /// The tag the host carries.
  String get tag => existingRentalTag ?? (hostName == null ? tagFor(project) : serverTagFor(hostName!));

  /// The tag the host of [project] carries.
  static String tagFor(String project) => 'porelo-project=$project';

  /// The provider tag of a server prepared independently of a project.
  static String serverTagFor(String host) => 'porelo-host=$host';

  /// Derives the lock from the original rental tag, including after setup again.
  static String lockNameForTag(String tag) {
    final match = RegExp(r'^porelo-(host|project)=([A-Za-z0-9][A-Za-z0-9._-]*)$').firstMatch(tag);
    if (match == null) throw const FormatException('The rental tag is invalid.');
    return match[1] == 'host' ? serverLockName(match[2]!) : match[2]!;
  }
}

/// The tag a rented host's public ssh host key is kept in, after the key's type `ssh-ed25519`.
const hostKeyTag = 'porelo-host-key=';

/// A new ed25519 key pair from the system's own `ssh-keygen`, in a directory removed straight after.
Future<(String, String)> sshKeygenEd25519() async {
  final directory = await Directory.systemTemp.createTemp('porelo-host-key-');
  try {
    final file = '${directory.path}${Platform.pathSeparator}host';
    final made = await Process.run('ssh-keygen', <String>[
      '-q',
      '-t',
      'ed25519',
      '-N',
      '',
      '-C',
      'porelo-host',
      '-f',
      file,
    ]);
    if (made.exitCode != 0) throw StateError('ssh-keygen could not make a host key: ${made.stderr}');
    final public = (await File('$file.pub').readAsString()).trim().split(' ').take(2).join(' ');
    return (await File(file).readAsString(), public);
  } finally {
    await directory.delete(recursive: true);
  }
}

/// Where everything goes on the host.
const _workdir = '/var/tmp/porelo-host';

const _collections = '/usr/share/ansible/collections';

/// `up` and `down`, in their order.
///
/// **This does no step of the playbook.** It rents, copies, starts `ansible-playbook` on the host
/// and relays what the collection's callback says; the plays do the work.
class HostRun {
  /// Constructor taking the provider, the way to the host, and where the lines go.
  HostRun({
    required this.provider,
    required this.remote,
    required this.emit,
    this.trust,
    this.hostKeys = sshKeygenEd25519,
    this.pollEvery = const Duration(seconds: 15),
    this.readyWithin = const Duration(minutes: 40),
    this.sshWithin = const Duration(minutes: 20),
    this.sshEvery = const Duration(seconds: 10),
    this.collectionRelease = hostCollection,
    this.resolvedExecutable,
    this.environment,
    this.preparation,
  });

  /// The typed replacement setup protocol; absent until its dependency is available.
  final ServerPreparation? preparation;

  /// Who rents the host.
  final HostProvider provider;

  /// How commands reach it.
  final Remote remote;

  /// Where each step's line goes.
  final void Function(Step step) emit;

  /// This command's steps, before the collection can announce its own.
  static const upSteps = [
    PlannedStep('rent', 'Rent the server', seconds: 900),
    PlannedStep('ssh', 'Wait for the server to accept SSH', seconds: 780),
    PlannedStep('copy', 'Copy the server setup files', seconds: 30),
    PlannedStep('ansible', 'Install the server setup tools', seconds: 120),
  ];

  /// Giving the server back follows the collection's teardown.
  static const downSteps = [PlannedStep('give-back', 'Give the server back', seconds: 30)];
  List<PlannedStep> _ownSteps = const [];

  /// Writes this command's own words on its own steps; collection words remain verbatim.
  void _write(Step step) {
    final own = _ownSteps.where((each) => each.task == step.step).firstOrNull;
    if (own == null || step.state == StepState.plan) {
      emit(step);
      return;
    }
    emit(
      Step(
        step.step,
        step.state,
        text: own.text,
        seconds: own.seconds,
        fix: step.fix,
        words: step.words,
        needs: step.needs,
        address: step.address,
        account: step.account,
        admin: step.admin,
        socket: step.socket,
      ),
    );
  }

  /// Makes a host key the one a host is trusted by, before the first login.
  final Future<void> Function(String address, String hostKey)? trust;

  /// Makes a new ssh host key pair: the private key in OpenSSH's form, and the public line.
  final Future<(String, String)> Function() hostKeys;

  /// How often the provider is asked while a host is being made.
  final Duration pollEvery;

  /// How long a host may take to be ready.
  final Duration readyWithin;

  /// How long ssh is asked again on a host the provider calls ready, before it counts as
  /// unreachable. Scaleway's Elastic Metal installs its system after it reports ready, and answered
  /// ssh about 13 minutes later (measured 2026-10-19).
  final Duration sshWithin;

  /// How long between two tries.
  final Duration sshEvery;

  /// The carried release's identity, replaceable with a fixture in tests.
  final ({String version, String fileName, String sha256}) collectionRelease;

  /// The command's executable path; defaults to Platform.resolvedExecutable.
  final String? resolvedExecutable;

  /// State directory settings for this run; defaults to the process environment.
  final Map<String, String>? environment;

  /// Brings [plan]'s host up; run again after the person has completed the stop on the host.
  Future<int> up(HostPlan plan) =>
      _withProjectLock(plan, () => _up(plan), forSetup: preparation != null || provider is! GivenMachine);

  Future<int> _withProjectLock(HostPlan plan, Future<int> Function() run, {bool forSetup = true}) async {
    final File file;
    try {
      plan.check(forSetup: forSetup);
      file = File(poreloHostProjectLock(HostPlan.lockNameForTag(plan.tag), environment: environment));
    } on FormatException catch (error) {
      _write(Step('lock', StepState.refused, fix: error.message));
      return Exit.refused;
    }
    await file.parent.create(recursive: true);
    if (!Platform.isWindows) {
      final permissions = await Process.run('chmod', ['700', '--', file.parent.path]);
      if (permissions.exitCode != 0 || ((await file.parent.stat()).mode & 0x1ff) != 0x1c0) {
        throw FileSystemException('Cannot keep the host state directory private (0700)', file.parent.path);
      }
    }
    final handle = await file.open(mode: FileMode.append);
    try {
      try {
        await handle.lock(FileLock.exclusive);
      } on FileSystemException {
        _write(
          Step(
            'lock',
            StepState.refused,
            words: 'setup of ${plan.project} is still running from before',
            fix: 'wait for it, or end it',
          ),
        );
        return Exit.waiting;
      }
      return await run();
    } finally {
      // Keep the inode in place so every contender locks the same file, including after a crash.
      await handle.close();
    }
  }

  Future<int> _up(HostPlan plan) async {
    final setup = preparation;
    if (setup == null && provider is GivenMachine && !plan.recoveryOnly && plan.hostName != null) {
      return _upGiven(plan);
    }
    if (plan.recoveryOnly || setup == null || plan.hostName == null || plan.adminSigners.isEmpty) {
      _write(
        const Step(
          'up',
          StepState.refused,
          fix: 'Verified SSH-only server preparation is not available. The existing rental was kept.',
        ),
      );
      return Exit.refused;
    }
    try {
      for (final signer in plan.adminSigners) {
        checkedEd25519(signer);
      }
      if (!plan.adminSigners.contains(plan.publicKey)) {
        throw const FormatException('The current person is not a verified host-admin signer.');
      }
      final host = await _rented(plan);
      if (host == null) return Exit.unreachable;
      final result = await setup.prepare(
        remote: remote,
        name: plan.hostName!,
        address: host.address!,
        adminSigners: List.unmodifiable(plan.adminSigners),
        adminLogin: plan.adminLogin!,
        adminKey: plan.publicKey,
        inventory: Map.unmodifiable(_inventoryVariables(plan)),
        settings: plan.preparationSettings,
      );
      if (result.name != plan.hostName || result.address != host.address || result.sshHostKey != host.hostKey) {
        throw const FormatException('The setup completion differs from the pinned rental.');
      }
      _write(Step('up', StepState.done, address: result.address, admin: 'root'));
      _write(Step('host', StepState.host, host: result));
      return Exit.done;
    } on Exception {
      _write(
        const Step('up', StepState.refused, fix: 'Server preparation could not be confirmed; the rental was kept.'),
      );
      return Exit.refused;
    }
  }

  Future<int> _upGiven(HostPlan plan) async {
    Directory? checkedCollection;
    _ownSteps = upSteps;
    _write(Step('plan', StepState.plan, steps: _ownSteps));
    try {
      plan.preparationSettings.check();
      final given = provider as GivenMachine;
      // Validate the endpoint before it reaches SSH, not only after setup has changed it.
      PreparedHost.read({
        'name': plan.hostName,
        'address': given.address,
        'ssh_port': 22,
        'ssh_host_key': given.hostKey,
        'services': plan.preparationSettings.localServices,
      });
      final source =
          plan.collection ??
          path.join(File(resolvedExecutable ?? Platform.resolvedExecutable).parent.path, collectionRelease.fileName);
      final expected = plan.collectionSha256 ?? (plan.collection == null ? collectionRelease.sha256 : '');
      if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(expected)) {
        throw const FormatException('The collection needs its expected SHA-256.');
      }
      if (FileSystemEntity.typeSync(source, followLinks: false) != FileSystemEntityType.file) {
        throw const FormatException('The collection must be a regular file.');
      }
      final bytes = await File(source).readAsBytes();
      if (sha256.convert(bytes).toString() != expected.toLowerCase()) {
        throw const FormatException('The collection is not a regular file with the expected SHA-256.');
      }
      checkedCollection = await Directory.systemTemp.createTemp('porelo-collection-');
      final checkedSource = File(path.join(checkedCollection.path, 'collection.tar.gz'));
      await checkedSource.writeAsBytes(bytes);
      final host = await _rented(plan);
      if (host == null) return Exit.unreachable;
      final address = host.address!;
      _write(const Step('copy', StepState.started));
      var result = await remote.run(
        address,
        'root',
        'work=$_workdir\n'
            r'''set -e
refuse_path() {
  printf 'Expected %s at %s; got: ' "$2" "$1" >&2
  stat -c '%F owner=%u mode=%a links=%h' -- "$1" >&2
  exit 1
}
if test ! -e "$work" && test ! -L "$work"; then
  mkdir -m 0700 "$work"
fi
test -d "$work" && test ! -L "$work" &&
  test "$(stat -c '%u:%a' "$work")" = '0:700' ||
  refuse_path "$work" 'a plain root-owned directory with mode 0700'
for file in "$work/collection.tar.gz" "$work/inventory.yml"; do
  test ! -L "$file" || refuse_path "$file" 'a plain root-owned single-link file'
  if test -e "$file"; then
    test -f "$file" && test "$(stat -c '%u:%h' "$file")" = '0:1' ||
      refuse_path "$file" 'a plain root-owned single-link file'
  fi
done''',
      );
      if (result.exitCode != 0) return _refused('copy', result, 'The host refused the preparation folder.');
      result = await remote.copy(address, 'root', checkedSource.path, '$_workdir/collection.tar.gz');
      if (result.exitCode != 0) return _refused('copy', result, 'The collection could not be copied.');
      result = await remote.run(address, 'root', 'cat > $_workdir/inventory.yml', input: _inventory(plan));
      if (result.exitCode != 0) return _refused('copy', result, 'The inventory could not be copied.');
      _write(const Step('copy', StepState.done));
      _write(const Step('ansible', StepState.started));
      result = await remote.run(
        address,
        'root',
        "set -e; if command -v cloud-init >/dev/null; then cloud-init status --wait >/dev/null || [ \$? -le 2 ]; fi\n"
            'DEBIAN_FRONTEND=noninteractive apt-get update -q >/dev/null\n'
            'DEBIAN_FRONTEND=noninteractive apt-get install -y -q ansible-core >/dev/null\n'
            'install -d -o root -g root -m 0755 /usr/share/ansible\n'
            'env LC_ALL=C.UTF-8 LANG=C.UTF-8 ansible-galaxy collection install --force -p $_collections $_workdir/collection.tar.gz >/dev/null',
      );
      if (result.exitCode != 0) return _refused('ansible', result, 'Ansible or the collection did not install.');
      _write(const Step('ansible', StepState.done));
      final played = await _play(address, plan, 'porelo.host.up');
      if (played.code != Exit.done) return played.code;
      final completed = played.host;
      if (completed == null || completed.sshHostKey != host.hostKey) {
        throw const FormatException('The host did not confirm completion with its pinned SSH key.');
      }
      _write(Step('up', StepState.done, address: address, admin: 'root'));
      _write(Step('host', StepState.host, host: completed));
      return Exit.done;
    } on FormatException catch (error) {
      _write(Step('up', StepState.refused, fix: error.message));
      return Exit.refused;
    } on Exception {
      _write(const Step('up', StepState.refused, fix: 'Preparation could not be confirmed; the host was kept.'));
      return Exit.refused;
    } finally {
      await checkedCollection?.delete(recursive: true);
    }
  }

  /// Takes [plan]'s host down: the down play, then the host given back. Nothing happens when none is rented.
  ///
  /// **A host whose down play did not finish is kept**: a
  /// copy that failed may have left the only copy of its data there. The play's own line says what
  /// failed, and the last step says the host is kept and names the ways out. [giveBackAnyway] gives
  /// it back all the same, for a person who has read that.
  Future<int> down(HostPlan plan, {bool giveBackAnyway = false}) => _withProjectLock(plan, () async {
    try {
      return await _down(plan, giveBackAnyway);
    } on ProviderFailed catch (e) {
      _write(Step('give-back', StepState.refused, fix: e.message));
      return Exit.refused;
    }
  }, forSetup: false);

  Future<int> _down(HostPlan plan, bool giveBackAnyway) async {
    _ownSteps = downSteps;
    _write(Step('plan', StepState.plan, steps: _ownSteps));
    final host = await provider.find(plan.tag);
    if (host == null) {
      _write(const Step('give-back', StepState.done, words: 'no host carries the project tag'));
      return Exit.done;
    }
    if (plan.recoveryOnly || giveBackAnyway) {
      if (!giveBackAnyway) {
        _write(
          const Step(
            'give-back',
            StepState.refused,
            fix: 'This legacy rental cannot run its old teardown. Confirm give-back without a backup.',
          ),
        );
        return Exit.refused;
      }
      await provider.release(host.id);
      _write(
        const Step(
          'give-back',
          StepState.done,
          words: 'Given back without a backup or teardown after explicit loss confirmation.',
        ),
      );
      return Exit.done;
    }
    final address = host.address;
    if (plan.hostName != null && address != null) {
      if (trust != null) {
        if (host.hostKey == null) {
          _write(const Step('copy', StepState.refused, fix: 'The provider named no SSH host key for teardown.'));
          return Exit.refused;
        }
        await trust!(address, host.hostKey!);
      }
      final copied = await remote.run(
        address,
        plan.loginUser,
        'mkdir -p $_workdir && cat > $_workdir/inventory.yml',
        input: _inventory(plan),
      );
      if (copied.exitCode != 0) return _refused('copy', copied, 'the host refused the teardown inventory');
    }
    final played = address == null
        ? _unreachable('play', 'the provider names no address for ${host.id}')
        : (await _play(address, plan, 'porelo.host.down')).code;
    if (played != Exit.done && !giveBackAnyway) {
      _write(
        Step(
          'give-back',
          StepState.refused,
          words: '${host.id} is kept and still billed, since its down play did not finish',
          fix: "run 'down' again, or 'down --give-back-anyway' to give it back knowingly",
        ),
      );
      return played;
    }
    _write(const Step('give-back', StepState.started));
    await provider.release(host.id);
    _write(
      played == Exit.done
          ? Step('give-back', StepState.done, address: address)
          : Step(
              'give-back',
              StepState.done,
              address: address,
              words: 'given back knowingly although its down play did not finish: what it held is gone',
            ),
    );
    return played;
  }

  Future<RentedHost?> _rented(HostPlan plan) async {
    _write(const Step('rent', StepState.started));
    final found = await provider.find(plan.tag);
    if (found == null && plan.existingRentalTag != null) {
      throw const FormatException('The existing rental was not found. No second server was rented.');
    }
    var host = found ?? await _create(plan);
    final until = DateTime.now().add(readyWithin);
    while (!host.ready || host.address == null || host.hostKey == null) {
      if (DateTime.now().isAfter(until)) {
        _unreachable('rent', '${host.id} was not ready within ${readyWithin.inMinutes} minutes');
        return null;
      }
      await Future<void>.delayed(pollEvery);
      host = await provider.state(host.id);
    }
    _write(const Step('rent', StepState.done));

    _write(const Step('ssh', StepState.started));
    await trust?.call(host.address!, host.hostKey!);
    // A host the provider calls ready may still be starting its sshd, or cloud-init may not have
    // put the login in yet: asked again for a while, and only ssh's own last words reported.
    var reached = await remote.run(host.address!, plan.loginUser, 'true');
    // A host key that is not the provider's is never asked again: that is the one answer waiting
    // cannot change, and the refusal comes at once.
    final sshUntil = DateTime.now().add(sshWithin);
    while (reached.exitCode != 0 && !_keyRefused(reached) && DateTime.now().isBefore(sshUntil)) {
      await Future<void>.delayed(sshEvery);
      reached = await remote.run(host.address!, plan.loginUser, 'true');
    }
    if (reached.exitCode != 0) {
      _unreachable('ssh', reached.stderr);
      return null;
    }
    _write(const Step('ssh', StepState.done));
    return host;
  }

  /// Rents a host whose ssh host key is made here: its private half goes to the host in cloud-init's
  /// data only, its public half into a tag, so any later `up` or `down` trusts exactly that key.
  Future<RentedHost> _create(HostPlan plan) async {
    final (private, public) = await hostKeys();
    final data = StringBuffer()
      ..writeln('#cloud-config')
      ..writeln('ssh_deletekeys: true')
      ..writeln('ssh_genkeytypes: [ed25519]')
      ..writeln('ssh_keys:')
      ..writeln('  ed25519_private: |');
    for (final line in const LineSplitter().convert(private.trim())) {
      data.writeln('    $line');
    }
    data.writeln('  ed25519_public: $public');
    return provider.create(
      HostRequest(
        name: plan.name,
        tags: <String>[plan.tag, '$hostKeyTag${public.split(' ')[1]}'],
        sshPublicKey: plan.publicKey,
        userData: data.toString(),
      ),
    );
  }

  /// Runs [playbook] on the host and relays the callback's lines; the stop is said by its line.
  Future<({int code, PreparedHost? host})> _play(String address, HostPlan plan, String playbook) async {
    Step? waiting;
    Step? failed;
    PreparedHost? host;
    StepState? lastState;
    String? hostProblem;
    void refuseHost(String words) {
      hostProblem = words;
      failed = Step('host', StepState.refused, fix: words);
      _write(failed!);
    }

    final ran = await remote.run(
      address,
      plan.loginUser,
      // Through `env`, not `sudo -E`: Ubuntu 26.04's sudo (sudo-rs) ignores -E and says so.
      '${plan.loginUser == 'root' ? '' : 'sudo '}env LC_ALL=C.UTF-8 LANG=C.UTF-8 ANSIBLE_COLLECTIONS_PATH=$_collections '
      'ANSIBLE_STDOUT_CALLBACK=porelo.host.lines ansible-playbook -c local -i $_workdir/inventory.yml $playbook',
      onLine: (line) {
        if (hostProblem != null || failed != null || waiting != null) return;
        Step? step;
        try {
          step = _relayed(line, address, plan.account, plan.loginUser, plan: plan);
        } on FormatException catch (error) {
          refuseHost(error.message);
          return;
        }
        if (step == null) return;
        if (step.state == StepState.host) {
          final values = step.host!;
          final problem = playbook != 'porelo.host.up'
              ? 'The host record is allowed only from up.'
              : host != null
              ? 'The host record was repeated.'
              : lastState != StepState.done || failed != null || waiting != null
              ? 'The host record must follow the last successful up task.'
              : values.values['address'] != address
              ? 'host.json: address differs from the rental.'
              : plan.hostName != null && values.name != plan.hostName
              ? 'The completion names another server.'
              : null;
          if (problem != null) {
            refuseHost(problem);
          } else {
            host = values;
          }
          return;
        }
        if (host != null) {
          refuseHost('The host record must be the last line of up.');
          return;
        }
        lastState = step.state;
        if (step.state == StepState.waiting) {
          step = Step(
            step.step,
            StepState.refused,
            text: step.text,
            words: step.words,
            fix: step.words ?? 'The host requested a retired setup stop.',
          );
        }
        if (step.state == StepState.waiting) waiting = step;
        if (step.state == StepState.refused) failed = step;
        _write(step);
      },
    );
    // **The stop is the line, never the exit code**: `ansible-playbook` ends with 2 there, as on
    // any failed task, and a failure would otherwise read as somebody being asked for something.
    if (hostProblem != null) return (code: Exit.refused, host: null);
    if (waiting != null) return (code: Exit.waiting, host: null);
    if (failed != null) return (code: Exit.refused, host: null);
    if (ran.exitCode == 0) return (code: Exit.done, host: host);
    if (failed == null) return (code: _refused('play', ran, 'the play ended with ${ran.exitCode}'), host: null);
    return (code: Exit.refused, host: null);
  }

  /// One line of the collection's callback as a step, or null for one that is not its.
  Step? _relayed(String line, String address, String account, String admin, {HostPlan? plan}) {
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?> || decoded['v'] != 1 || !validStepFields(decoded)) return null;
    final state = decoded['state'];
    if (state == 'host') {
      return Step.fromLine(line, hostName: plan?.hostName, localServices: plan?.preparationSettings.localServices);
    }
    if (state == 'plan') {
      final steps = PlannedStep.readMany(decoded['steps']);
      if (steps == null || steps.any((step) => _ownSteps.any((own) => own.task == step.task))) return null;
      // Teardown's release follows the collection; provisioning precedes it.
      return Step(
        'plan',
        StepState.plan,
        steps: _ownSteps == downSteps ? [...steps, ..._ownSteps] : [..._ownSteps, ...steps],
      );
    }
    final words = decoded['msg'] as String?;
    final text = decoded['text'] as String?;
    final seconds = decoded['seconds'] as int?;
    if (state == 'waiting') {
      final needs = (decoded['needs'] as List<Object?>? ?? const <Object?>[]).whereType<String>().toList();
      return Step(
        'person',
        StepState.waiting,
        needs: needs,
        words: words,
        text: text,
        seconds: seconds,
        address: address,
        account: account,
        admin: admin,
      );
    }
    final name = decoded['task'] as String? ?? decoded['play'] as String? ?? 'play';
    return switch (state) {
      'started' => Step(name, StepState.started, text: text, seconds: seconds, words: words),
      'ok' || 'changed' || 'skipped' => Step(name, StepState.done, text: text, seconds: seconds, words: words),
      // Where `up` refuses for a secret it then takes on its own call, the call needs the host and its login user.
      'failed' => Step(
        name,
        StepState.refused,
        fix: words,
        words: words,
        text: text,
        seconds: seconds,
        address: address,
        admin: admin,
      ),
      _ => null,
    };
  }

  /// Returns [project]'s setup directory for [act], relative to the login's home for the person's own act.
  static String setupPlace(HostAct act, {String? project}) => act.setupPlace(project: project);

  /// Uploads a bring or join's machine file and both bundles through the person's own login.
  ///
  /// Requires [accessBundle] for [HostAct.ownAccount] and refuses project files for [HostAct.root].
  /// [HostAct.legacyUp] accepts no access bundle and retains the combined `up` directory.
  /// The caller then runs `ansible-playbook -c local porelo.host.bring -e porelo_project=<project>`
  /// (or `porelo.host.join`) as the same login, without sudo.
  /// Returns `null` once all files are checked in place, or the refusal exit code; invalid inputs
  /// throw [HostFilesRefused] for invalid own-account project names, or [FormatException] for other invalid inputs,
  /// before any remote command runs.
  Future<int?> uploadSetupFiles({
    required HostAct act,
    required String address,
    required String user,
    required String project,
    required String machineFile,
    required String bundle,
    String? accessBundle,
  }) async {
    if (act == HostAct.root || (act == HostAct.legacyUp && accessBundle != null)) {
      throw const FormatException(
        'Only an own-account upload accepts project access data; root accepts no project files.',
      );
    }
    if (act == HostAct.ownAccount) {
      HostFiles.checkProjectName(project);
    } else if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(project)) {
      throw const FormatException('The setup files need a plain project name.');
    }
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_-]*$').hasMatch(user) ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9.:-]*$').hasMatch(address)) {
      throw const FormatException('The setup files need a valid host address and login.');
    }
    if (act == HostAct.ownAccount && (user == 'root' || accessBundle == null)) {
      throw const FormatException('An own-account upload needs the person\'s login and the access bundle.');
    }
    final files = _setupFiles(
      HostPlan(project: project, publicKey: '', machineFile: machineFile, bundle: bundle),
      accessBundle: accessBundle,
      act: act,
    )!;
    return _uploadSetupFiles(address, user, files, act: act, project: project);
  }

  /// Replaces only the access bundle in an existing own-account setup.
  ///
  /// Uses the setup upload's private staging and digest checks, then renames the
  /// checked file into place with mode `0600`. Returns a refusal code on failure.
  Future<int?> uploadAccessBundle({
    required String address,
    required String user,
    required String project,
    required String bundle,
  }) async {
    HostFiles.checkProjectName(project);
    if (user == 'root' ||
        !RegExp(r'^[A-Za-z_][A-Za-z0-9_-]*$').hasMatch(user) ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9.:-]*$').hasMatch(address)) {
      throw const FormatException('The access upload needs the person\'s host address and login.');
    }
    return _uploadOwnSetupFiles(
      address,
      user,
      {HostFiles.accessBundleFileName: _uploadFile(bundle)},
      project: project,
      replaceAccess: true,
    );
  }

  static ({String path, String digest}) _uploadFile(String local) {
    if (FileSystemEntity.typeSync(local, followLinks: false) != FileSystemEntityType.file) {
      throw FormatException('$local is not a plain file to upload');
    }
    try {
      return (path: local, digest: sha256.convert(File(local).readAsBytesSync()).toString());
    } on FileSystemException catch (error) {
      throw FormatException('Cannot read $local: ${error.osError?.message ?? error.message}');
    }
  }

  /// The setup's files by the name they take on the host, each with its local path and SHA-256, read before anything
  /// is rented; null when [plan] names none. Refuses a plan naming only one, or a file that is no plain file.
  static Map<String, ({String path, String digest})>? _setupFiles(
    HostPlan plan, {
    String? accessBundle,
    HostAct act = HostAct.legacyUp,
  }) {
    if ((plan.machineFile == null) != (plan.bundle == null)) {
      throw const FormatException('--machine-file needs --bundle and vice versa');
    }
    if (plan.machineFile == null) return null;
    final files = <String, ({String path, String digest})>{};
    for (final (name, local) in [
      ('machine.yml', plan.machineFile!),
      (act == HostAct.ownAccount ? HostFiles.projectBundleFileName : '${plan.project}.bundle', plan.bundle!),
      if (accessBundle != null) (HostFiles.accessBundleFileName, accessBundle),
    ]) {
      files[name] = _uploadFile(local);
    }
    return files;
  }

  /// Uploads the setup's [files] for [act], `0600`, and checks each by its SHA-256 there; the exit to return
  /// when that is refused, or null when all are in place.
  ///
  /// They are staged in a folder only the login user reads and checked there before anything is placed; a check that
  /// fails once they are placed removes them, so the host never finds a file it was not sent.
  Future<int?> _uploadSetupFiles(
    String address,
    String user,
    Map<String, ({String path, String digest})> files, {
    required HostAct act,
    required String project,
  }) async {
    if (act == HostAct.ownAccount) return _uploadOwnSetupFiles(address, user, files, project: project);
    final place = setupPlace(act);
    final staging = '$_workdir/setup';
    const sudo = '/usr/bin/sudo ';
    const owner = '-o root -g root ';
    String onHost(String file) => quoteForAShell(file);
    String digestsIn(String folder) =>
        [for (final entry in files.entries) '${entry.value.digest}  $folder/${entry.key}\n'].join();
    const checkFiles = '/usr/bin/sha256sum -c -';
    Future<int> refusedWithoutStaging(RemoteResult result, String fix) async {
      await remote.run(address, user, '/usr/bin/rm -rf ${onHost(staging)}');
      return _refused('copy', result, fix);
    }

    final made = await remote.run(address, user, '/usr/bin/rm -rf $staging && /usr/bin/install -d -m 0700 $staging');
    if (made.exitCode != 0) return _refused('copy', made, 'the host refused a folder for the setup files');
    for (final entry in files.entries) {
      final copied = await remote.copy(address, user, entry.value.path, '$staging/${entry.key}');
      if (copied.exitCode != 0) return refusedWithoutStaging(copied, 'the setup files could not be copied');
    }
    final words = <String>[];
    final arrived = await remote.run(address, user, checkFiles, input: digestsIn(staging), onLine: words.add);
    if (arrived.exitCode != 0) {
      return refusedWithoutStaging(
        RemoteResult(arrived.exitCode, [...words, arrived.stderr].where((line) => line.isNotEmpty).join('\n')),
        'the setup files did not arrive as they were sent',
      );
    }
    final placed = await remote.run(
      address,
      user,
      [
        '$sudo/usr/bin/install -d -m 0700 $owner${onHost(place)}',
        for (final name in files.keys)
          '$sudo/usr/bin/install -m 0600 $owner${onHost('$staging/$name')} ${onHost('$place/$name')}',
      ].join(' && '),
    );
    if (placed.exitCode != 0) {
      // A first file placed before the second failed is no file the host was sent whole.
      await remote.run(address, user, '$sudo/usr/bin/rm -rf ${onHost(place)}');
      return refusedWithoutStaging(placed, 'the host refused the setup files');
    }
    await remote.run(address, user, '/usr/bin/rm -rf ${onHost(staging)}');
    words.clear();
    final checked = await remote.run(address, user, '$sudo$checkFiles', input: digestsIn(place), onLine: words.add);
    if (checked.exitCode != 0) {
      await remote.run(address, user, '$sudo/usr/bin/rm -rf ${onHost(place)}');
      return _refused(
        'copy',
        RemoteResult(checked.exitCode, [...words, checked.stderr].where((line) => line.isNotEmpty).join('\n')),
        'the setup files did not stay as they were sent; they were removed',
      );
    }
    return null;
  }

  Future<int?> _uploadOwnSetupFiles(
    String address,
    String user,
    Map<String, ({String path, String digest})> files, {
    required String project,
    bool replaceAccess = false,
  }) async {
    // The remote login shell is Bash by porelo-host's account-creation contract.
    // Its startup files and environment belong to the account and are trusted as such.
    Future<RemoteResult> runScript(String script, {String? input, void Function(String)? onLine}) =>
        remote.run(address, user, script, input: input, onLine: onLine);
    final place = setupPlace(HostAct.ownAccount, project: project);
    final parts = path.posix.split(place);
    final parents = [for (var count = 1; count < parts.length; count++) path.posix.joinAll(parts.take(count))];
    const checkedHome = r'''setup_home=${HOME-}
case "$setup_home" in /*) ;; *) echo 'The host home must be an absolute directory.' >&2; exit 1;; esac
case "$setup_home/" in *'//'*|*'/../'*|*'/./'*|*$'\n'*|*$'\r'*) echo 'The host home is not a plain absolute path.' >&2; exit 1;; esac
test -d "$setup_home" && test ! -L "$setup_home" || { echo 'The host home is missing or a link.' >&2; exit 1; }
''';
    String underHome(String name) => '"\$setup_home"/${quoteForAShell(name)}';
    final lines = <String>[];
    final found = await runScript([checkedHome, r'''printf '%s\n' "$setup_home"'''].join('\n'), onLine: lines.add);
    if (found.exitCode != 0) return _refused('copy', found, 'the host refused its home directory');
    if (lines.length != 1 || !path.posix.isAbsolute(lines.single) || lines.single.contains('\x00')) {
      return _refused(
        'copy',
        const RemoteResult(1, 'The host did not report one absolute home.'),
        'the host home was not checked',
      );
    }
    final home = lines.single;
    final destination = path.posix.join(home, place);
    // A leading hyphen is refused by the shared name check, so staging cannot name a project.
    final staging = path.posix.join(path.posix.dirname(destination), '-upload-$project');
    String q(String name) => quoteForAShell(name);
    String plainDirectory(String name) => 'test -d ${q(name)} && test ! -L ${q(name)}';
    final safe = [
      for (final folder in [home, ...parents.map((parent) => path.posix.join(home, parent))]) plainDirectory(folder),
    ].join(' && ');
    final prefix = '$checkedHome\ntest "\$setup_home" = ${q(home)} || exit 1\nsafe() { $safe; }';
    final uploadedNames = replaceAccess
        ? ['machine.yml', HostFiles.projectBundleFileName, HostFiles.accessBundleFileName]
        : files.keys.toList();
    final foreignWords = q('The project setup folder already exists at $destination; it was preserved: ');
    final previousAccess = '$staging/.previous-access.bundle';
    final checkUpload = [
      'safe && ${plainDirectory(destination)} || foreign "not a plain directory"',
      'test -f ${q('$destination/.porelo-upload')} && test ! -L ${q('$destination/.porelo-upload')} || foreign "missing plain upload marker"',
      'shopt -s nullglob dotglob',
      'for entry in ${q(destination)}/*; do',
      '  test -f "\$entry" && test ! -L "\$entry" || foreign "a file is a link or not a plain file: \$entry"',
      '  case "\${entry##*/}" in ${[...uploadedNames, '.porelo-upload'].map(q).join('|')}) ;; *) foreign "unexpected file: \$entry";; esac',
      'done',
      'mapfile -t marker < ${q('$destination/.porelo-upload')}',
      'test "\${#marker[@]}" = ${uploadedNames.length + 1} || foreign "malformed upload marker"',
      r'''[[ "${marker[0]}" =~ ^uploaded=[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || foreign "malformed upload time"''',
      for (final (index, name) in uploadedNames.indexed)
        '[[ "\${marker[${index + 1}]}" =~ ^[0-9a-f]{64}\\ \\ ${RegExp.escape(name)}\$ ]] || foreign "malformed upload digest"',
      '(cd -- ${q(destination)} && printf \'%s\\n\' "\${marker[@]:1}" | /usr/bin/sha256sum --quiet -c -) || foreign "uploaded files changed"',
    ].join('\n');
    final removeStaging =
        'if safe && ${plainDirectory(staging)}; then\n'
        '  /usr/bin/rm -f -- ${[
          ...files.keys,
          if (replaceAccess) ...['.porelo-upload', '.previous-access.bundle'],
        ].map((name) => q('$staging/$name')).join(' ')} && '
        '/usr/bin/rmdir -- ${q(staging)}\n'
        'else echo ${q('Cannot safely clean staging at $staging.')} >&2; return 1; fi';
    Future<int> refused(RemoteResult result, String fix) async {
      final cleaned = await runScript(
        '$prefix\nif test ! -e ${q(staging)} && test ! -L ${q(staging)}; then exit 0; fi\n'
        'clean_staging() { $removeStaging; }\nclean_staging',
      );
      return _refused(
        'copy',
        RemoteResult(result.exitCode, [result.stderr, cleaned.stderr].where((line) => line.isNotEmpty).join('\n')),
        fix,
      );
    }

    lines.clear();
    final replacedWords = 'An earlier upload of $project was replaced.';
    final made = await runScript(
      [
        'set -e',
        prefix,
        if (replaceAccess)
          '${plainDirectory(destination)} || { echo "The project setup folder is missing or a link." >&2; exit 1; }',
        if (!replaceAccess)
          for (final parent in parents)
            'test ! -L ${underHome(parent)} && '
                '{ test -d ${underHome(parent)} || /usr/bin/mkdir -m 0700 ${underHome(parent)}; } || exit 1',
        'safe || exit 1',
        '/usr/bin/mkdir -m 0700 ${q(staging)}',
        'foreign() { echo $foreignWords"\$1" >&2; '
            'if safe && ${plainDirectory(staging)}; then /usr/bin/rmdir -- ${q(staging)}; fi; exit 1; }',
        'if test -e ${q(destination)} || test -L ${q(destination)}; then',
        checkUpload,
        if (!replaceAccess) ...[
          '  /usr/bin/rm -- ${[...files.keys, '.porelo-upload'].map((name) => q('$destination/$name')).join(' ')}',
          '  /usr/bin/rmdir -- ${q(destination)}',
          '  printf \'%s\\n\' ${q(replacedWords)}',
        ],
        'fi',
      ].join('\n'),
      onLine: lines.add,
    );
    if (made.exitCode != 0) return _refused('copy', made, 'the host refused a folder for the setup files');
    if (lines.isNotEmpty && (lines.length != 1 || lines.single != replacedWords)) {
      final cleaned = await runScript('$prefix\nsafe && ${plainDirectory(staging)} && /usr/bin/rmdir -- ${q(staging)}');
      return _refused(
        'copy',
        RemoteResult(
          1,
          ['The host printed unexpected startup output.', cleaned.stderr].where((line) => line.isNotEmpty).join('\n'),
        ),
        'the setup reservation was refused; any populated reservation was preserved',
      );
    }
    if (lines.isNotEmpty) _write(Step('copy', StepState.started, words: replacedWords));
    for (final file in files.entries) {
      final copied = await remote.copy(address, user, file.value.path, '$staging/${file.key}');
      if (copied.exitCode != 0) return refused(copied, 'the setup files could not be copied');
    }
    final digests = [for (final file in files.entries) '${file.value.digest}  ${file.key}\n'].join();
    lines.clear();
    final arrived = await runScript(
      '$prefix\nsafe && ${plainDirectory(staging)} && cd -- ${q(staging)} && /usr/bin/sha256sum --quiet -c -',
      input: digests,
      onLine: lines.add,
    );
    if (arrived.exitCode != 0) {
      return refused(
        RemoteResult(arrived.exitCode, [...lines, arrived.stderr].where((line) => line.isNotEmpty).join('\n')),
        'the setup files did not arrive as they were sent',
      );
    }
    if (lines.isNotEmpty) {
      return refused(
        const RemoteResult(1, 'The host printed unexpected startup output.'),
        'the setup check was refused',
      );
    }
    lines.clear();
    final placed = await runScript(
      [
        'set -e',
        prefix,
        'reserved=0',
        if (replaceAccess) 'restore_access=0',
        'installed=()',
        'clean_staging() { $removeStaging; }',
        'cleanup() {',
        '  result=\$?; trap - EXIT',
        if (replaceAccess) ...[
          '  if [ "\$result" -ne 0 ] && [ "\$restore_access" = 1 ]; then',
          '    if safe && ${plainDirectory(destination)} && ${plainDirectory(staging)} && '
              'test -f ${q(previousAccess)} && test ! -L ${q(previousAccess)} && '
              '/usr/bin/mv -fT -- ${q(previousAccess)} ${q('$destination/${HostFiles.accessBundleFileName}')}; then :',
          '    else echo ${q('Cannot safely restore the previous access bundle; it remains at $previousAccess.')} >&2; exit 1; fi',
          '  fi',
        ],
        '  if [ "\$result" -ne 0 ] && [ "\$reserved" = 1 ]; then',
        '    if safe && ${plainDirectory(destination)}; then',
        '      for name in "\${installed[@]}"; do /usr/bin/rm -f -- ${q(destination)}/"\$name" || result=1; done',
        '      /usr/bin/rmdir -- ${q(destination)} || result=1',
        '    else echo ${q('Cannot safely clean setup at $destination.')} >&2; result=1; fi',
        '  fi',
        '  clean_staging || result=1',
        '  exit "\$result"',
        '}',
        'trap cleanup EXIT',
        'safe && ${plainDirectory(staging)} || exit 1',
        if (!replaceAccess) ...['/usr/bin/mkdir -m 0700 ${q(destination)}', 'reserved=1'],
        'safe && ${plainDirectory(staging)} && ${plainDirectory(destination)} || exit 1',
        if (replaceAccess) ...[
          'foreign() { echo $foreignWords"\$1" >&2; exit 1; }',
          checkUpload,
          'marker[${uploadedNames.indexOf(HostFiles.accessBundleFileName) + 1}]=${q('${files[HostFiles.accessBundleFileName]!.digest}  ${HostFiles.accessBundleFileName}')}',
          '(umask 077; set -o noclobber; printf \'%s\\n\' "\${marker[@]}" > ${q('$staging/.porelo-upload')})',
          '/usr/bin/chmod 0600 -- ${q('$staging/.porelo-upload')}',
          'test ! -e ${q(previousAccess)} && test ! -L ${q(previousAccess)} || exit 1',
          '/usr/bin/install -m 0600 ${q('$destination/${HostFiles.accessBundleFileName}')} ${q(previousAccess)}',
        ],
        for (final name in files.keys) ...[
          'installed+=(${q(name)})',
          if (replaceAccess) ...[
            'test -f ${q('$staging/$name')} && test ! -L ${q('$staging/$name')} || exit 1',
            'test ! -e ${q('$destination/$name')} && test ! -L ${q('$destination/$name')} || '
                '{ test -f ${q('$destination/$name')} && test ! -L ${q('$destination/$name')}; } || exit 1',
            '/usr/bin/chmod 0600 -- ${q('$staging/$name')}',
            'restore_access=1',
            '/usr/bin/mv -fT -- ${q('$staging/$name')} ${q('$destination/$name')}',
          ] else
            '/usr/bin/install -m 0600 ${q('$staging/$name')} ${q('$destination/$name')}',
        ],
        'cd -- ${q(destination)} && /usr/bin/sha256sum --quiet -c -',
        if (replaceAccess) ...[
          '/usr/bin/mv -fT -- ${q('$staging/.porelo-upload')} ${q('$destination/.porelo-upload')}',
          'restore_access=0',
        ] else ...[
          'installed+=(${q('.porelo-upload')})',
          '{ printf \'uploaded=%s\\n\' "\$(/usr/bin/date -u +%Y-%m-%dT%H:%M:%SZ)"; printf \'%s\' ${q(digests)}; } > .porelo-upload',
          '/usr/bin/chmod 0600 .porelo-upload',
        ],
      ].join('\n'),
      input: digests,
      onLine: lines.add,
    );
    if (placed.exitCode != 0) {
      return _refused(
        'copy',
        RemoteResult(placed.exitCode, [...lines, placed.stderr].where((line) => line.isNotEmpty).join('\n')),
        'the setup files could not be checked and placed',
      );
    }
    if (lines.isNotEmpty) {
      if (replaceAccess) {
        return _refused(
          'copy',
          const RemoteResult(1, 'The host printed unexpected startup output.'),
          'the access bundle replacement was not confirmed',
        );
      }
      final cleaned = await runScript(
        '$prefix\nif test ! -e ${q(destination)} && test ! -L ${q(destination)}; then exit 0; fi\n'
        'if safe && ${plainDirectory(destination)}; then\n'
        '  /usr/bin/rmdir -- ${q(destination)}\n'
        'else echo ${q('Cannot safely clean setup at $destination.')} >&2; exit 1; fi',
      );
      return refused(
        RemoteResult(
          1,
          ['The host printed unexpected startup output.', cleaned.stderr].where((line) => line.isNotEmpty).join('\n'),
        ),
        'the setup placement was refused; any populated setup was preserved',
      );
    }
    return null;
  }

  static bool _keyRefused(RemoteResult result) => result.stderr.contains('Host key verification failed');

  int _refused(String step, RemoteResult result, String fix) {
    _write(Step(step, StepState.refused, fix: fix, words: result.stderr.isEmpty ? null : result.stderr));
    return Exit.refused;
  }

  int _unreachable(String step, String words) {
    _write(Step(step, StepState.refused, fix: 'the provider or the host could not be reached', words: words));
    return Exit.unreachable;
  }

  /// The first play's part of the inventory. JSON, which YAML reads as it is.
  String _inventory(HostPlan plan) => const JsonEncoder.withIndent('  ').convert(<String, Object>{
    'all': <String, Object>{
      'hosts': <String, Object>{'localhost': <String, Object>{}},
      'vars': _inventoryVariables(plan),
    },
  });

  Map<String, Object> _inventoryVariables(HostPlan plan) => {
    'porelo_host_inventory_version': plan.hostName == null ? 1 : 2,
    if (plan.hostName == null) ...{
      'porelo_host_account': plan.account,
      'porelo_host_authorized_key': plan.publicKey,
      'porelo_host_project': plan.project,
    } else ...{
      'porelo_host_name': plan.hostName!,
      'porelo_host_network': 0,
      ...plan.preparationSettings.roleSettings,
    },
    'porelo_host_distribution': plan.distribution,
    'porelo_host_forge': plan.forge,
  };
}
