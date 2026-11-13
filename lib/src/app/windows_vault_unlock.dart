import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show Hmac, sha256, sha512;
import 'package:cryptography/cryptography.dart' show Ed25519, KeyPairType, Signature, SimplePublicKey;
import 'package:porelo_host/porelo_host.dart' show HostCardSsh, HostFilesRefused, inTheLoginShell;

import 'fleet_backend.dart' show CoreHostUnlocker, HostUnlockResult, HostUnlockState, HostUnlocker;
import 'desk.dart' show desk;
import 'machines.dart' show openSsh;
import 'owned_process.dart';

/// The unlocker of this computer: the window's own on Windows, where Core's `host unlock` does not run, Core's
/// elsewhere.
HostUnlocker hostUnlockerHere({Map<String, String>? environment}) =>
    desk.isWindows ? WindowsHostUnlocker(environment: environment) : CoreHostUnlocker(environment: environment);

/// Why a host vault share was not derived: the agent's answer, the key or the inputs were not what the rule needs.
class VaultShareRefused implements Exception {
  /// Carries the public reason, never key material.
  const VaultShareRefused(this.message);

  /// The reason, safe to show.
  final String message;

  @override
  String toString() => message;
}

/// The ssh agent could not be reached, so the person's key is not there for now.
class SshAgentAbsent implements Exception {
  /// Carries the public reason.
  const SshAgentAbsent(this.message);

  /// The reason, safe to show.
  final String message;

  @override
  String toString() => message;
}

/// What the window asks of the person's ssh agent: the keys it holds and a signature by one of them.
abstract interface class SshAgent {
  /// The public key blobs the agent holds.
  Future<List<Uint8List>> keys();

  /// The agent's signature of [data] by the key whose public blob is [key], as the agent protocol returns it.
  Future<Uint8List> sign(Uint8List key, Uint8List data);
}

/// One request to the agent and its reply's body (its type byte and contents), the frame's length taken off.
typedef AgentExchange = Future<Uint8List> Function(Uint8List frame);

/// The ssh agent protocol, one exchange per request.
class AgentProtocolClient implements SshAgent {
  /// Speaks over [exchange]; the Windows OpenSSH agent's named pipe when none is given.
  AgentProtocolClient([AgentExchange? exchange]) : _exchange = exchange ?? windowsAgentPipe;

  final AgentExchange _exchange;

  static const _failure = 5;
  static const _requestIdentities = 11;
  static const _identitiesAnswer = 12;
  static const _signRequest = 13;
  static const _signResponse = 14;

  @override
  Future<List<Uint8List>> keys() async {
    final reply = _Reader(await _exchange(_frame(_requestIdentities, const [])));
    if (reply.byte() != _identitiesAnswer) throw const SshAgentAbsent('The ssh agent did not list its keys.');
    final count = reply.uint32();
    if (count > 1024) throw const SshAgentAbsent('The ssh agent listed more keys than it can hold.');
    final keys = <Uint8List>[];
    for (var i = 0; i < count; i++) {
      keys.add(reply.string());
      reply.string();
    }
    reply.end();
    return keys;
  }

  @override
  Future<Uint8List> sign(Uint8List key, Uint8List data) async {
    final body = BytesBuilder()
      ..add(sshString(key))
      ..add(sshString(data))
      ..add(_uint32(0));
    final answer = await _exchange(_frame(_signRequest, body.takeBytes()));
    try {
      final reply = _Reader(answer);
      final type = reply.byte();
      if (type == _failure) throw const VaultShareRefused('Your ssh agent refused to sign for the machine vault.');
      if (type != _signResponse) throw const VaultShareRefused('Your ssh agent answered the signing unreadably.');
      final signature = reply.string();
      reply.end();
      return signature;
    } finally {
      answer.fillRange(0, answer.length, 0);
    }
  }

  static Uint8List _frame(int type, List<int> body) {
    final frame = BytesBuilder()
      ..add(_uint32(body.length + 1))
      ..addByte(type)
      ..add(body);
    return frame.takeBytes();
  }
}

/// The SSHSIG namespace a host vault's share is signed in.
const vaultShareNamespace = 'porelo-vault';

