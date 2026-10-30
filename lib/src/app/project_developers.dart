import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:porelo_host/porelo_host.dart';

import 'access_checkout.dart';
import 'access_developers.dart';
import 'forge.dart';
import 'run_here.dart';

/// Runs the admin sync through the account's pinned SSH connection.
class DeveloperHostSync {
  /// Uses the project admin's own account and transport, never a root login.
  DeveloperHostSync({required this.remote, required this.account});

  /// The pinned SSH transport.
  final Remote remote;

  /// The project admin’s own host account.
  final String account;

  /// Requests exactly one sync and retains only its validated public answer.
  Future<DeveloperSyncAnswer> call(String project, AccessDevelopers access) async {
    checkAdminName(account);
    HostFiles.checkProjectName(project);
    if (account == 'root') throw const FormatException('Use your own project admin account.');
    if (remote case final OpenSsh ssh) await ssh.trust(access.hostAddress, access.sshHostKey);
    final lines = <String>[];
    final result = await remote.run(
      access.hostAddress,
      account,
      inTheLoginShell('/usr/bin/sudo -n /usr/local/sbin/porelo-host-person sync ${quoteForAShell(project)}'),
      onLine: lines.add,
    );
    if (result.exitCode != 0) throw HostAdminRefused(result.stderr);
    if (lines.length != 1) throw const FormatException('The admin sync must answer with one JSON line.');
    return DeveloperSyncAnswer.read(lines.single, project);
  }
}

/// The host's last successful sync, with no inferred lock or admission states.
class DeveloperSyncAnswer {
  DeveloperSyncAnswer._(
    this.commit,
    this.accessCommit,
    this.added,
    this.dropped,
    this.unchanged,
    this.laptopsAdded,
    this.laptopsDropped,
  );

  /// The project revision reported by the host.
  final String commit;

  /// The access revision reported by the host.
  final String accessCommit;

  /// The accounts admitted by this sync.
  final List<String> added;

  /// The accounts dropped by this sync.
  final List<String> dropped;

  /// The accounts the host reported as unchanged.
  final List<String> unchanged;

  /// The laptop identifiers added by this sync.
  final List<String> laptopsAdded;

  /// The laptop identifiers dropped by this sync.
  final List<String> laptopsDropped;

  /// Validates the sync identity, both revisions, and every reported account and laptop.
  factory DeveloperSyncAnswer.read(String line, String project) {
    try {
      final value = jsonDecode(line);
      if (value is! Map || value['project'] != project) throw const FormatException();
      String revision(String field) {
        final revision = value[field];
        if (revision is! String || !RegExp(r'^(?:[0-9a-f]{40}|[0-9a-f]{64})$').hasMatch(revision)) {
          throw const FormatException();
        }
        return revision;
      }

      List<String> names(String field, {bool laptop = false}) {
        final items = value[field];
        if (items is! List || items.any((v) => v is! String)) throw const FormatException();
        for (final item in items.cast<String>()) {
          final parts = item.split('/');
          checkAdminName(parts.first);
          if (laptop
              ? parts.length != 2 || !RegExp(r'^[a-z0-9][a-z0-9-]{0,31}$').hasMatch(parts[1])
              : parts.length != 1) {
            throw const FormatException();
          }
        }
        if (items.toSet().length != items.length) throw const FormatException();
        return List.unmodifiable(items.cast<String>());
      }

      final added = names('added'), dropped = names('dropped'), unchanged = names('unchanged');
      if ({...added, ...dropped, ...unchanged}.length != added.length + dropped.length + unchanged.length) {
        throw const FormatException();
      }
      return DeveloperSyncAnswer._(
        revision('commit'),
        revision('access_commit'),
        added,
        dropped,
        unchanged,
        names('laptops_added', laptop: true),
        names('laptops_dropped', laptop: true),
      );
    } on Exception {
      throw const FormatException('The host returned a malformed sync answer or answered for another project.');
    }
  }

