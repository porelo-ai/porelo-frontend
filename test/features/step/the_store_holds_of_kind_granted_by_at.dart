import 'package:flutter_test/flutter_test.dart';
import 'package:sokar_frontend/client.dart';

import '../support/world.dart';

/// Usage: the store holds {'jira'} of kind {'oauth-device'} granted by {'alice'} at {'2026-09-30T05:40:00Z'}
Future<void> theStoreHoldsOfKindGrantedByAt(WidgetTester tester, String name, String kind, String by, String at) async {
  World.backend.theStoreIs = VaultState.from(<String, dynamic>{
    'vault': '/home/somebody/.local/share/sokar/vault.bin',
    'exists': true,
    'credentials': <Map<String, dynamic>>[
      <String, dynamic>{
        'name': name,
        'type': kind,
        'characters': 0,
        'grant': <String, dynamic>{'grantedBy': by, 'grantedAt': at},
      },
    ],
    'readable': true,
  });
}
