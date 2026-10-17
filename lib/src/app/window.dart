import 'package:flutter/services.dart';

/// The window this interface is drawn in.
///
/// One method, and it exists for one reason: a second launch asks the interface already running to
/// come forward. Presenting a window is the desktop's own business, which Dart has no way to ask
/// for, so the Linux runner carries the smallest bridge to it.
class Window {
  static const _channel = MethodChannel('porelo/window');

  /// Brings the window forward.
  ///
  /// Quiet when it cannot: a desktop that will not raise a window is not a reason to fail, and
  /// there is nothing useful to say about it to somebody who is looking at another window anyway.
  static Future<void> comeForward() async {
    try {
      await _channel.invokeMethod<bool>('present');
    } on PlatformException {
      // Nothing to do. The second launch has already said its piece on the terminal.
    } on MissingPluginException {
      // Running under a host with no window — a test, or a headless build.
    }
  }
}