/// The text the person's key signs for [hostFingerprint] and [login]; a changed host key or login signs another.
Uint8List vaultShareText(String hostFingerprint, String login) {
  // Checked, not trusted: a space in either would let two different pairs sign the same text.
  if (!RegExp(r'^SHA256:[A-Za-z0-9+/]{43}$').hasMatch(hostFingerprint) ||
      !RegExp(r'^[a-z][a-z0-9-]{0,31}$').hasMatch(login)) {
    throw const VaultShareRefused('A machine vault share needs a host key fingerprint and a login.');
  }
  return Uint8List.fromList(utf8.encode('host=$hostFingerprint account=$login'));
}

/// The bytes an SSHSIG signature in [vaultShareNamespace] signs over [text]: its preimage, not the text itself.
Uint8List sshsigSignedData(Uint8List text) {
  final data = BytesBuilder()
    ..add(ascii.encode('SSHSIG'))
    ..add(sshString(utf8.encode(vaultShareNamespace)))
    ..add(sshString(const []))
    ..add(sshString(ascii.encode('sha512')))
    ..add(sshString(sha512.convert(text).bytes));
  return data.takeBytes();
}

/// Asks [agent] to sign the share's text for [hostFingerprint] and [login] with the Ed25519 key [key], verifies the
/// signature against that key and answers the binary SSHSIG blob the share is derived from.
///
/// The blob is the share's input; the caller clears it once the share is taken.
Future<Uint8List> signVaultShare(SshAgent agent, Uint8List key, String hostFingerprint, String login) async {
  final public = _ed25519PublicKey(key);
  final signedData = sshsigSignedData(vaultShareText(hostFingerprint, login));
  final signature = await agent.sign(key, signedData);
  try {
    final reader = _Reader(signature);
    final String algorithm;
    final Uint8List raw;
    try {
      algorithm = ascii.decode(reader.string(), allowInvalid: true);
      raw = reader.string();
      reader.end();
    } on SshAgentAbsent {
      throw const VaultShareRefused('Your ssh agent answered the signing unreadably.');
    }
    if (algorithm != 'ssh-ed25519' || raw.length != 64) {
      throw const VaultShareRefused('Your ssh agent signed with another kind of key.');
    }
    // An agent's signature must verify before it can produce an opening share.
    final good = await Ed25519().verify(
      signedData,
      signature: Signature(raw, publicKey: SimplePublicKey(public, type: KeyPairType.ed25519)),
    );
    raw.fillRange(0, raw.length, 0);
    if (!good) throw const VaultShareRefused('Your ssh agent\'s signature does not verify against your key.');
    final blob = BytesBuilder()
      ..add(ascii.encode('SSHSIG'))
      ..add(_uint32(1))
      ..add(sshString(key))
      ..add(sshString(utf8.encode(vaultShareNamespace)))
      ..add(sshString(const []))
      ..add(sshString(ascii.encode('sha512')))
      ..add(sshString(signature));
    return blob.takeBytes();
  } finally {
    signature.fillRange(0, signature.length, 0);
  }
}

/// The 32-byte share from an SSHSIG [blob]: HKDF-SHA256 with the whole blob as input key material, an empty salt and
/// the info `porelo-vault-share-v1`.
Uint8List vaultShareFromBlob(Uint8List blob) {
  // An empty salt is HMAC's key of zero bytes, which HMAC pads to the same block as SHA-256's length of zeros.
  final pseudoRandom = Hmac(sha256, const []).convert(blob).bytes;
  final expanded = Hmac(sha256, pseudoRandom).convert([...utf8.encode('porelo-vault-share-v1'), 1]).bytes;
  pseudoRandom.fillRange(0, pseudoRandom.length, 0);
  return Uint8List.fromList(expanded.sublist(0, 32));
}

/// The share [agent]'s key [key] opens [login]'s vault on the host with key [hostFingerprint] by.
Future<Uint8List> deriveVaultShare(SshAgent agent, Uint8List key, String hostFingerprint, String login) async {
  final blob = await signVaultShare(agent, key, hostFingerprint, login);
  try {
    return vaultShareFromBlob(blob);
  } finally {
    blob.fillRange(0, blob.length, 0);
  }
}

/// The public blob of an `ssh-ed25519 <base64>` line.
Uint8List publicKeyBlob(String line) {
  final fields = line.trim().split(RegExp(r'\s+'));
  if (fields.length < 2) throw const VaultShareRefused('The card names no public key.');
  try {
    return base64Decode(fields[1]);
  } on FormatException {
    throw const VaultShareRefused('The card names an unreadable public key.');
  }
}

