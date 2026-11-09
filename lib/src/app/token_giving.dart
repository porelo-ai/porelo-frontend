import 'package:flutter/foundation.dart';

/// Gives a machine this person's token: once per machine at a time, wherever it was asked from. A second ask while one
/// runs gives nothing, as two would feed the token over two logins at once.
class TokenGiving extends ChangeNotifier {
  /// Gives with the given function, which answers why not or null.
  TokenGiving(this._give);

  final Future<String?> Function(String host, {bool atOnce}) _give;
  final _giving = <String>{};
  bool _disposed = false;

  /// Why [host] cannot be given the token now, or null where it can.
  String? busy(String host) => _giving.contains(host) ? '$host is being given your token already.' : null;

  /// Gives [host] the token, [atOnce] passed on; answers why not, or null once given.
  Future<String?> give(String host, {bool atOnce = false}) async {
    if (!_giving.add(host)) return busy(host);
    notifyListeners();
    try {
      return await _give(host, atOnce: atOnce);
    } finally {
      _giving.remove(host);
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
