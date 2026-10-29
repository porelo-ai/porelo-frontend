import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_host/porelo_host.dart';
import 'package:porelo_frontend/client.dart';

import 'access_checkout.dart';
import 'bring_project_file.dart';
import 'fleet_backend.dart';
import 'host_stop_feed.dart';
import 'host_matrix_settings.dart';
import 'machines.dart';
import 'run_here.dart';
import 'read_public_signing_key.dart';

/// A bring in the project admin's own account, with no rental or privileged command.
class ProjectBring extends ChangeNotifier {
  /// Reuses the setup upload and accepts only SSH and Git replacements for tests.
  ProjectBring({
    required this.project,
    required this.backend,
    this.targetBackend,
    required this.machine,
    required this.host,
    required this.knownHosts,
    required this.secretsFile,
    required this.signingKey,
    required this.accessRoot,
    required this.remote,
    required this.files,
    this.forgeCa,
    this.runGit,
  });

  /// The followed project's name.
  final String project;

  /// The daemon that already verified the project revision.
  final FleetBackend backend;

  /// The host account's daemon, which confirms the followed commit after the playbook succeeds.
  final FleetBackend? targetBackend;

  /// The admitted person's pinned host connection.
  final Machine machine;

  /// The host admin's checked public values.
  final PreparedHost host;

  /// The pinned trust file, shared with every own-account SSH call.
  final String knownHosts;

  /// The encrypted file opened only by the terminal feed.
  final String secretsFile;

  /// The project's current signing public key file.
  final File signingKey;

  /// The public CA retained for this host alone, checked against its advertised digest.
  final String? forgeCa;

  /// The private access checkout root on this desktop.
  final String accessRoot;

  /// The SSH boundary, never a rental provider.
  final Remote remote;

  /// The signed project bundle builder.
  final HostFiles files;

  /// The person's Git process boundary, replaced only by stand-ins in tests.
  final RunHere? runGit;

  /// Whether the bring is still running, including its own-account stop.
  bool busy = false;

  /// Whether the playbook confirmed a successful bring.
  bool brought = false;

  /// A refusal, including the playbook's public explanation when a task fails.
  String? problem;

  final _lastLines = <String>[];
  String? _playbookFailure;

  /// The playbook's latest public output, kept in memory only.
  List<String> get lastLines => List.unmodifiable(_lastLines);

  /// The allowed needs of the current stop; no secret values enter this object.
  List<String> needs = const [];

  /// The vault entry names the signed project's machine file declares.
  List<String> keys = const [];
  List<String>? _stopCommand;
  bool _disposed = false;
  bool _canResume = false;
  String? _expectedCommit;

  /// The terminal command carrying secrets directly from the file into the own-account stop.
  List<String>? get stopCommand => _stopCommand;

