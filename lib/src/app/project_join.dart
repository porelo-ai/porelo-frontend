import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_host/porelo_host.dart';
import 'package:yaml/yaml.dart';

import 'access_checkout.dart';
import 'access_join.dart';
import 'bring_project_file.dart';
import 'fleet_backend.dart';
import 'join_keys.dart';
import 'machines.dart';
import 'project_bring.dart';
import 'read_public_signing_key.dart';
import 'run_here.dart';

/// A verified developer join, with laptop changes behind Porelo's successful answer.
class ProjectJoin extends ChangeNotifier {
  /// Accepts the existing bundle builder, own-account SSH, and local VPN terminal.
  ProjectJoin({
    required this.project,
    required this.backend,
    required this.files,
    required this.signingKey,
    required this.keys,
    required this.root,
    required this.secretsFile,
    required this.activateVpn,
    required this.setForgePassword,
    this.targetBackend,
    this.environment,
    RunHere? run,
    this.remoteFor,
    this.restoreIdentity,
  }) : _run = run ?? runHere;

  /// The followed project's name.
  final String project;

  /// The daemon that supplies the verified project revision.
  final FleetBackend backend;

  /// The post-join daemon boundary, replaced only in tests.
  final FleetBackend? targetBackend;

  /// The existing signed project bundle builder.
  final HostFiles files;

  /// The public key already trusted for this project.
  final File signingKey;

  /// The laptop keys' system store boundary.
  final JoinKeys keys;

  /// The private join state root, outside public repositories and operation records.
  final String root;

  /// The encrypted secrets file, read only by the stop's terminal.
  final String secretsFile;

  /// The VPN terminal, called only with checked access and a matching CA.
  final Future<bool> Function(AccessJoin access, JoinPublicKeys keys, String address, String ca) activateVpn;

  /// The terminal-only lasting password feed, required before the first playbook start.
  final Future<bool> Function(Machine machine, String knownHosts) setForgePassword;

  /// The desktop's runtime and host-state paths.
  final Map<String, String>? environment;

  /// The pinned SSH factory; tests replace only transport.
  final Remote Function(String knownHosts, String identity)? remoteFor;

  /// The runtime identity restoration boundary, replaced only in tests.
  final Future<String> Function(String host)? restoreIdentity;
  final RunHere _run;

  /// Whether verification, setup, or upload is still running.
  bool busy = false;

  /// The public refusal; secrets and raw Git diagnostics are never retained.
  String? problem;

  /// The checked access settings, available only after verification.
  AccessJoin? access;

  /// The shared own-account playbook and stop runner.
  ProjectBring? accountRun;
  String? _joinedRecord;
  String? _recordFile;
  bool _disposed = false;

  /// Whether the host daemon confirmed the project's verified revision.
  bool get joined => accountRun?.brought == true;

