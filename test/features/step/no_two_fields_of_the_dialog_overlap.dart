import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: no two fields of the dialog overlap
Future<void> noTwoFieldsOfTheDialogOverlap(WidgetTester tester) async {
  // A field's floating label rises above its own box, so boxes that merely touch still overlap.
  final fields = find.descendant(of: find.byType(AlertDialog), matching: find.byType(InputDecorator));
  final boxes = [for (final each in fields.evaluate()) tester.getRect(find.byWidget(each.widget))]
    ..sort((a, b) => a.top.compareTo(b.top));
  expect(boxes.length, greaterThan(2), reason: 'the dialog should have fields to judge');
  for (var i = 1; i < boxes.length; i++) {
    expect(
      boxes[i].top - boxes[i - 1].bottom,
      greaterThanOrEqualTo(4),
      reason: 'the label of field ${i + 1} reaches into field $i',
    );
  }
}
