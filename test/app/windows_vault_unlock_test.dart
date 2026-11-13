import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' show Ed25519, SimpleKeyPair;
import 'package:flutter/foundation.dart' show debugPrint, DebugPrintCallback, listEquals;
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/windows_vault_unlock.dart';
import 'package:porelo_host/porelo_host.dart' show HostCardSsh;

/// Core's written vector for a host vault share: a key made for the vector alone, never a person's.
const _seed = '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f';
const _publicBlob =
    '0000000b7373682d656432353531390000002003a107bff3ce10be1d70dd18e74bc09967e4d6309ba50d5f1ddc8664125531b8';
const _host = 'SHA256:uNiVztksCsDhcc0u9e8BujQXVUpKZIDTMczCvj3tD2s';
const _login = 'builder';
const _signedData =
    '5353485349470000000c706f72656c6f2d7661756c7400000000000000067368613531320000004036cf1f788a6a3b380949fa3701cee14fd2'
    '26413ff3e67937acc3ef65b730ea44a8ded47c8f49cbc18bd770cc0ec615d8bd73bacd56a92cc96faf2602671a7d95';
const _signatureBlob =
    '53534853494700000001000000330000000b7373682d656432353531390000002003a107bff3ce10be1d70dd18e74bc09967e4d6309ba50d5f'
    '1ddc8664125531b80000000c706f72656c6f2d7661756c740000000000000006736861353132000000530000000b7373682d6564323535313900'
    '0000404727d4497aa83f483deec835366b10e242bb4cf6a83f47e1a6fde736bedfb8a2477fc0ace6b453af545df15b2d9ecc1d302b2c018d575'
    '6ac61acb27cad5fa80a';
const _share = 'f894c8fd19308ab206813eb64af1b821653623f006e6a4b95e3bd3d5d8843828';

const _appData = r'C:\Users\person\AppData\Roaming';
const _config = r'C:\Users\person\AppData\Roaming\porelo\ssh\alpha.conf';