/// The `SHA256:` fingerprint of an `ssh-<type> <base64>` line, as `ssh-keygen -l` names it.
String sshFingerprint(String line) =>
    'SHA256:${base64Encode(sha256.convert(publicKeyBlob(line)).bytes).replaceAll('=', '')}';

/// The 32 key bytes of an `ssh-ed25519` public blob; any other blob is refused.
Uint8List _ed25519PublicKey(Uint8List blob) {
  try {
    final reader = _Reader(blob);
    final algorithm = ascii.decode(reader.string(), allowInvalid: true);
    final key = reader.string();
    reader.end();
    if (algorithm == 'ssh-ed25519' && key.length == 32) return key;
  } on SshAgentAbsent {
    // Read as any other blob that is no Ed25519 key.
  }
  throw const VaultShareRefused('A machine vault is opened only with an Ed25519 key.');
}

/// An ssh string: its length as four big-endian bytes, then the bytes.
Uint8List sshString(List<int> bytes) =>
    (BytesBuilder()
          ..add(_uint32(bytes.length))
          ..add(bytes))
        .takeBytes();

Uint8List _uint32(int value) => Uint8List(4)..buffer.asByteData().setUint32(0, value);

/// Reads an agent's answer, every length checked against what is there.
class _Reader {
  _Reader(this._bytes);

  final Uint8List _bytes;
  int _at = 0;

  int byte() {
    _need(1);
    return _bytes[_at++];
  }

  int uint32() {
    _need(4);
    final value = _bytes.buffer.asByteData(_bytes.offsetInBytes).getUint32(_at);
    _at += 4;
    return value;
  }

  Uint8List string() {
    final length = uint32();
    _need(length);
    final value = Uint8List.fromList(_bytes.sublist(_at, _at + length));
    _at += length;
    return value;
  }

  void end() {
    if (_at != _bytes.length) throw const SshAgentAbsent('The ssh agent answered more than it was asked.');
  }

  void _need(int count) {
    if (_at + count > _bytes.length) throw const SshAgentAbsent('The ssh agent answered too little.');
  }
}

/// The Windows OpenSSH agent's named pipe, which KeePassXC's keys are added to.
const windowsAgentPipePath = r'\\.\pipe\openssh-ssh-agent';

/// One exchange with the Windows OpenSSH agent over its named pipe, in an isolate of its own, since the pipe's reads
/// block.
Future<Uint8List> windowsAgentPipe(Uint8List frame) async {
  Uint8List? answer;
  try {
    answer = await Isolate.run(() => _pipeExchange(frame));
  } on Object {
    // No kernel32 or no pipe to open is no agent, never an unlock that throws.
    answer = null;
  }
  if (answer == null) throw const SshAgentAbsent('The Windows ssh agent does not answer.');
  return answer;
}

/// The most an agent's reply may hold; a reply with no end is no answer.
const _mostReplyBytes = 256 * 1024;

