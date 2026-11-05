import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

/// Reading a reviewed file's count without its line ends.
///
/// The harm: a count an older machine never sent, read as zero, says a whole real change is only line
/// endings, and a person skips reading it.
void main() {
  test('counts the machine does not send are absent, and say nothing about line endings', () {
    final read = ReviewFile.from(<String, dynamic>{
      'path': 'lib/money.dart',
      'status': 'M',
      'added': 1042,
      'removed': 1043,
      'rank': 'ORDINARY',
      'reason': '',
    });
    expect(read.addedIgnoringLineEndings, isNull);
    expect(read.removedIgnoringLineEndings, isNull);
    expect(read.mostlyLineEndings, isFalse);
  });

  test('a CRLF to LF file of three real lines is mostly line endings', () {
    final read = ReviewFile.from(<String, dynamic>{
      'path': 'lib/legacy.dart',
      'added': 1042,
      'removed': 1043,
      'addedIgnoringLineEndings': 1,
      'removedIgnoringLineEndings': 2,
    });
    expect(read.addedIgnoringLineEndings, 1);
    expect(read.removedIgnoringLineEndings, 2);
    expect(read.mostlyLineEndings, isTrue);
  });

  test('a binary file is never mostly line endings', () {
    final read = ReviewFile.from(<String, dynamic>{
      'path': 'logo.png',
      'added': -1,
      'removed': -1,
      'addedIgnoringLineEndings': -1,
      'removedIgnoringLineEndings': -1,
    });
    expect(read.mostlyLineEndings, isFalse);
  });

  test('a change whose lines are all real is not mostly line endings', () {
    final read = ReviewFile.from(<String, dynamic>{
      'path': 'lib/money.dart',
      'added': 10,
      'removed': 4,
      'addedIgnoringLineEndings': 10,
      'removedIgnoringLineEndings': 4,
    });
    expect(read.mostlyLineEndings, isFalse);
  });
}