  /// Verifies local bundles before reading laptop keys or opening any setup terminal.
  Future<void> join() async {
    if (busy || accountRun?.busy == true || joined) return;
    busy = true;
    problem = null;
    _notify();
    Directory? scratch;
    try {
      HostFiles.checkProjectName(project);
      SecretsFile.checkPath(secretsFile);
      final public = readPublicSigningKey(signingKey).trim().split(RegExp(r'\s+')).take(2).join(' ');
      final fingerprint = HostFiles.signingFingerprint(public);
      final followed = (await backend.following()).where((entry) => entry.name == project).firstOrNull;
      if (followed == null ||
          followed.unverified ||
          followed.commit.isEmpty ||
          !{...followed.signers, ...followed.pinned}.contains(fingerprint)) {
        throw const WorkspaceRefused('Choose the public signing key pinned for this verified followed project.');
      }
      BringProjectFile.checkSource(followed.url);
      final source = await files.createProjectSetup(
        project: project,
        url: followed.url,
        commit: followed.commit,
        signingKey: signingKey,
      );
      final contract = BringProjectFile.read(source.projectYaml);
      final directory = Directory(path.join(root, project));
      scratch = await HostFileWriter().createPrivateTemporary(Directory.systemTemp);
      final projectBundle = File(path.join(scratch.path, HostFiles.projectBundleFileName));
      final accessBundle = File(path.join(scratch.path, HostFiles.accessBundleFileName));
      await HostFileWriter().write(projectBundle, source.bytes);
      final checkout = path.join(scratch.path, 'access');
      final clone = await _git(['clone', '--no-checkout', '--', contract.access, checkout]);
      if (clone.code != 0) {
        throw WorkspaceRefused(
          'Cannot read ${contract.access}. Accept GitHub’s invitation to this private repository and check your own Git access. Nothing on this laptop was set up.',
        );
      }
      final bundled = await _bundleAccess(checkout, accessBundle);
      await HostFileWriter().protect(accessBundle);
      _recordFile = path.join(directory.path, 'joined.json');
      final previous = await _previous(contract.access);
      final answer = await _verify(scratch, public: public, commit: followed.commit, previous: previous);
      final accessCommit = answer['access_commit'] as String;
      final currentTip = (await _gitChecked(['rev-parse', '--verify', 'HEAD^{commit}'], checkout)).out.trim();
      final branchTip = (await _gitChecked([
        'rev-parse',
        '--verify',
        'refs/heads/${bundled.branch}^{commit}',
      ], checkout)).out.trim();
      if (accessCommit != bundled.commit || currentTip != accessCommit || branchTip != accessCommit) {
        throw const WorkspaceRefused(
          'The access clone’s tip differs from the commit Porelo verified. Nothing on this laptop was set up.',
        );
      }
      final checked = AccessJoin.read(answer);
      final ca = await _accessCa(checkout, accessCommit);
      checkJoinCa(checked.host, ca);
      final laptop = await _laptop(checked);
      await privateDirectory(directory);
      access = checked;
      if (!await activateVpn(checked, laptop.publicKeys, laptop.address, ca)) {
        throw const WorkspaceRefused('The VPN check did not confirm this host. The join did not start.');
      }
      final knownHosts = '${poreloHostKnownHosts(environment: environment)}.${checked.hostName}';
      final remote = _remote(knownHosts, laptop.identity);
      await _trust(knownHosts, checked.host.vpnAddress, checked.host.values['ssh_host_key']!);
      final uids = <String>[];
      final uidResult = await remote.run(checked.host.vpnAddress, laptop.account, '/usr/bin/id -u', onLine: uids.add);
      final uid = uids.length == 1 && RegExp(r'^[1-9][0-9]*$').hasMatch(uids.single) ? int.tryParse(uids.single) : null;
      if (uidResult.exitCode != 0 || uid == null || uid > 4294967294) {
        throw const WorkspaceRefused('The host did not confirm a non-root account for the joined daemon.');
      }
      final machineName = '${laptop.account}@${checked.host.vpnAddress}';
      final machine = Machine(
        name: machineName,
        socketPath: Machine.endpointFor(machineName, environment: environment),
        remoteSocket: Machine.porelodSocketFor(uid),
        kind: 'host',
        host: '${laptop.account}@${checked.host.vpnAddress}',
        hostProject: checked.hostName,
        identity: laptop.identity,
      );
      if (!await setForgePassword(machine, knownHosts)) {
        throw const WorkspaceRefused('The lasting forge password was not set. The join did not start.');
      }
      final homes = <String>[];
      final home = await remote.run(
        checked.host.vpnAddress,
        laptop.account,
        'printf \'%s\\n\' "\$HOME"',
        onLine: homes.add,
      );
      if (home.exitCode != 0 || homes.length != 1) {
        throw const WorkspaceRefused('The host refuses this account or did not report its home.');
      }
      final machineFile = File(path.join(scratch.path, 'machine.yml'));
      await HostFileWriter().write(
        machineFile,
        utf8.encode(
          HostFiles.machineYaml(
            project: project,
            url: HostFiles.bundleUrl(project, act: HostAct.ownAccount, home: homes.single),
            fingerprint: fingerprint,
            act: HostAct.ownAccount,
            keys: [for (final key in contract.keys) HostKeyFile(key, File(key))],
          ),
        ),
      );
      String? uploadFailure;
      final runner = HostRun(
        provider: GivenMachine(address: checked.host.vpnAddress, hostKey: checked.host.values['ssh_host_key']!),
        remote: remote,
        emit: (step) {
          if (step.state == StepState.refused) uploadFailure = step.words ?? step.fix;
        },
      );
      final upload = await runner.uploadSetupFiles(
        act: HostAct.ownAccount,
        address: checked.host.vpnAddress,
        user: laptop.account,
        project: project,
        machineFile: machineFile.path,
        bundle: projectBundle.path,
        accessBundle: accessBundle.path,
      );
      if (upload != null) throw WorkspaceRefused(uploadFailure ?? 'The own-account upload was refused.');
      accountRun?.removeListener(_notify);
      accountRun?.dispose();
      accountRun = ProjectBring(
        project: project,
        backend: backend,
        targetBackend: targetBackend,
        machine: machine,
        host: checked.host,
        knownHosts: knownHosts,
        secretsFile: secretsFile,
        signingKey: signingKey,
        accessRoot: root,
        remote: remote,
        files: files,
        joining: true,
      )..addListener(_notify);
      _joinedRecord = jsonEncode({
        'repository': contract.access,
        'commit': answer['commit'],
        'access_commit': answer['access_commit'],
      });
      await accountRun!.joinUploaded(commit: followed.commit, credentialKeys: contract.keys);
      await rememberJoined();
    } on WorkspaceRefused catch (error) {
      problem = error.words;
    } on HostFilesRefused catch (error) {
      problem = error.message;
    } on SecretStoreFailed {
      problem = 'The system secret store could not read this laptop’s host keys.';
    } on Exception {
      problem = 'The join could not complete. Check the signed repositories and pinned own-account connection.';
    } finally {
      if (scratch != null) await scratch.delete(recursive: true);
      busy = false;
      _notify();
    }
  }

