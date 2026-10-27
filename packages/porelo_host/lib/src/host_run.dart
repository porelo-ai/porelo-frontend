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

/// What one host of one project is made from.
class HostPlan {
  /// Constructor taking the project, the account and the files that go up.
  const HostPlan({
    required this.project,
    required this.account,
    required this.publicKey,
    this.collection,
    this.collectionSha256,
    this.loginUser = 'ubuntu',
    this.distribution = 'snapshots',
    this.vpnPeerPublicKey,
    this.vpnPeerAddress,
    this.machineFile,
    this.bundle,
  });

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

  /// The person's WireGuard peer: a public key, never a secret.
  final String? vpnPeerPublicKey;

  /// The person's WireGuard peer's address.
  final String? vpnPeerAddress;

  /// This desktop's `machine.yml`, uploaded into the setup's place on the host; null where the drive still carries it.
  final String? machineFile;

  /// The project's bundle, uploaded beside it as `<project>.bundle`.
  final String? bundle;

  /// The tag the host carries.
  String get tag => 'porelo-project=$project';
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

/// Ansible's locale on the host, whatever this computer's ssh sends along: it refuses one that is
/// not UTF-8, and a person's own (`de_CH.UTF-8`, say) need not exist on a fresh host.
const _locale = 'export LC_ALL=C.UTF-8 LANG=C.UTF-8 && ';

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
  });

  /// Who rents the host.
  final HostProvider provider;

  /// How commands reach it.
  final Remote remote;

  /// Where each step's line goes.
  final void Function(Step step) emit;

  /// This command's steps, before the collection can announce its own.
  static const upSteps = [
    PlannedStep('rent', 'Rent the project server', seconds: 300),
    PlannedStep('ssh', 'Wait for the server to accept SSH', seconds: 780),
    PlannedStep('copy', 'Copy the server setup files', seconds: 30),
    PlannedStep('ansible', 'Install the server setup tools', seconds: 120),
  ];

  /// Giving the server back follows the collection's teardown.
  static const downSteps = [PlannedStep('give-back', 'Give the project server back', seconds: 30)];
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
  Future<int> up(HostPlan plan) => _withProjectLock(plan, () => _up(plan));

  Future<int> _withProjectLock(HostPlan plan, Future<int> Function() run) async {
    final File file;
    try {
      file = File(poreloHostProjectLock(plan.project, environment: environment));
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
    if ((plan.collection == null) != (plan.collectionSha256 == null)) {
      _write(const Step('collection', StepState.refused, fix: '--collection needs --collection-sha256 and vice versa'));
      return Exit.refused;
    }
    final expected = (plan.collectionSha256 ?? collectionRelease.sha256).toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(expected)) {
      _write(
        const Step('collection', StepState.refused, fix: '--collection-sha256 must contain 64 hexadecimal digits'),
      );
      return Exit.refused;
    }
    final collection =
        plan.collection ??
        path.join(File(resolvedExecutable ?? Platform.resolvedExecutable).parent.path, collectionRelease.fileName);
    try {
      final actual = (await sha256.bind(File(collection).openRead()).single).toString();
      if (actual != expected) {
        _write(
          Step(
            'collection',
            StepState.refused,
            fix: 'Collection $collection: expected SHA-256 $expected; got $actual.',
          ),
        );
        return Exit.refused;
      }
    } on FileSystemException catch (error) {
      _write(
        Step(
          'collection',
          StepState.refused,
          fix: 'Cannot read collection $collection: ${error.osError?.message ?? error.message}.',
        ),
      );
      return Exit.refused;
    }
    // The setup's files are read before anything is rented: a missing one costs no server.
    final Map<String, ({String path, String digest})>? setupFiles;
    try {
      setupFiles = _setupFiles(plan);
    } on FormatException catch (error) {
      _write(Step('copy', StepState.refused, fix: error.message));
      return Exit.refused;
    }
    _ownSteps = upSteps;
    _write(Step('plan', StepState.plan, steps: _ownSteps));
    final RentedHost? host;
    try {
      host = await _rented(plan);
    } on ProviderFailed catch (e) {
      // The provider's own sentence, as a refused step and 65: the person fixes it, not the code.
      _write(Step('rent', StepState.refused, fix: e.message));
      return Exit.refused;
    }
    if (host == null) return Exit.unreachable;
    final address = host.address!;

    _write(const Step('copy', StepState.started));
    final inventory = _inventory(plan);
    final copied = await remote.run(
      address,
      plan.loginUser,
      'mkdir -p $_workdir && cat > $_workdir/inventory.yml',
      input: inventory,
    );
    if (copied.exitCode != 0) return _refused('copy', copied, 'the host refused the inventory');
    final tarball = await remote.copy(address, plan.loginUser, collection, '$_workdir/collection.tar.gz');
    if (tarball.exitCode != 0) return _refused('copy', tarball, 'the collection could not be copied');
    final digestWords = <String>[];
    final checked = await remote.run(
      address,
      plan.loginUser,
      'sha256sum -c - || { sha256sum $_workdir/collection.tar.gz; exit 65; }',
      input: '$expected  $_workdir/collection.tar.gz\n',
      onLine: digestWords.add,
    );
    if (checked.exitCode != 0) {
      return _refused(
        'copy',
        RemoteResult(
          checked.exitCode,
          ['Expected SHA-256: $expected.', ...digestWords, checked.stderr].where((line) => line.isNotEmpty).join('\n'),
        ),
        'the host refused the collection digest',
      );
    }
    if (setupFiles != null) {
      final uploaded = await _uploadSetupFiles(address, plan, setupFiles);
      if (uploaded != null) return uploaded;
    }
    _write(const Step('copy', StepState.done));

    _write(const Step('ansible', StepState.started));
    final installed = await remote.run(
      address,
      plan.loginUser,
      // cloud-init first, which may still hold apt's lock on a fresh host; its "degraded" (2) is no
      // reason to stop here. A fresh image has no package lists yet.
      '${_locale}if command -v cloud-init >/dev/null; then cloud-init status --wait >/dev/null; [ \$? -le 2 ] || exit 1; fi && '
      'sudo DEBIAN_FRONTEND=noninteractive apt-get update -q >/dev/null && '
      'sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q ansible-core >/dev/null && '
      // As root, as the plays run: they leave root's files in the collection, which a second `up`
      // replaces.
      'sudo env LC_ALL=C.UTF-8 LANG=C.UTF-8 ansible-galaxy collection install --force '
      '-p $_workdir/collections $_workdir/collection.tar.gz >/dev/null',
    );
    if (installed.exitCode != 0) {
      return _refused('ansible', installed, 'ansible-core or the collection did not install');
    }
    _write(const Step('ansible', StepState.done));

    final played = await _play(address, plan, 'porelo.host.up');
    if (played != Exit.done) return played;
    final lines = <String>[];
    final uid = await remote.run(address, plan.account, 'id -u', onLine: lines.add);
    if (uid.exitCode != 0) return _refused('up', uid, 'the account uid could not be read');
    if (lines.length != 1 || !RegExp(r'^[0-9]+$').hasMatch(lines.single)) {
      return _refused('up', uid, 'id -u must return one uid containing only digits');
    }
    _write(
      Step(
        'up',
        StepState.done,
        address: address,
        account: plan.account,
        socket: '/run/user/${lines.single}/porelo/porelod.sock',
      ),
    );
    return Exit.done;
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
  });

  Future<int> _down(HostPlan plan, bool giveBackAnyway) async {
    _ownSteps = downSteps;
    _write(Step('plan', StepState.plan, steps: _ownSteps));
    final host = await provider.find(plan.tag);
    if (host == null) {
      _write(const Step('give-back', StepState.done, words: 'no host carries the project tag'));
      return Exit.done;
    }
    final address = host.address;
    final played = address == null
        ? _unreachable('play', 'the provider names no address for ${host.id}')
        : await _play(address, plan, 'porelo.host.down');
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
    var host = await provider.find(plan.tag) ?? await _create(plan);
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
        name: plan.project,
        tags: <String>[plan.tag, '$hostKeyTag${public.split(' ')[1]}'],
        sshPublicKey: plan.publicKey,
        userData: data.toString(),
      ),
    );
  }

  /// Runs [playbook] on the host and relays the callback's lines; the stop is said by its line.
  Future<int> _play(String address, HostPlan plan, String playbook) async {
    Step? waiting;
    Step? failed;
    final ran = await remote.run(
      address,
      plan.loginUser,
      // Through `env`, not `sudo -E`: Ubuntu 26.04's sudo (sudo-rs) ignores -E and says so.
      'sudo env LC_ALL=C.UTF-8 LANG=C.UTF-8 ANSIBLE_COLLECTIONS_PATH=$_workdir/collections '
      'ANSIBLE_STDOUT_CALLBACK=porelo.host.lines ansible-playbook -c local -i $_workdir/inventory.yml $playbook',
      onLine: (line) {
        final step = _relayed(line, address, plan.account, plan.loginUser);
        if (step == null) return;
        if (step.state == StepState.waiting) waiting = step;
        if (step.state == StepState.refused) failed = step;
        _write(step);
      },
    );
    // **The stop is the line, never the exit code**: `ansible-playbook` ends with 2 there, as on
    // any failed task, and a failure would otherwise read as somebody being asked for something.
    if (waiting != null) return Exit.waiting;
    if (ran.exitCode == 0) return Exit.done;
    if (failed == null) return _refused('play', ran, 'the play ended with ${ran.exitCode}');
    return Exit.refused;
  }

  /// One line of the collection's callback as a step, or null for one that is not its.
  Step? _relayed(String line, String address, String account, String admin) {
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?> || decoded['v'] != 1 || !validStepFields(decoded)) return null;
    final state = decoded['state'];
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

  /// Where the host's setup reads `machine.yml` and the bundle: root's alone until its account exists.
  static const setupPlace = '/etc/porelo-host/setup';

  /// The setup's files by the name they take on the host, each with its local path and SHA-256, read before anything
  /// is rented; null when [plan] names none. Refuses a plan naming only one, or a file that is no plain file.
  static Map<String, ({String path, String digest})>? _setupFiles(HostPlan plan) {
    if ((plan.machineFile == null) != (plan.bundle == null)) {
      throw const FormatException('--machine-file needs --bundle and vice versa');
    }
    if (plan.machineFile == null) return null;
    final files = <String, ({String path, String digest})>{};
    for (final (name, local) in [('machine.yml', plan.machineFile!), ('${plan.project}.bundle', plan.bundle!)]) {
      if (FileSystemEntity.typeSync(local, followLinks: false) != FileSystemEntityType.file) {
        throw FormatException('$local is not a plain file to upload');
      }
      try {
        files[name] = (path: local, digest: sha256.convert(File(local).readAsBytesSync()).toString());
      } on FileSystemException catch (error) {
        throw FormatException('Cannot read $local: ${error.osError?.message ?? error.message}');
      }
    }
    return files;
  }

  /// Uploads the setup's [files] into [setupPlace] as root's, `0600`, and checks each by its SHA-256 there; the exit
  /// to return when that is refused, or null when both are in place.
  ///
  /// They are staged in a folder only the login user reads and checked there before anything is placed; a check that
  /// fails once they are placed removes them, so the host never finds a file it was not sent.
  Future<int?> _uploadSetupFiles(
    String address,
    HostPlan plan,
    Map<String, ({String path, String digest})> files,
  ) async {
    const staging = '$_workdir/setup';
    String digestsIn(String folder) =>
        [for (final entry in files.entries) '${entry.value.digest}  $folder/${entry.key}\n'].join();
    Future<int> refusedWithoutStaging(RemoteResult result, String fix) async {
      await remote.run(address, plan.loginUser, '/usr/bin/rm -rf $staging');
      return _refused('copy', result, fix);
    }

    final made = await remote.run(
      address,
      plan.loginUser,
      '/usr/bin/rm -rf $staging && /usr/bin/install -d -m 0700 $staging',
    );
    if (made.exitCode != 0) return _refused('copy', made, 'the host refused a folder for the setup files');
    for (final entry in files.entries) {
      final copied = await remote.copy(address, plan.loginUser, entry.value.path, '$staging/${entry.key}');
      if (copied.exitCode != 0) return refusedWithoutStaging(copied, 'the setup files could not be copied');
    }
    final words = <String>[];
    final arrived = await remote.run(
      address,
      plan.loginUser,
      '/usr/bin/sha256sum -c -',
      input: digestsIn(staging),
      onLine: words.add,
    );
    if (arrived.exitCode != 0) {
      return refusedWithoutStaging(
        RemoteResult(arrived.exitCode, [...words, arrived.stderr].where((line) => line.isNotEmpty).join('\n')),
        'the setup files did not arrive as they were sent',
      );
    }
    final placed = await remote.run(
      address,
      plan.loginUser,
      [
        '/usr/bin/sudo /usr/bin/install -d -m 0700 -o root -g root $setupPlace',
        for (final name in files.keys)
          '/usr/bin/sudo /usr/bin/install -m 0600 -o root -g root '
              '${quoteForAShell('$staging/$name')} ${quoteForAShell('$setupPlace/$name')}',
      ].join(' && '),
    );
    if (placed.exitCode != 0) {
      // A first file placed before the second failed is no file the host was sent whole.
      await remote.run(address, plan.loginUser, '/usr/bin/sudo /usr/bin/rm -rf $setupPlace');
      return refusedWithoutStaging(placed, 'the host refused the setup files');
    }
    await remote.run(address, plan.loginUser, '/usr/bin/rm -rf $staging');
    words.clear();
    final checked = await remote.run(
      address,
      plan.loginUser,
      '/usr/bin/sudo /usr/bin/sha256sum -c -',
      input: digestsIn(setupPlace),
      onLine: words.add,
    );
    if (checked.exitCode != 0) {
      await remote.run(address, plan.loginUser, '/usr/bin/sudo /usr/bin/rm -rf $setupPlace');
      return _refused(
        'copy',
        RemoteResult(checked.exitCode, [...words, checked.stderr].where((line) => line.isNotEmpty).join('\n')),
        'the setup files did not stay as they were sent; they were removed',
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
      'vars': <String, Object>{
        'porelo_host_inventory_version': 1,
        'porelo_host_account': plan.account,
        'porelo_host_authorized_key': plan.publicKey,
        'porelo_host_project': plan.project,
        'porelo_host_distribution': plan.distribution,
        'porelo_host_vpn_peer_public_key': ?plan.vpnPeerPublicKey,
        'porelo_host_vpn_peer_address': ?plan.vpnPeerAddress,
      },
    },
  });
}
