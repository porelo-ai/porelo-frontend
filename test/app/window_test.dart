import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/window.dart';

/// A second launch joins the one already running, which is only true if something comes forward.
/// A window that stays behind whatever the person was looking at reads as a launch that failed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('porelo/window');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('asks the window it is drawn in to come forward', () async {
    final asked = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      asked.add(call.method);
      return true;
    });

    await Window.comeForward();

    expect(asked, <String>['present'], reason: 'nothing else raises the window');
  });

  test('a desktop that will not raise the window is not a failure', () async {
    messenger.setMockMethodCallHandler(
        channel, (call) async => throw PlatformException(code: 'no'));

    await expectLater(Window.comeForward(), completes);
  });

  test('a host with no window at all is not a failure either', () async {
    // Nothing is registered: a test, or a headless build. The second launch has already said its
    // piece on the terminal, so there is nobody left to tell.
    await expectLater(Window.comeForward(), completes);
  });
}
