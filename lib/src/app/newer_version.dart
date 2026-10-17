import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Notices when a newer build of the interface has been installed under it.
///
/// A package upgrade replaces the binary while this one keeps running, so what somebody has open
/// is quietly out of date. Saying so beats leaving them to find out through a bug that has already
/// been fixed — and declining leaves everything exactly as it was, because nothing here restarts
/// anything on its own.
class NewerVersion extends ChangeNotifier {
  /// Constructor taking what to watch and how often to look.
  ///
  /// [what] and [every] are injectable so this can be tested without installing anything.
  NewerVersion({File? what, this.every = const Duration(minutes: 5)})
    : _what = what ?? File(Platform.resolvedExecutable);

  final File _what;

  /// How often to look.
  final Duration every;

  DateTime? _asStarted;
  Timer? _looking;
  bool _arrived = false;

  /// Whether a newer build is installed and this one is still running.
  bool get arrived => _arrived;

  /// Starts watching. Safe when the file cannot be read: nothing is claimed either way.
  void watch() {
    _asStarted = _changedAt();
    _looking?.cancel();
    if (_asStarted == null) return;
    _looking = Timer.periodic(every, (_) => _look());
  }

  /// Looks now.
  void _look() {
    final now = _changedAt();
    if (now == null || _asStarted == null) return;
    if (!now.isAfter(_asStarted!)) return;
    _arrived = true;
    _looking?.cancel();
    notifyListeners();
  }

  @visibleForTesting
  // ignore: public_member_api_docs
  void lookNow() => _look();

  DateTime? _changedAt() {
    try {
      return _what.statSync().modified;
    } on FileSystemException {
      return null;
    }
  }

  @override
  void dispose() {
    _looking?.cancel();
    super.dispose();
  }
}
