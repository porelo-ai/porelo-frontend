import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/settings.dart';

void main() {
  // Harm: a person who needs larger text sets it at every start again.
  test('the zoom is kept for the next start', () async {
    final store = MemorySettingsStore({'form': settingsForm});
    final first = Settings(store);
    await first.load();
    await first.zoomIn();
    await first.zoomIn();
    expect(first.zoomPercent, 125);

    final next = Settings(store);
    await next.load();
    expect(next.zoomPercent, 125);
  });

  // Harm: the window grows or shrinks past what can be read or used, with no step back.
  test('the zoom moves by steps and stops at the first and the last', () async {
    final settings = Settings(MemorySettingsStore({'form': settingsForm}));
    await settings.load();
    for (var i = 0; i < 20; i++) {
      await settings.zoomIn();
    }
    expect(settings.zoomPercent, Settings.zoomSteps.last);
    for (var i = 0; i < 20; i++) {
      await settings.zoomOut();
    }
    expect(settings.zoomPercent, Settings.zoomSteps.first);
    await settings.zoomReset();
    expect(settings.zoomPercent, 100);
  });

  // Harm: a stored value the window does not offer draws it at a size no step leads back from.
  test('a stored zoom the window does not offer is read as the usual size', () async {
    final settings = Settings(MemorySettingsStore({'form': settingsForm, 'zoomPercent': 3000}));
    await settings.load();
    expect(settings.zoomPercent, 100);
  });
}