void main() {
  late Desk before;
  setUp(() {
    before = desk;
    desk = Desk.of('windows', const {'APPDATA': _appData});
  });
  tearDown(() => desk = before);

  // Harm: a share other than Core's opens no host vault, or opens one with a share Core would not make.
  test('the share is derived by Core\'s written rule, byte for byte its vector', () async {
    final agent = await _Agent.of(_seed);

    final blob = await signVaultShare(AgentProtocolClient(agent.exchange), agent.blob, _host, _login);

    expect(_hex(agent.blob), _publicBlob);
    expect(agent.signed.map(_hex), [_signedData]);
    expect(_hex(blob), _signatureBlob);
    expect(_hex(vaultShareFromBlob(blob)), _share);
    expect(_hex(await deriveVaultShare(AgentProtocolClient(agent.exchange), agent.blob, _host, _login)), _share);
  });

  // Harm: a signature the key never made, from an agent that lies, becomes an opening share.
  test('a signature that does not verify against the key derives no share', () async {
    final agent = await _Agent.of(_seed)
      ..forges = true;

    await expectLater(
      deriveVaultShare(AgentProtocolClient(agent.exchange), agent.blob, _host, _login),
      throwsA(isA<VaultShareRefused>()),
    );
  });

  group('on Windows', () {
    late _Agent agent;
    late _Host host;
    late String hostKey;

    setUp(() async {
      agent = await _Agent.of(_seed);
      final hostPair = await Ed25519().newKeyPairFromSeed(List.filled(32, 7));
      hostKey = 'ssh-ed25519 ${base64Encode(_ed25519Blob((await hostPair.extractPublicKey()).bytes))}';
      host = _Host(scanned: hostKey);
    });

    HostCardSsh card() => HostCardSsh(
      name: 'alpha',
      address: '203.0.113.7',
      sshPort: 2222,
      hostKey: hostKey,
      login: _login,
      publicKey: 'ssh-ed25519 ${base64Encode(agent.blob)}',
    );

    WindowsHostUnlocker unlocker({Future<bool> Function(HostCardSsh)? askToClear}) => WindowsHostUnlocker(
      start: host.start,
      agent: AgentProtocolClient(agent.exchange),
      askToClear: askToClear,
      environment: const {'APPDATA': _appData},
      windows: true,
    );

    Future<Uint8List> expectedShare() async => deriveVaultShare(
      AgentProtocolClient((await _Agent.of(_seed)).exchange),
      agent.blob,
      sshFingerprint(hostKey),
      _login,
    );

    // Harm: the share signed for a host the window never checked, sent to whatever answers at the card's address.
    test('a host whose scanned key is not the card\'s pin is asked nothing', () async {
      final other = await Ed25519().newKeyPairFromSeed(List.filled(32, 9));
      host = _Host(scanned: 'ssh-ed25519 ${base64Encode(_ed25519Blob((await other.extractPublicKey()).bytes))}');

      final result = await unlocker().unlock(card(), _config);

      expect(result.state, HostUnlockState.refused);
      expect(host.verbs, isEmpty);
      expect(agent.asked, 0);
      expect(host.commands.single, containsAllInOrder(['-p', '2222', '--', '203.0.113.7']));
    });

    // Harm: each answer of the host read as another, so a refused vault reads open or a closed one is cleared.
    for (final (code, line, state, more) in [
      (0, '{"vault":"open"}', HostUnlockState.unlocked, <String>[]),
      (65, '{"vault":"not-a-host-vault"}', HostUnlockState.refused, <String>[]),
      (77, '{"vault":"other-key"}', HostUnlockState.otherKey, <String>[]),
      (70, '', HostUnlockState.refused, <String>[]),
      (0, '{"vault":"absent"}', HostUnlockState.refused, <String>[]),
      (66, '{"vault":"absent"}', HostUnlockState.unlocked, <String>['init']),
    ]) {
      test('an unlock answering $code $line reads $state', () async {
        host.answers['unlock'] = (code, line);

        final result = await unlocker().unlock(card(), _config);

        expect(result.state, state);
        if (state != HostUnlockState.unlocked) expect(result.words, isNotEmpty);
        expect(host.verbs, ['unlock', ...more]);
      });
    }

    test('each refusal has its own words', () async {
      final words = <String?>{};
      for (final (code, line) in [(65, '{"vault":"not-a-host-vault"}'), (77, '{"vault":"other-key"}'), (70, '')]) {
        host.answers['unlock'] = (code, line);
        words.add((await unlocker().unlock(card(), _config)).words);
      }
      expect(words, hasLength(3));
    });

    // Harm: a vault opened by another key, and every credential in it, cleared without the person's yes.
    test('a vault opened by another key is cleared only after the person\'s yes', () async {
      host.answers['unlock'] = (77, '{"vault":"other-key"}');
      final asked = <String>[];

      final kept = await unlocker(
        askToClear: (card) async {
          asked.add(card.name);
          return false;
        },
      ).unlock(card(), _config);

      expect(kept.state, HostUnlockState.otherKey);
      expect(asked, ['alpha']);
      expect(host.verbs, ['unlock']);

      host.verbs.clear();
      final made = await unlocker(askToClear: (_) async => true).unlock(card(), _config);

      expect(made.state, HostUnlockState.unlocked);
      expect(host.verbs, ['unlock', 'clear', 'init']);
    });

    // Harm: the opening share in an argument list or a log line, where any process or reader of the log sees it.
    test('the share travels only on standard input, exactly its 32 bytes', () async {
      host.answers['unlock'] = (66, '{"vault":"absent"}');
      final printed = <String>[];
      final DebugPrintCallback wasPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) => printed.add('$message');
      try {
        await runZoned(
          () => unlocker().unlock(card(), _config),
          zoneSpecification: ZoneSpecification(print: (_, _, _, line) => printed.add(line)),
        );
      } finally {
        debugPrint = wasPrint;
      }
      final share = await expectedShare();

      expect(host.inputs['unlock'], share);
      expect(host.inputs['init'], share);
      for (final form in [_hex(share), base64Encode(share), base64Encode(share).replaceAll('=', '')]) {
        expect(host.commands.expand((command) => command).where((argument) => argument.contains(form)), isEmpty);
        expect(printed.where((line) => line.contains(form)), isEmpty);
      }
      for (final command in host.commands.skip(1)) {
        expect(command, containsAllInOrder(['-F', _config, '-T', '--', 'alpha']));
      }
    });

    // Harm: the old key's share sent in the new one's place, which locks the person out of their own vault.
    test('a rekey sends the old share, then the new, and nothing else', () async {
      final previous = await _Agent.of('1f1e1d1c1b1a191817161514131211100f0e0d0c0b0a09080706050403020100');
      agent.others.add(previous);
      host.answers['rekey'] = (0, '{"vault":"open"}');

      final result = await unlocker().rekey(card(), _config, previousKey: 'ssh-ed25519 ${base64Encode(previous.blob)}');

      expect(result.state, HostUnlockState.unlocked);
      final old = await deriveVaultShare(
        AgentProtocolClient(previous.exchange),
        previous.blob,
        sshFingerprint(hostKey),
        _login,
      );
      expect(host.inputs['rekey'], [...old, ...await expectedShare()]);
    });

    // Harm: a share asked of a key the agent does not hold, or a vault step run without one.
    test('without the card\'s key in the agent the card waits for it', () async {
      agent.holds = false;

      final result = await unlocker().unlock(card(), _config);

      expect(result.state, HostUnlockState.waitingForKey);
      expect(host.verbs, isEmpty);
    });
  });

  // Harm: on Windows the vault stays shut, since Core's unlock does not run there.
  test('Windows takes the window\'s own unlocker, Linux keeps Core\'s', () {
    expect(hostUnlockerHere(environment: const {'APPDATA': _appData}), isA<WindowsHostUnlocker>());
    desk = Desk.of('linux', const {'HOME': '/home/person'});
    expect(hostUnlockerHere(), isA<CoreHostUnlocker>());
  });
}

