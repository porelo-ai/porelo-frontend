import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'provider.dart';
import 'remote.dart';
import 'steps.dart';

/// What the person gives at the one stop, held in memory and handed to the host's commands on
/// their standard input only.
class Answers {
  /// Constructor taking the drive's login and the vault's passphrase, each where it was asked for.
  const Answers({this.driveEmail, this.drivePassword, this.driveCode, this.vaultPassphrase});

  /// The answers as the interface writes them to `up`'s standard input: one JSON object.
  factory Answers.fromJson(String text) {
    final map = jsonDecode(text) as Map<String, Object?>;
    return Answers(
      driveEmail: map['driveEmail'] as String?,
      drivePassword: map['drivePassword'] as String?,
      driveCode: map['driveCode'] as String?,
      vaultPassphrase: map['vaultPassphrase'] as String?,
    );
  }

  /// The drive's login name.
  final String? driveEmail;

  /// The drive's password.
  final String? drivePassword;

  /// The drive's second factor, a one-time code, when the account has one.
  final String? driveCode;

  /// The vault's passphrase.
  final String? vaultPassphrase;

  /// Whether anything was given at all.
  bool get any => drivePassword != null || vaultPassphrase != null;

  @override
  String toString() => 'Answers(drive: ${drivePassword != null}, vault: ${vaultPassphrase != null})';
}

/// What one host of one project is made from.
class HostPlan {
  /// Constructor taking the project, the account and the files that go up.
  const HostPlan({
    required this.project,
    required this.account,
    required this.publicKey,
    required this.collection,
    this.loginUser = 'ubuntu',
    this.distribution = 'snapshots',
    this.tresor,
    this.vpnPeerPublicKey,
    this.vpnPeerAddress,
  });

  /// The project's name: the host's name, and the tag it is found by.
  final String project;

  /// The account the first play makes, which runs Porelo.
  final String account;

  /// The person's public key, which logs in as [loginUser] and then as [account].
  final String publicKey;

  /// The collection's tarball on this computer.
  final String collection;

  /// The image's own user with sudo, which the first steps run as.
  final String loginUser;

  /// Where Porelo's package comes from: `releases` or `snapshots`. `snapshots` until a release of
  /// Porelo carries `vault status`, which the host's plays ask; 0.5.0 has none.
  final String distribution;

  /// The drive's tresor the host syncs.
  final String? tresor;

  /// The person's WireGuard peer: a public key, never a secret.
  final String? vpnPeerPublicKey;

