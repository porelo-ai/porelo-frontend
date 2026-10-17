import 'package:flutter/foundation.dart';

/// A model that may still be finishing a call when the dialog that showed it disposes it: what it
/// says after that is said to nobody, never thrown as a use after dispose.
mixin QuietAfterDispose on ChangeNotifier {
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