String _hex(List<int> bytes) => bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

List<int> _unhex(String text) => [
  for (var i = 0; i < text.length; i += 2) int.parse(text.substring(i, i + 2), radix: 16),
];

Uint8List _ed25519Blob(List<int> key) =>
    Uint8List.fromList([...sshString(ascii.encode('ssh-ed25519')), ...sshString(key)]);

/// An ssh agent speaking the agent protocol, holding the key of one seed and any [others].
class _Agent {
  _Agent._(this._pair, this.blob);

  static Future<_Agent> of(String seed) async {
    final pair = await Ed25519().newKeyPairFromSeed(_unhex(seed));
    final public = await pair.extractPublicKey();
    return _Agent._(pair, _ed25519Blob(public.bytes));
  }

  final SimpleKeyPair _pair;
  final Uint8List blob;
  final others = <_Agent>[];
  final signed = <Uint8List>[];
  bool holds = true;
  bool forges = false;
  int asked = 0;

  Future<Uint8List> exchange(Uint8List frame) async {
    asked++;
    final data = ByteData.sublistView(frame);
    expect(data.getUint32(0), frame.length - 4);
    final type = frame[4];
    if (type == 11) {
      final keys = [if (holds) blob, for (final other in others) other.blob];
      return Uint8List.fromList([
        12,
        ..._uint32(keys.length),
        for (final key in keys) ...[...sshString(key), ...sshString(utf8.encode('person'))],
      ]);
    }
    expect(type, 13);
    var at = 5;
    Uint8List next() {
      final length = data.getUint32(at);
      final value = frame.sublist(at + 4, at + 4 + length);
      at += 4 + length;
      return value;
    }

    final key = next();
    final toSign = next();
    expect(data.getUint32(at), 0);
    final signer = [this, ...others].firstWhere((agent) => listEquals(agent.blob, key));
    signer.signed.add(toSign);
    final signature = await Ed25519().sign(forges ? [...toSign, 0] : toSign, keyPair: signer._pair);
    return Uint8List.fromList([
      14,
      ...sshString([...sshString(ascii.encode('ssh-ed25519')), ...sshString(signature.bytes)]),
    ]);
  }

  static List<int> _uint32(int value) => (ByteData(4)..setUint32(0, value)).buffer.asUint8List();
}

/// The host's ssh and ssh-keyscan: the scan answers [scanned]; each vault step answers as it is told, and what it
/// read on standard input is kept by its verb.
class _Host {
  _Host({required this.scanned});

  final String scanned;
  final commands = <List<String>>[];
  final verbs = <String>[];
  final inputs = <String, List<int>>{};
  final answers = <String, (int, String)>{
    'unlock': (0, '{"vault":"open"}'),
    'init': (0, '{"vault":"open"}'),
    'clear': (0, '{"items":[],"refused":false,"kept":""}'),
  };

  Future<Process> start(List<String> command) async {
    commands.add(command);
    if (command.first.endsWith('ssh-keyscan') || command.first.endsWith('ssh-keyscan.exe')) {
      return _Ran(0, '# 203.0.113.7:2222 SSH-2.0-OpenSSH\n[203.0.113.7]:2222 $scanned\n', (_) {});
    }
    final verb = RegExp(r'porelo vault (\w+)').firstMatch(command.last)!.group(1)!;
    verbs.add(verb);
    final (code, line) = answers[verb] ?? (70, '');
    return _Ran(code, line.isEmpty ? '' : '$line\n', (input) => inputs[verb] = input);
  }
}

class _Ran implements Process {
  _Ran(this._code, String out, void Function(List<int>) read) : stdin = IOSink(_Read(read)) {
    stdout = Stream.value(utf8.encode(out));
  }

  final int _code;

  @override
  late final Stream<List<int>> stdout;

  @override
  final Stream<List<int>> stderr = const Stream.empty();

  @override
  final IOSink stdin;

  @override
  Future<int> get exitCode async => _code;

  @override
  int get pid => 1;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;
}

class _Read implements StreamConsumer<List<int>> {
  _Read(this._read);

  final void Function(List<int>) _read;
  final _all = <int>[];

  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.forEach(_all.addAll);

  @override
  Future<void> close() async => _read(_all);
}