Uint8List? _pipeExchange(Uint8List frame) {
  final k = DynamicLibrary.open('kernel32.dll');
  final createFile = k
      .lookupFunction<
        IntPtr Function(Pointer<Uint16>, Uint32, Uint32, Pointer<Void>, Uint32, Uint32, IntPtr),
        int Function(Pointer<Uint16>, int, int, Pointer<Void>, int, int, int)
      >('CreateFileW');
  final readFile = k
      .lookupFunction<
        Int32 Function(IntPtr, Pointer<Uint8>, Uint32, Pointer<Uint32>, Pointer<Void>),
        int Function(int, Pointer<Uint8>, int, Pointer<Uint32>, Pointer<Void>)
      >('ReadFile');
  final writeFile = k
      .lookupFunction<
        Int32 Function(IntPtr, Pointer<Uint8>, Uint32, Pointer<Uint32>, Pointer<Void>),
        int Function(int, Pointer<Uint8>, int, Pointer<Uint32>, Pointer<Void>)
      >('WriteFile');
  final closeHandle = k.lookupFunction<Int32 Function(IntPtr), int Function(int)>('CloseHandle');
  final heap = k.lookupFunction<IntPtr Function(), int Function()>('GetProcessHeap')();
  final heapAlloc = k
      .lookupFunction<Pointer<Void> Function(IntPtr, Uint32, IntPtr), Pointer<Void> Function(int, int, int)>(
        'HeapAlloc',
      );
  final heapFree = k
      .lookupFunction<Int32 Function(IntPtr, Uint32, Pointer<Void>), int Function(int, int, Pointer<Void>)>('HeapFree');
  const zeroMemory = 0x00000008;
  final name = heapAlloc(heap, zeroMemory, (windowsAgentPipePath.length + 1) * 2).cast<Uint16>();
  final buffer = heapAlloc(heap, zeroMemory, _mostReplyBytes).cast<Uint8>();
  final done = heapAlloc(heap, zeroMemory, 4).cast<Uint32>();
  try {
    if (name.address == 0 || buffer.address == 0 || done.address == 0) return null;
    name.asTypedList(windowsAgentPipePath.length).setAll(0, windowsAgentPipePath.codeUnits);
    const genericReadWrite = 0x80000000 | 0x40000000;
    const openExisting = 3;
    final pipe = createFile(name, genericReadWrite, 0, nullptr, openExisting, 0, 0);
    if (pipe == -1 || pipe == 0) return null;
    try {
      buffer.asTypedList(frame.length).setAll(0, frame);
      for (var sent = 0; sent < frame.length; sent += done.value) {
        if (writeFile(pipe, buffer + sent, frame.length - sent, done, nullptr) == 0 || done.value == 0) return null;
      }
      bool readExactly(int count) {
        for (var got = 0; got < count; got += done.value) {
          if (readFile(pipe, buffer + got, count - got, done, nullptr) == 0 || done.value == 0) return false;
        }
        return true;
      }

      if (!readExactly(4)) return null;
      final length = buffer.asTypedList(4).buffer.asByteData(buffer.asTypedList(4).offsetInBytes).getUint32(0);
      if (length == 0 || length > _mostReplyBytes || !readExactly(length)) return null;
      return Uint8List.fromList(buffer.asTypedList(length));
    } finally {
      closeHandle(pipe);
    }
  } finally {
    // The reply may hold a signature; it is cleared before the heap takes it back.
    if (buffer.address != 0) buffer.asTypedList(_mostReplyBytes).fillRange(0, _mostReplyBytes, 0);
    for (final block in [name.cast<Void>(), buffer.cast<Void>(), done.cast<Void>()]) {
      if (block.address != 0) heapFree(heap, 0, block);
    }
  }
}

/// What one step on the host answered: its exit and its one JSON line, read.
typedef _HostAnswer = ({int code, Map<String, Object?>? line});

/// Opens a host's vault on Windows, where Core's `host unlock` does not run: the window checks the host key against the
/// card's pin, derives the share with the person's key in the Windows ssh agent, and runs Porelo's vault commands on
/// the host through the card's own ssh config, the share only on their standard input.
class WindowsHostUnlocker implements HostUnlocker {
  /// Accepts a process boundary, an agent and the person's yes for tests; [askToClear] is asked before a vault opened
  /// by another key is cleared, and without it such a vault is only kept.
  WindowsHostUnlocker({
    Future<Process> Function(List<String>)? start,
    SshAgent? agent,
    this.askToClear,
    this.deadline = const Duration(seconds: 30),
    this.environment,
    bool? windows,
  }) : _start = start ?? _startHere,
       _agent = agent ?? AgentProtocolClient(),
       _windows = windows ?? desk.isWindows;

  /// The person's yes to clearing [HostCardSsh]'s vault, which another key opened, and making it anew with theirs.
  final Future<bool> Function(HostCardSsh card)? askToClear;

  /// The bound on each step on the host before its process is ended.
  final Duration deadline;

  /// The platform config environment shared with host publication.
  final Map<String, String>? environment;

  final Future<Process> Function(List<String>) _start;
  final SshAgent _agent;
  final bool _windows;
  final Map<String, Set<Process>> _children = {};
  final Map<String, Future<HostUnlockResult>> _pending = {};
  final Map<String, int> _generations = {};

  static Future<Process> _startHere(List<String> command) => Process.start(command.first, command.sublist(1));

  static const _cancelled = HostUnlockResult(HostUnlockState.refused, 'Machine unlock was cancelled.');

  @override
  Future<HostUnlockResult> unlock(HostCardSsh card, String config) => _pending.putIfAbsent(
    card.name,
    // A block, not an arrow: whenComplete waits for a returned future, and the one removed is this one.
    () => _guarded(card, config, _unlock).whenComplete(() {
      _pending.remove(card.name);
    }),
  );