  /// Verifies both repositories, publishes access settings, uploads privately, and runs exactly one bring.
  Future<void> bring() async {
    if (busy || brought) return;
    busy = true;
    problem = null;
    _notify();
    Directory? scratch;
    AccessCheckout? access;
    try {
      HostFiles.checkProjectName(project);
      SecretsFile.checkPath(secretsFile);
      checkHostMatrixCa(host, forgeCa);
      final login = RegExp(r'^([A-Za-z_][A-Za-z0-9_-]*)@([A-Za-z0-9][A-Za-z0-9.:-]*)$').firstMatch(machine.host);
      if (login == null || login[1] == 'root' || !path.isAbsolute(machine.identity) || !path.isAbsolute(knownHosts)) {
        throw const WorkspaceRefused(
          'Choose an admitted own-account host with a pinned SSH key and your own SSH identity.',
        );
      }
      final user = login[1]!;
      final address = login[2]!;
      if (address != host.vpnAddress) {
        throw const WorkspaceRefused('The admitted SSH address differs from the host admin’s values.');
      }
      if (FileSystemEntity.typeSync(machine.identity, followLinks: false) != FileSystemEntityType.file) {
        throw const WorkspaceRefused('Choose your own plain SSH identity file for the host account.');
      }
      if (remote case final OpenSsh ssh) {
        if (ssh.knownHosts.path != knownHosts ||
            ssh.identity != machine.identity ||
            !knownHosts.endsWith('.${host.values['homeserver']!.split('.')[1]}')) {
          throw const WorkspaceRefused('The bring needs this host’s own pinned trust file and your SSH identity.');
        }
        await ssh.trust(address, host.values['ssh_host_key']!);
      }
      final fingerprint = HostFiles.signingFingerprint(readPublicSigningKey(signingKey));
      final followed = (await backend.following()).where((entry) => entry.name == project).firstOrNull;
      if (followed == null || followed.commit.isEmpty || followed.unverified) {
        throw const WorkspaceRefused('This project needs a verified followed commit before it can be brought.');
      }
      BringProjectFile.checkSource(followed.url);
      final pinned = {...followed.signers, ...followed.pinned};
      if (pinned.isNotEmpty && !pinned.contains(fingerprint)) {
        throw const WorkspaceRefused('The chosen signing key is not pinned for this followed project.');
      }
      final source = await files.createProjectSetup(
        project: project,
        url: followed.url,
        commit: followed.commit,
        signingKey: signingKey,
      );
      _expectedCommit = followed.commit;
      final contract = BringProjectFile.read(source.projectYaml);
      keys = contract.keys;
      access = AccessCheckout(
        root: accessRoot,
        project: project,
        repository: contract.access,
        signingKey: signingKey,
        run: runGit,
      );
      await access.open();
      await access.writeHost(host, forgeCa);
      scratch = await HostFileWriter().createPrivateTemporary(Directory.systemTemp);
      final accessBundle = path.join(scratch.path, HostFiles.accessBundleFileName);
      await access.commitPushAndBundle(accessBundle);
      final homes = <String>[];
      final homeResult = await remote.run(address, user, 'printf \'%s\\n\' "\$HOME"', onLine: homes.add);
      if (homeResult.exitCode != 0 || homes.length != 1) {
        throw const WorkspaceRefused('The own-account host did not report exactly one home directory.');
      }
      final yaml = HostFiles.machineYaml(
        project: project,
        url: HostFiles.bundleUrl(project, act: HostAct.ownAccount, home: homes.single),
        fingerprint: fingerprint,
        act: HostAct.ownAccount,
        forgeRepositories: contract.repositories,
        keys: [for (final key in keys) HostKeyFile(key, File(key))],
      );
      final writer = HostFileWriter();
      final machineFile = File(path.join(scratch.path, 'machine.yml'));
      final bundle = File(path.join(scratch.path, HostFiles.projectBundleFileName));
      await writer.write(machineFile, utf8.encode(yaml));
      await writer.write(bundle, source.bytes);
      final runner = HostRun(
        provider: GivenMachine(address: address, hostKey: host.values['ssh_host_key']!),
        remote: remote,
        emit: (step) {
          if (step.state == StepState.refused) {
            _playbookFailure = step.words?.isNotEmpty == true ? step.words : step.fix;
          }
        },
      );
      final uploaded = await runner.uploadSetupFiles(
        act: HostAct.ownAccount,
        address: address,
        user: user,
        project: project,
        machineFile: machineFile.path,
        bundle: bundle.path,
        accessBundle: accessBundle,
      );
      if (uploaded != null) {
        throw WorkspaceRefused(
          _playbookFailure ?? 'The own-account setup upload was refused. The bring did not start.',
        );
      }
      await _runPlaybook();
    } on WorkspaceRefused catch (refusal) {
      problem = refusal.words;
    } on HostFilesRefused catch (refusal) {
      problem = refusal.message;
    } on Exception {
      problem = 'The project bring could not complete. Check your own Git credentials, signing setup, and pinned host connection.';
    } finally {
      await access?.close();
      if (scratch != null) await scratch.delete(recursive: true);
      busy = false;
      _notify();
    }
  }

