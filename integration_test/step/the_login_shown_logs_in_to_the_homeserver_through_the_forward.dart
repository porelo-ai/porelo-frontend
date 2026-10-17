import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import 'the_test_machine_has_a_project_with_a_conversation.dart';

/// Usage: the login shown logs in to the homeserver through the forward
Future<void> theLoginShownLogsInToTheHomeserverThroughTheForward(WidgetTester tester) async {
  if (noConversationHere != null) return;
  // Each field holds its value alone; its name stands beside it, as a Matrix client names it.
  String shown(String field) => tester.widget<SelectableText>(find.byKey(ValueKey<String>('login $field'))).data!;

  final homeserver = shown('homeserver');
  final user = shown('user');
  final password = shown('password');
  await pumpUntil(
    tester,
    () => find.textContaining('is forwarded from this computer').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the homeserver forwarded here',
  );
  // What a person's Matrix client does with it: log in, on this computer, through the forward.
  final client = HttpClient();
  try {
    final request = await client.postUrl(Uri.parse('$homeserver/_matrix/client/v3/login'));
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode(<String, dynamic>{
        'type': 'm.login.password',
        'identifier': <String, dynamic>{'type': 'm.id.user', 'user': user},
        'password': password,
      }),
    );
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    expect(response.statusCode, 200, reason: body);
    expect((jsonDecode(body) as Map<String, dynamic>)['user_id'], user);
  } finally {
    client.close(force: true);
  }
}