  /// The person's WireGuard peer's address.
  final String? vpnPeerAddress;

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
  });

  /// Who rents the host.
  final HostProvider provider;

  /// How commands reach it.
  final Remote remote;

  /// Where each step's line goes.
  final void Function(Step step) emit;

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

  /// Brings [plan]'s host up, as far as it can go. A second call with [answers] goes on after the stop.
  Future<int> up(HostPlan plan, {Answers answers = const Answers()}) async {
    final RentedHost? host;
    try {
      host = await _rented(plan);
    } on ProviderFailed catch (e) {
      // The provider's own sentence, as a refused step and 65: the person fixes it, not the code.
      emit(Step('rent', StepState.refused, fix: e.message));
      return Exit.refused;
    }
    if (host == null) return Exit.unreachable;
    final address = host.address!;

    emit(const Step('copy', StepState.started));
    final inventory = _inventory(plan);
    final copied = await remote.run(
      address,
      plan.loginUser,
      'mkdir -p $_workdir && cat > $_workdir/inventory.yml',
      input: inventory,
    );
    if (copied.exitCode != 0) return _refused('copy', copied, 'the host refused the inventory');
    final tarball = await remote.copy(address, plan.loginUser, plan.collection, '$_workdir/collection.tar.gz');
    if (tarball.exitCode != 0) return _refused('copy', tarball, 'the collection could not be copied');
    emit(const Step('copy', StepState.done));

    emit(const Step('ansible', StepState.started));
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
    emit(const Step('ansible', StepState.done));

    if (answers.any) {
      final given = await _answer(address, plan, answers);
      if (given != null) return given;
    }
    final played = await _play(address, plan, 'porelo.host.up');
    if (played != Exit.done) return played;
    final lines = <String>[];
    final uid = await remote.run(address, plan.account, 'id -u', onLine: lines.add);
    if (uid.exitCode != 0) return _refused('up', uid, 'the account uid could not be read');
    if (lines.length != 1 || !RegExp(r'^[0-9]+$').hasMatch(lines.single)) {
      return _refused('up', uid, 'id -u must return one uid containing only digits');
    }
    emit(
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
  Future<int> down(HostPlan plan, {bool giveBackAnyway = false}) async {
    try {
      return await _down(plan, giveBackAnyway);
    } on ProviderFailed catch (e) {
      emit(Step('give-back', StepState.refused, fix: e.message));
      return Exit.refused;
    }
  }

  Future<int> _down(HostPlan plan, bool giveBackAnyway) async {
    final host = await provider.find(plan.tag);
    if (host == null) {
      emit(const Step('give-back', StepState.done, words: 'no host carries the project tag'));
      return Exit.done;
    }
    final address = host.address;
    final played = address == null
        ? _unreachable('play', 'the provider names no address for ${host.id}')
        : await _play(address, plan, 'porelo.host.down');
    if (played != Exit.done && !giveBackAnyway) {
      emit(
        Step(
          'give-back',
          StepState.refused,
          words: '${host.id} is kept and still billed, since its down play did not finish',
          fix: "run 'down' again, or 'down --give-back-anyway' to give it back knowingly",
        ),
      );
      return played;
    }
    emit(const Step('give-back', StepState.started));
    await provider.release(host.id);
    emit(
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
    emit(const Step('rent', StepState.started));
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
    emit(const Step('rent', StepState.done));

    emit(const Step('ssh', StepState.started));
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
    emit(const Step('ssh', StepState.done));
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

  /// The person's answers, each on the standard input of its own command as [HostPlan.account].
  /// Null when all went in, else how `up` ends.
  Future<int?> _answer(String address, HostPlan plan, Answers answers) async {
    if (answers.drivePassword != null) {
      emit(const Step('drive', StepState.started));
      final login = await remote.run(
        address,
        plan.account,
        // The account's own runtime directory, where its Tresorit daemon listens, set here rather
        // than trusted to the ssh session, which may not give a command one.
        'XDG_RUNTIME_DIR=/run/user/\$(id -u) tresorit-cli login --email ${_quoted(answers.driveEmail ?? '')} --password-on-stdin',
        // The one-time code is the line after the password: the client asks for it itself and
        // reads it from the same standard input (measured on Tresorit 3.5.1300.4870).
        input: '${answers.drivePassword}\n${answers.driveCode == null ? '' : '${answers.driveCode}\n'}',
      );
      if (login.exitCode != 0) return _refused('drive', login, 'the drive refused the login');
      emit(const Step('drive', StepState.done));
    }
    if (answers.vaultPassphrase != null) {
      emit(const Step('vault', StepState.started));
      final opened = await remote.run(
        address,
        plan.account,
        // `vault status` says 4 when there is none yet, so the same answer makes it or opens it. The
        // account's runtime directory is set here, as for the drive, where its daemon listens.
        'export XDG_RUNTIME_DIR=/run/user/\$(id -u); '
        'if porelo vault status >/dev/null 2>&1; [ \$? -eq 4 ]; then porelo vault init --passphrase-stdin; '
        'else porelo vault unlock --passphrase-stdin; fi',
        input: '${answers.vaultPassphrase}\n',
      );
      if (opened.exitCode != 0) return _refused('vault', opened, 'the vault was not opened');
      emit(const Step('vault', StepState.done));
    }
    return null;
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
        final step = _relayed(line);
        if (step == null) return;
        if (step.state == StepState.waiting) waiting = step;
        if (step.state == StepState.refused) failed = step;
        emit(step);
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
  Step? _relayed(String line) {
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?> || decoded['v'] != 1) return null;
    final state = decoded['state'];
    final words = decoded['msg'] as String?;
    if (state == 'waiting') {
      final needs = (decoded['needs'] as List<Object?>? ?? const <Object?>[]).whereType<String>().toList();
      return Step('person', StepState.waiting, needs: needs, words: words);
    }
    final name = decoded['task'] as String? ?? decoded['play'] as String? ?? 'play';
    return switch (state) {
      'started' => Step(name, StepState.started),
      'ok' || 'changed' || 'skipped' => Step(name, StepState.done),
      'failed' => Step(name, StepState.refused, fix: words, words: words),
      _ => null,
    };
  }

  static bool _keyRefused(RemoteResult result) => result.stderr.contains('Host key verification failed');

  int _refused(String step, RemoteResult result, String fix) {
    emit(Step(step, StepState.refused, fix: fix, words: result.stderr.isEmpty ? null : result.stderr));
    return Exit.refused;
  }

  int _unreachable(String step, String words) {
    emit(Step(step, StepState.refused, fix: 'the provider or the host could not be reached', words: words));
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
        'porelo_host_tresor': ?plan.tresor,
        'porelo_host_vpn_peer_public_key': ?plan.vpnPeerPublicKey,
        'porelo_host_vpn_peer_address': ?plan.vpnPeerAddress,
      },
    },
  });
}

/// [word] as one word for a POSIX shell.
String _quoted(String word) => "'${word.replaceAll("'", r"'\''")}'";