  Future<void> _runPlaybook() async {
    _lastLines.clear();
    _playbookFailure = null;
    final login = machine.host.split('@');
    final result = await remote.run(
      login[1],
      login[0],
      inTheLoginShell(
        'ANSIBLE_STDOUT_CALLBACK=porelo.host.lines ansible-playbook -c local porelo.host.bring -e porelo_project=${quoteForAShell(project)}',
      ),
      onLine: _onPlaybookLine,
    );
    if (problem != null) throw WorkspaceRefused(problem!);
    // A stop ends the playbook; after its terminal succeeds only the playbook is resumed.
    if (needs.isNotEmpty && _stopCommand != null) return;
    if (result.stderr.trim().isNotEmpty) _appendOutput(result.stderr.trimRight());
    if (result.exitCode != 0 || _playbookFailure != null) {
      throw WorkspaceRefused(
        _playbookFailure ??
            (result.stderr.trim().isNotEmpty
                ? result.stderr.trimRight()
                : 'The bring did not complete. Check the host in your own account.'),
      );
    }
    final followed = targetBackend != null ? await targetBackend!.following() : await _followingOnHost();
    final observed = followed.where((entry) => entry.name == project).firstOrNull;
    if (observed == null || observed.unverified || observed.commit != _expectedCommit) {
      throw const WorkspaceRefused(
        'The playbook ended, but the host daemon did not confirm the verified project revision.',
      );
    }
    brought = true;
  }

  Future<List<Followed>> _followingOnHost() async {
    final connection = Backend(
      socketPath: '',
      label: machine.host,
      relay: [
        '/usr/bin/ssh',
        ...pinnedHostSshOptions(knownHosts, machine.identity),
        '-T',
        '--',
        machine.host,
        inTheLoginShell('porelo daemon connect'),
      ],
    );
    final daemon = await PoreloClient.connect(connection);
    return daemon.following();
  }

  /// Resumes only a successfully fed stop, reusing the checked setup files already on the host.
  Future<void> resume() async {
    if (busy || brought || !_canResume) return;
    _canResume = false;
    busy = true;
    problem = null;
    _notify();
    try {
      await _runPlaybook();
    } on WorkspaceRefused catch (refusal) {
      problem = refusal.words;
    } on Exception {
      problem = 'The bring could not resume over the pinned own-account connection.';
    } finally {
      busy = false;
      _notify();
    }
  }

  void _onPlaybookLine(String line) {
    Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      _appendOutput(line);
      _notify();
      return;
    }
    if (decoded is! Map<String, Object?> || decoded['v'] != 1) return;
    final event = decoded;
    var hasWords = false;
    for (final field in ['text', 'msg', 'words', 'fix']) {
      final words = event[field];
      if (words is String && words.isNotEmpty) {
        _appendOutput(words);
        hasWords = true;
      }
    }
    final task = event['task'];
    final state = event['state'];
    if (!hasWords && task is String && task.isNotEmpty && state is String) {
      _appendOutput('$task: $state');
    }
    if (event['state'] == 'failed' || event['state'] == 'refused') {
      final words = [event['msg'], event['words'], event['fix']].whereType<String>().where((line) => line.isNotEmpty);
      _playbookFailure = words.isEmpty ? 'The bring task failed.' : words.join('\n');
    }
    _notify();
    if (event['state'] != 'waiting') return;
    try {
      final waiting = event['needs'];
      if (waiting is! List || waiting.isEmpty || waiting.any((need) => need is! String)) {
        throw const FormatException();
      }
      final command = hostStopFeedCommand(
        act: HostAct.ownAccount,
        secretsFile: secretsFile,
        project: project,
        secretsHost: host.values['homeserver']!.split('.')[1],
        needs: waiting.cast<String>(),
        keys: keys,
        ssh: '/usr/bin/ssh',
        sshOptions: pinnedHostSshOptions(knownHosts, machine.identity),
        host: machine.host,
      );
      needs = List.unmodifiable(waiting.cast<String>());
      _stopCommand = command;
    } on FormatException {
      problem = 'The own-account bring requested a malformed or unsupported stop need.';
      _stopCommand = null;
    }
    _notify();
  }

  void _appendOutput(String output) {
    _lastLines.addAll(const LineSplitter().convert(output));
    if (_lastLines.length > 20) _lastLines.removeRange(0, _lastLines.length - 20);
  }

  /// Clears a stop only after the terminal confirms a successful feed.
  void stopFed(int code) {
    if (code != 0 || _stopCommand == null || needs.isEmpty) return;
    needs = const [];
    _stopCommand = null;
    _canResume = true;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