  /// Gives [card]'s vault the card's key in place of [previousKey], which still opens it: both shares go to the host's
  /// `vault rekey`, the old one first.
  Future<HostUnlockResult> rekey(HostCardSsh card, String config, {required String previousKey}) =>
      _guarded(card, config, (run) => _rekey(run, previousKey));

  Future<HostUnlockResult> _guarded(
    HostCardSsh card,
    String config,
    Future<HostUnlockResult> Function(_Run run) steps,
  ) async {
    final run = _Run(card, config, _generations[card.name] ?? 0);
    try {
      HostCardSsh.checkConfigPath(card.name, config, environment: environment, windows: _windows);
      final pinned = sshFingerprint(card.hostKey);
      if (!await _hostKeyMatches(run, pinned)) {
        return HostUnlockResult(
          HostUnlockState.refused,
          'The machine at ${card.address} offered another host key than its card pins; its vault was not asked.',
        );
      }
      return await steps(run);
    } on TimeoutException {
      return const HostUnlockResult(HostUnlockState.refused, 'The machine did not answer its vault in time.');
    } on ProcessException {
      return const HostUnlockResult(HostUnlockState.unsupported, 'ssh is not available on this computer.');
    } on HostFilesRefused catch (refused) {
      return HostUnlockResult(HostUnlockState.refused, refused.message);
    } on SshAgentAbsent {
      return const HostUnlockResult(HostUnlockState.waitingForKey);
    } on VaultShareRefused catch (refused) {
      return HostUnlockResult(HostUnlockState.refused, refused.message);
    } on _Cancelled {
      return _cancelled;
    }
  }

  Future<HostUnlockResult> _unlock(_Run run) async {
    final card = run.card;
    final key = await _heldKey(card.publicKey);
    if (key == null) return const HostUnlockResult(HostUnlockState.waitingForKey);
    final opened = await _withShare(run, key, (share) => _step(run, 'unlock --share-stdin', share));
    switch (opened) {
      case (code: 0, line: {'vault': 'open'}):
        return const HostUnlockResult(HostUnlockState.unlocked);
      case (code: 66, line: {'vault': 'absent'}):
        return _create(run, key);
      case (code: 77, line: {'vault': 'other-key'}):
        // The share is not held while the person thinks: it is derived again after their yes.
        if (askToClear == null || !await askToClear!(card)) return _otherKey;
        final cleared = await _step(run, 'clear --yes --force', null);
        if (cleared case (code: 0, line: {'refused': false})) return _create(run, key);
        return const HostUnlockResult(HostUnlockState.refused, 'The machine vault could not be cleared.');
      case (code: 65, line: {'vault': 'not-a-host-vault'}):
        return _notAHostVault;
      default:
        return _unexpected;
    }
  }

  Future<HostUnlockResult> _create(_Run run, Uint8List key) async {
    final made = await _withShare(run, key, (share) => _step(run, 'init --share-stdin', share));
    if (made case (code: 0, line: {'vault': 'open'})) return const HostUnlockResult(HostUnlockState.unlocked);
    return const HostUnlockResult(HostUnlockState.refused, 'The machine vault could not be made with your key.');
  }

  Future<HostUnlockResult> _rekey(_Run run, String previousKey) async {
    final key = await _heldKey(run.card.publicKey);
    final previous = await _heldKey(previousKey);
    if (key == null || previous == null) return const HostUnlockResult(HostUnlockState.waitingForKey);
    final changed = await _withShare(
      run,
      previous,
      (old) => _withShare(run, key, (now) {
        final both = Uint8List(64)
          ..setAll(0, old)
          ..setAll(32, now);
        return _step(run, 'rekey --share-stdin', both).whenComplete(() => both.fillRange(0, 64, 0));
      }),
    );
    return switch (changed) {
      (code: 0, line: {'vault': 'open'}) => const HostUnlockResult(HostUnlockState.unlocked),
      (code: 66, line: {'vault': 'absent'}) => const HostUnlockResult(
        HostUnlockState.refused,
        'The machine has no vault to give your new key.',
      ),
      (code: 77, line: {'vault': 'other-key'}) => const HostUnlockResult(
        HostUnlockState.otherKey,
        'Your previous key does not open the machine vault. It was kept unchanged.',
      ),
      (code: 65, line: {'vault': 'not-a-host-vault'}) => _notAHostVault,
      _ => _unexpected,
    };
  }

  static const _otherKey = HostUnlockResult(
    HostUnlockState.otherKey,
    'The machine vault was opened by another key. It was kept; resetting it needs your yes and every sign-in again.',
  );

