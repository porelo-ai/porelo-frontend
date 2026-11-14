import 'package:flutter/foundation.dart';

/// What the interface is called wherever a person reads its name: the window's title, the menu
/// entry, the about dialog and the Windows package. Its binary, package and paths keep the technical
/// name `porelo-frontend`, which nothing on screen shows.
const productName = 'Porelo Control Tower';

/// This window's version as the package build stamps it: `x.y.z` for a release, `x.y.z~snapshot.<run>` for a
/// snapshot. A build from source is stamped with none and says so.
const windowVersion = String.fromEnvironment('PORELO_VERSION', defaultValue: 'built from source');

/// Whether what this window sets up takes Porelo from `snapshots` rather than `releases`. Only a release build of a
/// release version takes `releases`; a snapshot package is a release build too, so its version decides, and a build
/// from source takes `snapshots`.
bool windowTakesSnapshots({bool release = kReleaseMode, String version = windowVersion}) =>
    !(release && RegExp(r'^[0-9]+\.[0-9]+\.[0-9]+$').hasMatch(version));