  /// Reports only what this sync said about [account].
  String state(String account) => added.contains(account)
      ? 'admitted by last sync'
      : dropped.contains(account)
      ? 'dropped by last sync'
      : unchanged.contains(account)
      ? 'unchanged at last sync'
      : 'not reported by last sync';
}

/// Edits signed developer access, then applies it at the host and central forge.
class ProjectDevelopers extends ChangeNotifier {
  /// Reuses the private checkout, central forge, and admin sync boundary.
  ProjectDevelopers({required this.access, required this.forge, required this.repository, required this.sync});

  /// The private, signed access checkout.
  final AccessCheckout access;

  /// The central forge reached with the existing token store.
  final Forge? forge;

  /// The access repository’s owner/name at the central forge.
  final String repository;

  /// The project admin’s sync boundary.
  final Future<DeveloperSyncAnswer> Function(String project, AccessDevelopers access) sync;

  /// The last verified and published developer list.
  AccessDevelopers? listed;

  /// The last confirmed host sync answer in this settings session.
  DeveloperSyncAnswer? lastSync;

  /// The last read-access answers from the forge.
  final Map<String, String> forgeStates = {};

  /// The accounts removed during this session and their former forge logins.
  final Map<String, String?> removed = {};

  /// The latest refusal, with publication distinguished from external application.
  String? problem;

  /// Whether an access operation is still running.
  bool busy = false;
  bool _disposed = false;
  Future<void> Function()? _pendingForge;
  bool _pendingSync = false;
  String? _accessCommit;

  /// Whether a published change still needs an external confirmation.
  bool get needsRetry => _pendingSync || _pendingForge != null;

  /// Whether this forge implements collaborator management.
  bool get managesReadAccess => forge is ForgeCollaborators;

  /// Reads the verified checkout and current forge answers without changing host admission.
  Future<void> load() => _doing(() async {
    if (needsRetry) throw const FormatException('Retry the published access change before refreshing its signed list.');
    await access.open();
    try {
      listed = parseAccessDevelopers(await access.read());
      _accessCommit = await access.revision();
    } finally {
      await access.close();
    }
    await _readForge();
  });

  Future<void> _readForge() async {
    if (forge case final ForgeCollaborators collaborators) {
      final states = await collaborators.readAccess(repository, [
        for (final developer in listed!.developers.values)
          if (developer.forgeLogin != null) developer.forgeLogin!,
        ...removed.values.whereType<String>(),
      ]);
      forgeStates.addAll(states);
    }
  }

  /// Publishes exactly one new developer with one or more checked laptops.
  Future<void> add(String account, String login, String keyBlock, String address) =>
      addDeveloper(AccessDeveloper(account, login.isEmpty ? null : login, [parseLaptopPublicKeys(keyBlock, address)]));

  /// Publishes the reviewed developer and requests read access once.
  Future<void> addDeveloper(AccessDeveloper developer) => _change(
    (current) {
      if (current.developers.containsKey(developer.account)) {
        throw const FormatException('This developer is already listed.');
      }
      final addresses = <String>{};
      for (final laptop in developer.laptops) {
        current.checkAddress(laptop.vpnAddress);
        if (!addresses.add(laptop.vpnAddress)) throw const FormatException('A laptop VPN address is repeated.');
      }
      return developer;
    },
    account: developer.account,
    grant: developer.forgeLogin,
  );

  /// Removes a developer from the signed list and revokes their forge access.
  Future<void> remove(String account) => _change(
    (current) {
      if (!current.developers.containsKey(account)) throw const FormatException('This developer is no longer listed.');
      return null;
    },
    account: account,
    revoke: true,
  );

  /// Removes one laptop while retaining at least one for the developer.
  Future<void> removeLaptop(String account, String address) => _change((current) {
    final developer = current.developers[account];
    if (developer == null || !developer.laptops.any((laptop) => laptop.vpnAddress == address)) {
      throw const FormatException('This laptop is no longer listed.');
    }
    return AccessDeveloper(
      account,
      developer.forgeLogin,
      developer.laptops.where((laptop) => laptop.vpnAddress != address).toList(),
    );
  }, account: account);

