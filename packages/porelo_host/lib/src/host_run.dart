import 'dart:async';

import 'host_command.dart';

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import 'collection.dart';
import 'host_check.dart';
import 'provider.dart';
import 'remote.dart';
import 'steps.dart';
import 'state.dart';
import 'host_record.dart';
import 'host_files.dart';
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

  /// Whether this host has a forge: only where this plan and its chosen settings both say so.
  bool get hasForge => forge && preparationSettings.forge;

  /// The name for a server prepared independently of a project.
  final String? hostName;

  /// Core's proven login whose card key is pinned after preparation.
  final String? adminLogin;

  /// The runner limits and local forwarding choices supplied to preparation.
  final HostPreparationSettings preparationSettings;

  /// The existing provider tag; a missing match must never create a second rental.
  final String? existingRentalTag;

  /// Core's verified host-admin public signers.
  final List<String> adminSigners;

  /// The rental and lock identity, shared by up and down.
  String get name => hostName ?? project;

  /// The separate lock namespace for servers prepared without a project.
  static String serverLockName(String name) => 'host-$name';

  /// Checks server-only inputs before anything is rented or released.
  void check({bool forSetup = true}) {
    lockNameForTag(tag);
    if (!const ['snapshots', 'releases'].contains(distribution)) {
      throw const FormatException('Unknown host distribution.');
    }
    if (hostName == null) return;
    checkHostName(hostName!);
    if (project.isNotEmpty || account.isNotEmpty || bundle != null) {
      throw const FormatException('A server prepared without a project takes no account, project or bundle.');
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

  /// Where Porelo's package comes from: `releases` or `snapshots`, and `snapshots` unless given. The command
  /// passes the channel it was built for, so a released `porelo-host` needs a released Porelo that carries what
  /// the host's plays ask.
  final String distribution;

  /// This desktop's `machine.yml`, uploaded into the setup's place on the host; a server's holds its organization part.
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

/// The host's own check of the copied collection, right before `ansible-galaxy` reads it: [expected] is 64 hex digits,
/// validated before it reaches this line.
String _collectionCheck(String expected) =>
    'found=\$(sha256sum < $_workdir/collection.tar.gz | cut -d " " -f 1)\n'
    'if [ "\$found" != $expected ]; then\n'
    '  printf "The collection on the host has SHA-256 %s, expected %s; it was not installed.\\n" "\$found" $expected >&2\n'
    '  exit ${Exit.refused}\n'
    'fi\n';

const _collections = '/usr/share/ansible/collections';

// The helper takes `org` only from root itself, never through sudo; a rental that logs in as anyone else has no people.
const _rootAlone = 'Only a server reached as root has people to read or purge.';

/// Rejects shell input and service accounts before a purge can reach the host.
void checkPurgeLogin(String login) {
  if (RegExp(r'^[a-z][a-z0-9-]{0,31}$').stringMatch(login) != login ||
      login == 'porelo' ||
      login.startsWith('porelo-')) {
    throw const FormatException('A purge needs a person login, excluding porelo and porelo- service accounts.');
  }
}

/// A person whose server account still holds organization memberships, or who is locked with a purge day.
class HostMembership {
  const HostMembership._(this.login, this.hostAdmin, this.projects, {this.state = 'active', this.purgeOn});

  /// The account that an explicit purge may remove.
  final String login;

  /// Whether this person administers the host.
  final bool hostAdmin;

  /// Each project and the role this person holds there.
  final List<({String project, String role})> projects;

  /// The host's word on the account: `active`, `locked` or `pending`.
  final String state;

  /// The day the host deletes the account by itself, as `YYYY-MM-DD`, where it is locked.
  final String? purgeOn;

  /// Why the host's `person purge` refuses this person on [today] (`YYYY-MM-DD`), or null where it purges them: it
  /// purges only a person locked, listed in no project, no Machine Admin, and past their purge day.
  String? whyNotPurged(String today) {
    if (hostAdmin) return 'a Machine Admin is never purged';
    if (projects.isNotEmpty) return 'a person still listed in a project is never purged';
    if (state != 'locked') return 'only a locked account is purged';
    final day = purgeOn;
    if (day == null) return 'the machine names no purge day';
    if (today.compareTo(day) < 0) return 'it is purged only from its purge day, and it is kept until $day';
    return null;
  }

  /// Validates every person before returning any holders; missing data is never an empty answer.
  static List<HostMembership> readStatus(String answer) {
    const malformed = FormatException('The host membership status is malformed or incomplete.');
    final Object? decoded;
    try {
      decoded = jsonDecode(answer);
    } on FormatException {
      throw malformed;
    }
    if (decoded is! Map<String, Object?> || decoded['persons'] is! List<Object?>) throw malformed;
    final holders = <HostMembership>[];
    final logins = <String>{};
    for (final person in decoded['persons'] as List<Object?>) {
      if (person is! Map<String, Object?>) throw malformed;
      final login = person['login'];
      final state = person['state'];
      final admin = person['host_admin'];
      final projects = person['projects'];
      if (login is! String ||
          state is! String ||
          admin is! bool ||
          projects is! List<Object?> ||
          !const ['active', 'locked', 'pending', 'purged', 'named'].contains(state) ||
          person.containsKey('purge_on') && (person['purge_on'] is! String || (person['purge_on'] as String).isEmpty)) {
        throw malformed;
      }
      checkPurgeLogin(login);
      if (!logins.add(login)) throw malformed;
      final roles = <({String project, String role})>[];
      for (final entry in projects) {
        if (entry case {'project': final String project, 'role': final String role}
            when project.trim().isNotEmpty && role.trim().isNotEmpty) {
          roles.add((project: project, role: role));
        } else {
          throw malformed;
        }
      }
      final purgeOn = person['purge_on'] as String?;
      if (admin || roles.isNotEmpty || (state == 'locked' && purgeOn != null)) {
        holders.add(HostMembership._(login, admin, List.unmodifiable(roles), state: state, purgeOn: purgeOn));
      }
    }
    return List.unmodifiable(holders);
  }
}

/// What a machine whose root is closed by its cloud image is told: the command is the dialog's to show.
/// How a refused host key begins, so a window can offer to enter another.
const hostKeyNotFiled = 'The machine holds another SSH host key than the one filed';

const rootStillClosed = 'root is still closed: run the command above.';

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

  /// The same steps on a machine the person gave: nothing is rented there.
  static const givenUpSteps = [
    PlannedStep('rent', 'Take the server as given', seconds: 5),
    PlannedStep('ssh', 'Reach the server over SSH', seconds: 780),
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
    if (setup == null && provider is GivenMachine && plan.hostName != null) {
      return _upGiven(plan);
    }
    if (setup == null || plan.hostName == null || plan.adminSigners.isEmpty) {
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
    _ownSteps = provider is GivenMachine ? givenUpSteps : upSteps;
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
      final found = sha256.convert(bytes).toString();
      if (found != expected.toLowerCase()) {
        throw FormatException(
          'The collection has SHA-256 $found, expected ${expected.toLowerCase()}; nothing was copied.',
        );
      }
      final machineFile = plan.machineFile == null ? null : _uploadFile(plan.machineFile!);
      checkedCollection = await Directory.systemTemp.createTemp('porelo-collection-');
      final checkedSource = File(path.join(checkedCollection.path, 'collection.tar.gz'));
      await checkedSource.writeAsBytes(bytes);
      final host = await _rented(plan);
      if (host == null) return Exit.unreachable;
      final address = host.address!;
      // The check, where the collection holds one: before this run's first change, and so on any way in.
      if (readHostCheckFiles(bytes) case final check?) {
        final answer = await askHostCheck(
          check,
          choices: hostCheckChoices(
            plan.preparationSettings,
            forge: plan.hasForge,
            kvm: '${plan.hasForge && plan.preparationSettings.kvm}',
          ),
          send: hostCheckSender(remote, address),
        );
        if (!answer.passed) {
          _write(Step('copy', StepState.refused, fix: answer.refusalWords));
          return Exit.refused;
        }
      }
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
for file in "$work/collection.tar.gz" "$work/inventory.yml" "$work/machine.yml"; do
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
      if (machineFile != null) {
        result = await remote.copy(address, 'root', machineFile.path, '$_workdir/machine.yml');
        if (result.exitCode != 0) return _refused('copy', result, 'The machine file could not be copied.');
        const place = '/etc/porelo-host/setup';
        result = await remote.run(
          address,
          'root',
          'set -e\n'
              'install -d -o root -g root -m 0755 ${path.posix.dirname(place)}\n'
              'install -d -o root -g root -m 0700 $place\n'
              'install -o root -g root -m 0600 $_workdir/machine.yml $place/machine.yml\n'
              'rm -f $_workdir/machine.yml\n'
              'sha256sum -c - >/dev/null',
          input: '${machineFile.digest}  $place/machine.yml\n',
        );
        if (result.exitCode != 0) return _refused('copy', result, 'The machine file did not arrive as it was sent.');
      }
      _write(const Step('copy', StepState.done));
      _write(const Step('ansible', StepState.started));
      result = await remote.run(
        address,
        'root',
        "set -e; if command -v cloud-init >/dev/null; then cloud-init status --wait >/dev/null || [ \$? -le 2 ]; fi\n"
            'DEBIAN_FRONTEND=noninteractive apt-get update -q >/dev/null\n'
            'DEBIAN_FRONTEND=noninteractive apt-get install -y -q ansible-core >/dev/null\n'
            'install -d -o root -g root -m 0755 /usr/share/ansible\n'
            '${_collectionCheck(expected.toLowerCase())}'
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
  /// it back all the same, for a person who has read that. [purge] removes only the named accounts
  /// before the play and cannot be combined with [giveBackAnyway].
  Future<int> down(HostPlan plan, {bool giveBackAnyway = false, List<String> purge = const []}) async {
    try {
      for (final login in purge) {
        checkPurgeLogin(login);
      }
      if (giveBackAnyway && purge.isNotEmpty) {
        throw const FormatException('--purge cannot be combined with --give-back-anyway.');
      }
      if (purge.isNotEmpty && plan.loginUser != 'root') throw const FormatException(_rootAlone);
    } on FormatException catch (error) {
      _write(Step('purge', StepState.refused, fix: error.message));
      return Exit.usage;
    }
    return _withProjectLock(plan, () async {
      try {
        return await _down(plan, giveBackAnyway, purge.toSet());
      } on ProviderFailed catch (e) {
        _write(Step('give-back', StepState.refused, fix: e.message));
        return Exit.refused;
      }
    }, forSetup: false);
  }

  /// Reads memberships using the rental's login and host pin, without running a play or changing the host.
  Future<int> memberships(HostPlan plan) async {
    const step = 'org-status';
    try {
      plan.check(forSetup: false);
      if (plan.loginUser != 'root') throw const FormatException(_rootAlone);
      _write(const Step(step, StepState.started));
      final host = await provider.find(plan.tag);
      if (host == null) return _unreachable(step, 'No host carries the rental tag.');
      final address = host.address;
      if (address == null) return _unreachable(step, 'The provider names no address for ${host.id}.');
      if (trust != null) {
        if (host.hostKey == null) {
          _write(
            const Step(step, StepState.refused, fix: 'The provider named no SSH host key for the membership read.'),
          );
          return Exit.refused;
        }
        await trust!(address, host.hostKey!);
      }
      final answer = StringBuffer();
      final result = await remote.run(
        address,
        plan.loginUser,
        poreloHostCommand('org status --json'),
        onLine: answer.writeln,
      );
      final words = [result.stderr, answer.toString()].where((part) => part.isNotEmpty).join('\n');
      if (result.exitCode == 255) return _unreachable(step, words);
      if (result.exitCode != 0) {
        return _refused(step, RemoteResult(result.exitCode, words), 'The host refused the membership read.');
      }
      HostMembership.readStatus(answer.toString());
      _write(Step(step, StepState.done, words: answer.toString().trim()));
      return Exit.done;
    } on FormatException catch (error) {
      _write(Step(step, StepState.refused, fix: error.message));
      return Exit.refused;
    } on ProviderFailed catch (error) {
      _write(Step(step, StepState.refused, fix: error.message));
      return Exit.refused;
    } on Exception {
      _write(const Step(step, StepState.refused, fix: 'The membership read could not complete.'));
      return Exit.refused;
    }
  }

  Future<int> _down(HostPlan plan, bool giveBackAnyway, Set<String> purge) async {
    _ownSteps = downSteps;
    _write(Step('plan', StepState.plan, steps: _ownSteps));
    final host = await provider.find(plan.tag);
    if (host == null) {
      _write(const Step('give-back', StepState.done, words: 'no host carries the project tag'));
      return Exit.done;
    }
    if (giveBackAnyway) {
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
    if (address != null && trust != null) {
      if (host.hostKey == null) {
        _write(const Step('copy', StepState.refused, fix: 'The provider named no SSH host key for teardown.'));
        return Exit.refused;
      }
      await trust!(address, host.hostKey!);
    }
    for (final login in purge) {
      final step = 'purge-$login';
      if (address == null) return _unreachable(step, 'the provider names no address for ${host.id}');
      _write(Step(step, StepState.started));
      final output = StringBuffer();
      final result = await remote.run(
        address,
        plan.loginUser,
        poreloHostCommand('person purge $login'),
        onLine: output.writeln,
      );
      final words = [result.stderr, output.toString()].where((part) => part.isNotEmpty).join('\n');
      if (result.exitCode == 255) return _unreachable(step, words);
      if (result.exitCode != 0) {
        return _refused(step, RemoteResult(result.exitCode, words), 'The purge failed; the host was kept.');
      }
      _write(Step(step, StepState.done));
    }
    if (plan.hostName != null && address != null) {
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
    final answered = StringBuffer();
    Future<RemoteResult> login() {
      answered.clear();
      return remote.run(host.address!, plan.loginUser, 'true', onLine: answered.writeln);
    }

    var reached = await login();
    // A host key that is not the provider's is never asked again: that is the one answer waiting
    // cannot change, and the refusal comes at once.
    final sshUntil = DateTime.now().add(sshWithin);
    while (provider is! GivenMachine &&
        reached.exitCode != 0 &&
        !_keyRefused(reached) &&
        DateTime.now().isBefore(sshUntil)) {
      await Future<void>.delayed(sshEvery);
      reached = await login();
    }
    if (provider is GivenMachine && _keyRefused(reached)) {
      _write(
        Step(
          'ssh',
          StepState.refused,
          fix:
              '$hostKeyNotFiled, so this try changed nothing on it. An install changes the key, so one fetched '
              'before it finished is not the key it holds now. Enter the key again and compare it on the machine.',
          words: [reached.stderr, answered.toString()].where((part) => part.isNotEmpty).join('\n'),
        ),
      );
      return null;
    }
    if (reached.exitCode == 255) {
      _unreachable('ssh', [reached.stderr, answered.toString()].where((part) => part.isNotEmpty).join('\n'));
      return null;
    }
    if (reached.exitCode != 0) {
      // ssh's own failure is 255: anything else means the host was reached, and answered.
      final said = answered.toString().trim();
      final words = [
        reached.stderr.trim(),
        said,
        'The login ended with exit code ${reached.exitCode}.',
      ].where((part) => part.isNotEmpty).join('\n');
      _write(
        Step(
          'ssh',
          StepState.refused,
          fix: said.contains('rather than the user')
              ? '$rootStillClosed Nothing changed on the machine.'
              : 'The machine answered and refused the login. Nothing changed on the machine.',
          words: words,
        ),
      );
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
        final over = hostProblem != null || failed != null || waiting != null;
        Step? step;
        try {
          step = _relayed(line, address, plan.account, plan.loginUser, plan: plan);
        } on FormatException catch (error) {
          if (!over) refuseHost(error.message);
          return;
        }
        if (step == null) return;
        // Told to a person, even after a failure: the machine stays, with what it says stays on it.
        if (over) {
          if (step.state == StepState.note) _write(step);
          return;
        }
        if (step.state == StepState.host) {
          final values = step.host!;
          final problem = playbook != 'porelo.host.up'
              ? 'The host record is allowed only from up.'
              : host != null
              ? 'The host record was repeated.'
              : lastState != StepState.done || failed != null || waiting != null
              ? 'The host record must follow the last successful up task.'
              // A machine reports its own IPv4 address. Reached by name or IPv6 address, it has nothing to compare
              // with here: its pinned host key, checked by the caller and by every ssh, says it is that machine.
              : isIpv4Address(address) && values.values['address'] != address
              ? 'host.json: address differs from the rental.'
              : plan.hostName != null && values.name != plan.hostName
              ? 'The completion names another server.'
              : null;
          if (problem != null) {
            refuseHost(problem);
          } else {
            host = isIpv4Address(address) ? values : values.reachedAt(address);
          }
          return;
        }
        if (host != null) {
          refuseHost('The host record must be the last line of up.');
          return;
        }
        // It ends nothing, and no later line depends on it.
        if (step.state == StepState.note) {
          _write(step);
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
    if (decoded is! Map<String, Object?>) return null;
    final state = decoded['state'];
    if (decoded['v'] != 1 || !validStepFields(decoded)) {
      if (state == 'failed' || state == 'waiting') {
        return const Step('play', StepState.refused, fix: 'The host reported a setup stop with malformed fields.');
      }
      return null;
    }
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
      'note' => words == null || words.isEmpty ? null : Step('note', StepState.note, words: words),
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
    'porelo_host_forge': plan.hasForge,
    'porelo_host_kvm': plan.hasForge && plan.preparationSettings.kvm,
  };
}