  Future<({String branch, String commit})> _bundleAccess(String checkout, File bundle) async {
    final origin = (await _gitChecked(['symbolic-ref', '--short', 'refs/remotes/origin/HEAD'], checkout)).out.trim();
    if (!RegExp(r'^origin/[A-Za-z0-9][A-Za-z0-9._/-]*$').hasMatch(origin) || origin.contains('..')) {
      throw const WorkspaceRefused('The access repository has no safe default branch.');
    }
    final branch = origin.substring('origin/'.length);
    final commit = (await _gitChecked(['rev-parse', '--verify', 'HEAD^{commit}'], checkout)).out.trim();
    if (!_isCommit(commit)) throw const WorkspaceRefused('The access clone has no valid commit.');
    await _gitChecked(['bundle', 'create', bundle.path, 'refs/heads/$branch', 'HEAD'], checkout);
    return (branch: branch, commit: commit);
  }

  Future<String> _accessCa(String checkout, String commit) async {
    final contents = await _gitChecked(['show', '$commit:access.yml'], checkout);
    final Object? document;
    try {
      document = loadYaml(contents.out);
    } on YamlException {
      throw const WorkspaceRefused('The verified access file could not supply its host CA.');
    }
    final transports = document is Map ? document['transports'] : null;
    final matrix = transports is Map ? transports['matrix'] : null;
    final ca = matrix is Map ? matrix['ca_certificate'] : null;
    if (ca is! String || ca.isEmpty) {
      throw const WorkspaceRefused('The verified access file is missing its host CA certificate.');
    }
    return ca;
  }

  Future<Map<String, Object?>> _verify(
    Directory scratch, {
    required String public,
    required String commit,
    String? previous,
  }) async {
    final Ran verified;
    try {
      verified = await _run('porelo', [
        'project',
        'verify',
        '--json',
        '--repository',
        path.join(scratch.path, HostFiles.projectBundleFileName),
        '--signed-by',
        public,
        '--project',
        project,
        '--since',
        commit,
        '--access-repository',
        path.join(scratch.path, HostFiles.accessBundleFileName),
        if (previous != null) ...['--access-since', previous],
      ]);
    } on ProcessException {
      throw const WorkspaceRefused('Install Porelo on this computer');
    }
    if (verified.code != 0) {
      throw const WorkspaceRefused(
        'Porelo refused the project or signed access file. Nothing on this laptop was set up.',
      );
    }
    final answer = jsonDecode(verified.out);
    if (answer is! Map<String, Object?> ||
        answer['project'] != project ||
        answer['commit'] != commit ||
        !_isCommit(answer['access_commit'])) {
      throw const WorkspaceRefused('Porelo did not confirm this project and its access commit.');
    }
    return answer;
  }

