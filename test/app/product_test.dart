import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/product.dart';

void main() {
  // Harm: an installed snapshot window, a release build like a release's, sets WSL and hosts up from releases; or a
  // release window sets them up from snapshots.
  test('only a release build of a release version takes releases', () {
    expect(windowTakesSnapshots(release: true, version: '0.5.13'), isFalse);
    expect(windowTakesSnapshots(release: true, version: '0.5.13~snapshot.13'), isTrue);
    expect(windowTakesSnapshots(release: true, version: 'built from source'), isTrue);
    expect(windowTakesSnapshots(release: false, version: '0.5.13'), isTrue);
    expect(windowTakesSnapshots(release: false, version: 'built from source'), isTrue);
  });
}