  static const _notAHostVault = HostUnlockResult(
    HostUnlockState.refused,
    'The machine vault holds other slots than ssh keys; it is neither opened nor cleared from here.',
  );

  static const _unexpected = HostUnlockResult(
    HostUnlockState.refused,
    'The machine vault answered unexpectedly; nothing more was sent to it.',
  );

  /// The agent's blob of [publicKey], or null while the agent does not hold it.
  Future<Uint8List?> _heldKey(String publicKey) async {
    final wanted = publicKeyBlob(publicKey);
    for (final held in await _agent.keys()) {
      if (_same(held, wanted)) return held;
    }
    return null;
  }

  /// Derives [key]'s share for [run]'s card, hands it to [use] and clears it when [use] is done.
  Future<T> _withShare<T>(_Run run, Uint8List key, Future<T> Function(Uint8List share) use) async {
    final share = await deriveVaultShare(_agent, key, sshFingerprint(run.card.hostKey), run.card.login);
    try {
      _stillWanted(run);
      return await use(share);
    } finally {
      share.fillRange(0, share.length, 0);
    }
  }

  /// Whether `ssh-keyscan` of the card's address and port finds the key whose fingerprint is [pinned].
  Future<bool> _hostKeyMatches(_Run run, String pinned) async {
    final card = run.card;
    final scanned = await _run(run, [
      openSsh('ssh-keyscan'),
      '-T',
      '5',
      '-t',
      'ed25519',
      '-p',
      '${card.sshPort}',
      '--',
      card.address,
    ], null);
    for (final line in utf8.decode(scanned.out, allowMalformed: true).split('\n')) {
      final fields = line.trim().split(RegExp(r'\s+'));
      if (fields.length != 3 || fields.first.startsWith('#')) continue;
      try {
        if (sshFingerprint('${fields[1]} ${fields[2]}') == pinned) return true;
      } on VaultShareRefused {
        continue;
      }
    }
    return false;
  }

  /// Runs `porelo vault <verb> --json` on [run]'s host through its card's config, with [input] alone on standard input.
  Future<_HostAnswer> _step(_Run run, String verb, Uint8List? input) async {
    final ran = await _run(run, [
      openSsh('ssh'),
      '-F',
      run.config,
      '-T',
      '--',
      run.card.name,
      inTheLoginShell('porelo vault $verb --json'),
    ], input);
    Map<String, Object?>? line;
    try {
      final answer = jsonDecode(utf8.decode(ran.out).trim());
      if (answer is Map<String, Object?>) line = answer;
    } on FormatException {
      line = null;
    }
    return (code: ran.code, line: line);
  }

  /// Runs [command] as one of [run]'s host's owned children, bounded by [deadline], its answer kept to one short line.
  Future<({int code, List<int> out})> _run(_Run run, List<String> command, Uint8List? input) async {
    _stillWanted(run);
    final process = await _start(command);
    final children = _children.putIfAbsent(run.card.name, () => {})..add(process);
    try {
      _stillWanted(run);
      final out = process.stdout.fold(<int>[], (all, part) => all.length > 4096 ? all : (all..addAll(part)));
      unawaited(process.stderr.drain<void>());
      try {
        if (input != null) process.stdin.add(input);
        await process.stdin.close();
      } on Object {
        // It ended before taking its input; its exit says why.
      }
      final code = await process.exitCode.timeout(deadline);
      final said = await out.timeout(deadline);
      _stillWanted(run);
      return (code: code, out: said);
    } on TimeoutException {
      await stopOwnedProcess(process);
      rethrow;
    } finally {
      children.remove(process);
    }
  }

  /// Ends [run] once its host was cancelled: nothing more is sent to the host.
  void _stillWanted(_Run run) {
    if (run.generation != (_generations[run.card.name] ?? 0)) throw const _Cancelled();
  }

  static bool _same(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Future<void> cancel(String host) async {
    _generations[host] = (_generations[host] ?? 0) + 1;
    for (final child in [...?_children.remove(host)]) {
      await stopOwnedProcess(child);
    }
    await _pending[host];
  }
}

/// One unlock or rekey of [card]'s vault, begun while its host's cancels numbered [generation].
class _Run {
  _Run(this.card, this.config, this.generation);

  final HostCardSsh card;
  final String config;
  final int generation;
}

class _Cancelled implements Exception {
  const _Cancelled();
}