  Future<({JoinPublicKeys publicKeys, String account, String address, String identity})> _laptop(
    AccessJoin checked,
  ) async {
    final publicKeys = await keys.publicKeys(checked.hostName);
    final laptop = checked.laptop(publicKeys);
    final identity =
        await (restoreIdentity?.call(checked.hostName) ?? keys.identity(checked.hostName, environment: environment));
    return (publicKeys: publicKeys, account: laptop.account, address: laptop.address, identity: identity);
  }

  /// Keeps the access commit only after the host daemon confirms the join.
  Future<void> rememberJoined() async {
    if (!joined || _recordFile == null || _joinedRecord == null) return;
    final destination = File(_recordFile!);
    final staging = await HostFileWriter().createPrivateTemporary(destination.parent);
    try {
      final file = File(path.join(staging.path, 'joined.json'));
      await HostFileWriter().write(file, utf8.encode(_joinedRecord!));
      await file.rename(destination.path);
      if (await destination.readAsString() != _joinedRecord) {
        throw const WorkspaceRefused('The joined access commit was not kept.');
      }
    } finally {
      await staging.delete(recursive: true);
    }
  }

  Future<String?> _previous(String repository) async {
    final type = await FileSystemEntity.type(_recordFile!, followLinks: false);
    if (type == FileSystemEntityType.notFound) return null;
    if (type != FileSystemEntityType.file) {
      throw const WorkspaceRefused('The joined revision record is not a plain file.');
    }
    final value = jsonDecode(await File(_recordFile!).readAsString());
    if (value is! Map ||
        value['repository'] is! String ||
        !_isCommit(value['access_commit']) ||
        !_isCommit(value['commit'])) {
      throw const WorkspaceRefused('The joined revision record is malformed.');
    }
    return value['repository'] == repository ? value['access_commit'] as String : null;
  }

  static bool _isCommit(Object? value) => value is String && RegExp(r'^(?:[0-9a-f]{40}|[0-9a-f]{64})$').hasMatch(value);

  Remote _remote(String knownHosts, String identity) =>
      remoteFor?.call(knownHosts, identity) ?? OpenSsh(knownHosts: File(knownHosts), identity: identity);

  Future<void> _trust(String file, String address, String key) async {
    final destination = File(file);
    await privateDirectory(destination.parent);
    final type = await FileSystemEntity.type(file, followLinks: false);
    if (type != FileSystemEntityType.file && type != FileSystemEntityType.notFound) {
      throw const WorkspaceRefused('The host’s known_hosts must be a plain file, without links.');
    }
    final staging = await HostFileWriter().createPrivateTemporary(destination.parent);
    try {
      final prepared = File(path.join(staging.path, 'known_hosts'));
      final contents = '$address ${key.split(' ').take(2).join(' ')}\n';
      await HostFileWriter().write(prepared, utf8.encode(contents));
      await prepared.rename(file);
      if (await destination.readAsString() != contents) {
        throw const WorkspaceRefused('The host’s pinned SSH key was not kept.');
      }
    } finally {
      await staging.delete(recursive: true);
    }
  }

  Future<Ran> _git(List<String> args, [String? directory]) async {
    try {
      return await _run('git', args, inDirectory: directory, environment: const {'GIT_TERMINAL_PROMPT': '0'});
    } on Exception {
      throw const WorkspaceRefused(
        'Git could not read the private access repository. Check your own Git access and GitHub invitation.',
      );
    }
  }

  Future<Ran> _gitChecked(List<String> args, String directory) async {
    final result = await _git(args, directory);
    if (result.code != 0) {
      throw const WorkspaceRefused('Git could not bundle the private access repository.');
    }
    return result;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    accountRun?.removeListener(_notify);
    accountRun?.dispose();
    super.dispose();
  }
}