  Future<void> _change(
    AccessDeveloper? Function(AccessDevelopers current) change, {
    required String account,
    String? grant,
    bool revoke = false,
  }) => _doing(() async {
    if (needsRetry) throw const FormatException('Retry the published access change before editing another developer.');
    checkAdminName(account);
    final collaborators = forge is ForgeCollaborators ? forge as ForgeCollaborators : null;
    await access.open();
    Directory? temporary;
    try {
      final original = await access.read();
      final current = parseAccessDevelopers(original);
      final developer = change(current);
      final oldLogin = revoke ? current.developers[account]?.forgeLogin : null;
      if (oldLogin != null &&
          current.developers.values.any(
            (d) => d.account != account && d.forgeLogin?.toLowerCase() == oldLogin.toLowerCase(),
          )) {
        throw const FormatException(
          'Another listed developer uses this forge login. Resolve the shared login before revoking access.',
        );
      }
      if (collaborators != null && (grant != null || oldLogin != null)) {
        await collaborators.checkAdministration(repository);
      }
      final written = writeAccessDeveloper(original, account, developer);
      final next = parseAccessDevelopers(written);
      await access.edit((source) {
        if (source != original) {
          throw const WorkspaceRefused('The access file changed during review. Open it again before publishing.');
        }
        return written;
      });
      temporary = await HostFileWriter().createPrivateTemporary(Directory.systemTemp);
      await access.commitPushAndBundle(
        '${temporary.path}/access.bundle',
        message: 'Update project developers',
        onPublished: (revision) {
          listed = next;
          _accessCommit = revision;
          if (developer == null) removed[account] = oldLogin;
          _pendingSync = true;
          if (collaborators != null && grant != null) {
            _pendingForge = () async {
              forgeStates[grant] = await collaborators.grantRead(repository, grant);
            };
          } else if (collaborators != null && oldLogin != null) {
            _pendingForge = () async {
              await collaborators.revokeRead(repository, oldLogin);
              forgeStates[oldLogin] = 'direct access revoked';
            };
          }
        },
      );
    } finally {
      try {
        await access.close();
      } finally {
        if (temporary != null) await temporary.delete(recursive: true);
      }
    }
    await _apply();
  });

  /// Retries only the unconfirmed external steps, without another commit or invitation.
  Future<void> retry() => _doing(_apply);

  /// Requests the admin's sync and records its answer.
  Future<void> syncHost() => _doing(() async {
    _pendingSync = true;
    await _apply();
  });

  Future<void> _apply() async {
    final failures = <String>[];
    if (_pendingSync) {
      try {
        final answer = await sync(access.project, listed!);
        if (answer.accessCommit != _accessCommit) throw const FormatException('The host synced another access commit.');
        lastSync = answer;
        _pendingSync = false;
      } on HostAdminRefused catch (refused) {
        failures.add(refused.words);
      } on Exception {
        failures.add(
          'The host sync did not confirm the published access change. Check your project admin account and pinned connection.',
        );
      }
    }
    final applyForge = _pendingForge;
    if (applyForge != null) {
      try {
        await applyForge();
        _pendingForge = null;
      } on ForgeRefused catch (refused) {
        failures.add(refused.words);
      }
    }
    try {
      await _readForge();
    } on ForgeRefused catch (refused) {
      failures.add(refused.words);
    }
    if (failures.isNotEmpty) problem = 'The signed access file was published. ${failures.join('\n')}';
  }

  Future<void> _doing(Future<void> Function() action) async {
    if (busy) return;
    busy = true;
    problem = null;
    _notify();
    try {
      await action();
    } on WorkspaceRefused catch (refused) {
      problem = refused.words;
    } on ForgeRefused catch (refused) {
      problem = refused.words;
    } on FormatException catch (refused) {
      problem = refused.message;
    } on Exception {
      problem = 'Developer access could not be updated. No private diagnostic was recorded.';
    } finally {
      if (needsRetry && problem != null && !problem!.startsWith('The signed access file was published.')) {
        problem = 'The signed access file was published. $problem';
      }
      busy = false;
      _notify();
    }
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
