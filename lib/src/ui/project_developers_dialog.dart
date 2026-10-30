import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_host/porelo_host.dart';

import '../app/access_checkout.dart';
import '../app/access_developers.dart';
import '../app/bring_project_file.dart';
import '../app/commands.dart';
import '../app/desk.dart';
import '../app/fleet_backend.dart';
import '../app/forge.dart';
import '../app/forge_connection.dart';
import '../app/project_developers.dart';
import '../app/read_public_signing_key.dart';
import '../app/run_here.dart';
import 'dialog_scroll.dart';
import 'tokens.dart';
import 'wizard.dart';

/// Opens developer settings from the verified project revision and existing forge token store.
Future<void> showProjectDevelopers(
  BuildContext context, {
  required String project,
  required FleetBackend backend,
  required ForgeConnection forges,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _DeveloperSettings(project: project, backend: backend, forges: forges),
);

class _DeveloperSettings extends StatefulWidget {
  const _DeveloperSettings({required this.project, required this.backend, required this.forges});
  final String project;
  final FleetBackend backend;
  final ForgeConnection forges;
  @override
  State<_DeveloperSettings> createState() => _DeveloperSettingsState();
}

class _DeveloperSettingsState extends State<_DeveloperSettings> {
  late final _signer = TextEditingController(text: '${desk.home}/.ssh/id_ed25519.pub');
  final _account = TextEditingController();
  late final _identity = TextEditingController(text: '${desk.home}/.ssh/id_ed25519');
  late final _changes = Listenable.merge([_signer, _account, _identity]);
  ProjectDevelopers? _developers;
  String? _problem;
  bool _busy = false;

  String? _check(void Function() check) {
    try {
      check();
      return null;
    } on FormatException catch (e) {
      return e.message;
    } on Exception {
      return 'Choose a readable plain public key file and your own SSH identity.';
    }
  }

  Future<void> _open() async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    SecretStore? store;
    AccessCheckout? access;
    try {
      checkAdminName(_account.text.trim());
      final signer = File(desk.expandHome(_signer.text.trim()));
      final identity = desk.expandHome(_identity.text.trim());
      if (_account.text.trim() == 'root' ||
          !path.isAbsolute(identity) ||
          FileSystemEntity.typeSync(identity, followLinks: false) != FileSystemEntityType.file) {
        throw const FormatException('Choose your own project admin account and a plain SSH identity file.');
      }
      final public = readPublicSigningKey(signer);
      final followed = (await widget.backend.following()).where((f) => f.name == widget.project).firstOrNull;
      if (followed == null || followed.unverified || followed.commit.isEmpty) {
        throw const WorkspaceRefused('Follow and verify the project before editing developer access.');
      }
      final fingerprint = HostFiles.signingFingerprint(public);
      final trusted = {...followed.signers, ...followed.pinned};
      if (trusted.isNotEmpty && !trusted.contains(fingerprint)) {
        throw const WorkspaceRefused('Choose the public signing key pinned for this project.');
      }
      BringProjectFile.checkSource(followed.url);
      store = SecretStore.forThisSystem();
      final source = await HostFiles(store)
          .createProjectSetup(project: widget.project, url: followed.url, commit: followed.commit, signingKey: signer);
      final contract = BringProjectFile.read(source.projectYaml);
      await widget.forges.readList();
      final fullName = fullNameOf(contract.access);
      final entry = widget.forges.holding(contract.access);
      final reached = entry == null ? null : await widget.forges.reach(entry);
      if ((entry?.kind == 'github' || hostOf(contract.access) == 'github.com') && reached == null) {
        throw const ForgeRefused(
          'Give this central forge a token in Your forges. It needs Administration: Read and write on the access repository.',
        );
      }
      access = AccessCheckout(
        root: '${desk.data}/access',
        project: widget.project,
        repository: contract.access,
        signingKey: signer,
      );
      final remote = OpenSsh(
        knownHosts: File('${poreloHostKnownHosts()}.${widget.project}-developers'),
        identity: identity,
      );
      final model = ProjectDevelopers(
        access: access,
        forge: reached?.forge,
        repository: fullName ?? '',
        sync: DeveloperHostSync(remote: remote, account: _account.text.trim()).call,
      );
      await model.load();
      if (!mounted || model.listed == null) {
        _problem =
            model.problem ??
            'Developer settings could not open. Check the verified project and your Git signing setup.';
        model.dispose();
        return;
      }
      _developers?.dispose();
      setState(() => _developers = model);
    } on WorkspaceRefused catch (e) {
      _problem = e.words;
    } on ForgeRefused catch (e) {
      _problem = e.words;
    } on FormatException catch (e) {
      _problem = e.message;
    } on Exception {
      _problem = 'Developer settings could not open. Check the verified project and your Git signing setup.';
    } finally {
      await access?.close();
      await store?.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _developers?.dispose();
    _signer.dispose();
    _account.dispose();
    _identity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final developers = _developers;
    if (developers?.listed != null) return ProjectDevelopersDialog(developers: developers!);
    return Wizard(
      title: 'Project settings: Developers — ${widget.project}',
      changes: _changes,
      action: 'Open developers',
      steps: [
        WizardStep(
          title: 'Signing key',
          words: 'Choose the public key that verifies this project. Your configured Git signs every change to its private access file.',
          panel: (_) => _field(_signer, 'Project signing public key file', 'developers-signing-key'),
          check: () => _check(() => readPublicSigningKey(File(desk.expandHome(_signer.text.trim())))),
          summary: () => ['Signing public key: ${_signer.text}'],
        ),
        WizardStep(
          title: 'Admin account',
          words: 'Use your project admin account on the host. Its SSH identity stays on this computer. The signed access file supplies the host network and SSH host key.',
          panel: (_) => Column(
            children: [
              _field(_account, 'Your project admin account on the host', 'developers-admin'),
              _field(_identity, 'Your SSH identity file', 'developers-identity'),
            ],
          ),
          check: () => _check(() {
            checkAdminName(_account.text.trim());
            if (_account.text.trim() == 'root' ||
                !path.isAbsolute(desk.expandHome(_identity.text.trim())) ||
                FileSystemEntity.typeSync(desk.expandHome(_identity.text.trim()), followLinks: false) !=
                    FileSystemEntityType.file) {
              throw const FormatException('Choose your own account and a plain SSH identity file.');
            }
          }),
          summary: () => ['Admin account: ${_account.text}', 'SSH identity file: ${_identity.text}'],
        ),
      ],
      actionSteps: [
        WizardActionStep(
          title: 'Developers',
          words: 'Read the signed access checkout and ask the central forge about read access.',
          run: _open,
          state: () => _busy ? WizardActionState.running : WizardActionState.refused,
          panel: (_) => SelectableText(_problem ?? 'Opening developer settings…'),
        ),
      ],
    );
  }
}

Widget _field(TextEditingController controller, String label, String key) => Padding(
  padding: const EdgeInsets.only(bottom: Space.small),
  child: TextField(
    key: Key(key),
    controller: controller,
    decoration: InputDecoration(labelText: label),
  ),
);

/// The developer list, showing confirmed publication, host sync, and forge results.
class ProjectDevelopersDialog extends StatelessWidget {
  /// Shows this project’s developer access and its confirmed external answers.
  const ProjectDevelopersDialog({required this.developers, super.key});

  /// The access editor and last host and forge answers.
  final ProjectDevelopers developers;

  Command _command(String id, String label, VoidCallback run, {String? unavailable}) => Command(
    id: 'developers.$id',
    label: label,
    group: 'Developers',
    home: Home.openedView,
    run: run,
    unavailable: developers.busy ? 'Wait for the current operation.' : unavailable,
  );

  Widget _button(Command command) => Tooltip(
    message: command.unavailable ?? command.label,
    child: TextButton(
      key: Key(command.id),
      onPressed: command.unavailable == null ? command.run : null,
      child: Text(command.label),
    ),
  );

  Future<void> _remove(BuildContext context, AccessDeveloper developer, [AccessLaptop? laptop]) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(laptop == null ? 'Remove ${developer.account}?' : 'Remove laptop ${laptop.vpnAddress}?'),
        content: Text(
          laptop == null
              ? 'Sign and push the removal, sync the host, and revoke this developer’s direct read access and pending invitation to the access repository.'
              : 'Sign and push the laptop removal, then sync the host. The developer’s other laptop access stays listed.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
          FilledButton(
            key: const Key('developers-confirm-remove'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove, signed'),
          ),
        ],
      ),
    );
    if (yes == true) {
      if (laptop == null) {
        await developers.remove(developer.account);
      } else {
        await developers.removeLaptop(developer.account, laptop.vpnAddress);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: developers,
    builder: (context, _) {
      final listed = developers.listed;
      final unavailable = developers.needsRetry ? 'Retry the published change before another edit.' : null;
      String? noFreeAddress;
      try {
        listed?.nextAddress();
      } on FormatException catch (refused) {
        noFreeAddress = refused.message;
      }
      return AlertDialog(
        key: const Key('developers-dialog'),
        title: Text('Developers — ${developers.access.project}'),
        content: SizedBox(
          width: Sizes.dialog,
          child: DialogScroll(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Changes are signed with your own Git, pushed to the private access repository, then applied through the project admin’s host sync.',
                ),
                if (developers.problem != null)
                  SelectableText(
                    developers.problem!,
                    key: const Key('developers-problem'),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                if (developers.busy) const LinearProgressIndicator(),
                if (listed != null) ...[
                  Text('Host network: ${listed.network}'),
                  _button(
                    _command(
                      'add',
                      'Add developer…',
                      () => unawaited(
                        showDialog<void>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => _AddDeveloper(developers: developers),
                        ),
                      ),
                      unavailable: unavailable ?? noFreeAddress,
                    ),
                  ),
                  if (noFreeAddress != null) Text(noFreeAddress),
                  if (listed.developers.isEmpty) const Text('No developers are listed.'),
                  for (final developer in listed.developers.values) ...[
                    const SizedBox(height: Space.small),
                    Text(developer.account, style: Theme.of(context).textTheme.titleSmall),
                    Text(
                      'Listed in the signed access file. Host: ${developers.lastSync?.state(developer.account) ?? 'not read; no sync answer yet'}.',
                      key: ValueKey('developer-host-${developer.account}'),
                    ),
                    Text(
                      developer.forgeLogin == null
                          ? 'No central forge login listed.'
                          : '${developer.forgeLogin}: ${developers.forgeStates[developer.forgeLogin] ?? 'not read from the forge'}.',
                      key: ValueKey('developer-forge-${developer.account}'),
                    ),
                    for (final laptop in developer.laptops)
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('Laptop ${laptop.vpnAddress}'),
                          _button(
                            _command(
                              'remove-laptop-${developer.account}-${laptop.vpnAddress}',
                              'Remove laptop…',
                              () => unawaited(_remove(context, developer, laptop)),
                              unavailable:
                                  unavailable ??
                                  (developer.laptops.length == 1
                                      ? 'Remove the developer to remove their last laptop.'
                                      : null),
                            ),
                          ),
                        ],
                      ),
                    _button(
                      _command(
                        'remove-${developer.account}',
                        'Remove developer…',
                        () => unawaited(_remove(context, developer)),
                        unavailable: unavailable,
                      ),
                    ),
                  ],
                  for (final account in developers.removed.keys)
                    Text(
                      '$account: removed from the signed access file. Host: ${developers.lastSync?.state(account) ?? 'not confirmed'}. Forge: ${developers.forgeStates[developers.removed[account]] ?? 'not confirmed'}.',
                      key: ValueKey('developer-removed-$account'),
                    ),
                  if (developers.lastSync case final answer?)
                    SelectableText(
                      'Last sync: project ${answer.commit}; access ${answer.accessCommit}\nLaptops added: ${answer.laptopsAdded.join(', ')}\nLaptops dropped: ${answer.laptopsDropped.join(', ')}',
                    ),
                  _button(_command('sync', 'Sync with the host', () => unawaited(developers.syncHost()))),
                  _button(
                    _command(
                      'refresh',
                      'Refresh the signed list and forge answers',
                      () => unawaited(developers.load()),
                      unavailable: unavailable,
                    ),
                  ),
                  if (developers.needsRetry)
                    _button(_command('retry', 'Retry applying published access', () => unawaited(developers.retry()))),
                  if (!developers.managesReadAccess) ...[
                    const Text(
                      'This forge has no collaborator API here. Grant each listed login read access to the access repository; revoke it when removing them.',
                    ),
                    _button(
                      _command(
                        'grant-manually',
                        'Open the access repository to grant read access',
                        () {
                          final address = developers.access.repository;
                          final host = hostOf(address);
                          final name = fullNameOf(address);
                          if (host != null && name != null) unawaited(desk.open('https://$host/$name'));
                        },
                        unavailable: hostOf(developers.access.repository) == null
                            ? 'The access repository has no web address.'
                            : null,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: developers.busy ? null : () => Navigator.pop(context), child: const Text('Done')),
        ],
      );
    },
  );
}

class _AddDeveloper extends StatefulWidget {
  const _AddDeveloper({required this.developers});

  /// The access editor and last host and forge answers.
  final ProjectDevelopers developers;
  @override
  State<_AddDeveloper> createState() => _AddDeveloperState();
}

class _AddDeveloperState extends State<_AddDeveloper> {
  final _account = TextEditingController();
  final _login = TextEditingController();
  final _keys = TextEditingController();
  late final _address = TextEditingController(text: widget.developers.listed!.nextAddress());
  late final _changes = Listenable.merge([_account, _login, _keys, _address]);
  final _laptops = <AccessLaptop>[];
  bool _done = false;
  String? _keyProblem;

  String? _check(void Function() check) {
    try {
      check();
      return null;
    } on FormatException catch (e) {
      return e.message;
    }
  }

  AccessLaptop _laptop() {
    widget.developers.listed!.checkAddress(_address.text.trim());
    if (_laptops.any((l) => l.vpnAddress == _address.text.trim())) {
      throw const FormatException('This laptop address is already in the new developer.');
    }
    return parseLaptopPublicKeys(_keys.text, _address.text.trim());
  }

  List<AccessLaptop> _all() => [..._laptops, if (_keys.text.trim().isNotEmpty) _laptop()];

  @override
  void dispose() {
    for (final c in [_account, _login, _keys, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Wizard(
    title: 'Add developer',
    changes: _changes,
    action: 'Add developer, signed',
    steps: [
      WizardStep(
        title: 'Host account',
        words: 'Choose the developer’s account name on the host: a lower-case letter followed by lower-case letters, digits, underscores or dashes, at most 32 characters.',
        panel: (_) => _field(_account, 'Developer account on the host', 'developer-account'),
        check: () => _check(() {
          checkAdminName(_account.text.trim());
          if (widget.developers.listed!.developers.containsKey(_account.text.trim())) {
            throw const FormatException('This developer is already listed.');
          }
        }),
        summary: () => ['Host account: ${_account.text.trim()}'],
      ),
      WizardStep(
        title: 'Central forge',
        words: 'Enter their GitHub login, found on their GitHub profile. They receive read access to the private access repository after the signed change is pushed. Leave empty only if they have no central forge login.',
        panel: (_) => _field(_login, 'Developer GitHub login (optional)', 'developer-forge-login'),
        check: () => _login.text.trim().isEmpty ? null : _check(() => checkForgeLogin(_login.text.trim())),
        summary: () => ['Forge login: ${_login.text.trim().isEmpty ? 'none' : _login.text.trim()}'],
      ),
      WizardStep(
        title: 'Laptops',
        words: 'Paste the YAML block from Copy my public keys: ssh_public_key and wireguard_public_key. The SSH comment is discarded. Review the proposed free VPN address. Keep a laptop before adding another.',
        panel: (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final laptop in _laptops) Text('Laptop ${laptop.vpnAddress} kept'),
            TextField(
              key: const Key('developer-public-keys'),
              controller: _keys,
              minLines: 3,
              maxLines: 5,
              inputFormatters: [_PublicKeysOnly((problem) => setState(() => _keyProblem = problem))],
              decoration: InputDecoration(labelText: 'Laptop public keys (YAML)', errorText: _keyProblem),
            ),
            _field(_address, 'Laptop VPN address', 'developer-vpn-address'),
            TextButton(
              key: const Key('developer-keep-laptop'),
              onPressed: () {
                final problem = _check(_laptop);
                if (problem != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
                  return;
                }
                setState(() {
                  _laptops.add(_laptop());
                  _keys.clear();
                  try {
                    _address.text = widget.developers.listed!.nextAddress(reserved: _laptops.map((l) => l.vpnAddress));
                  } on FormatException {
                    _address.clear();
                  }
                });
              },
              child: const Text('Keep laptop and add another'),
            ),
          ],
        ),
        check: () => _check(() {
          if (_all().isEmpty) throw const FormatException('Paste at least one laptop’s public keys.');
        }),
        summary: () {
          try {
            return [for (final l in _all()) 'Laptop ${l.vpnAddress}: ${l.sshPublicKey}; ${l.wireguardPublicKey}'];
          } on FormatException {
            return ['Laptop public keys need checking.'];
          }
        },
      ),
    ],
    actionSteps: [
      WizardActionStep(
        title: 'Apply access',
        words: 'Sign and push the developer list, sync the host, and ask the central forge to grant read access.',
        run: () async {
          await widget.developers.addDeveloper(
            AccessDeveloper(_account.text.trim(), _login.text.trim().isEmpty ? null : _login.text.trim(), _all()),
          );
          if (mounted) setState(() => _done = widget.developers.problem == null);
        },
        state: () => widget.developers.busy
            ? WizardActionState.running
            : _done
            ? WizardActionState.done
            : WizardActionState.refused,
        panel: (_) => SelectableText(
          widget.developers.problem ??
              (_done
                  ? widget.developers.managesReadAccess
                        ? 'The signed developer entry was published and access was applied.'
                        : 'The signed developer entry was published and the host sync confirmed it. Grant central forge read access manually from Developers.'
                  : 'Applying developer access…'),
        ),
      ),
    ],
  );
}

class _PublicKeysOnly extends TextInputFormatter {
  _PublicKeysOnly(this.report);
  final void Function(String?) report;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      report(null);
      return newValue;
    }
    try {
      final laptop = parseLaptopPublicKeys(newValue.text, '');
      report(null);
      final text = 'ssh_public_key: "${laptop.sshPublicKey}"\nwireguard_public_key: "${laptop.wireguardPublicKey}"\n';
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    } on FormatException {
      report(
        'Paste the complete YAML block containing only ssh_public_key and wireguard_public_key. Other input is refused before display.',
      );
      return oldValue;
    }
  }
}
