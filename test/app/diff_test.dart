import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/diff.dart';

/// The gate answers `Review` with a diff as one string. This is what turns it into something a
/// person can look through file by file — the honest ceiling, since nothing can read a file at a
/// revision, so what surrounds a hunk is not knowable from here.
void main() {
  test('a changed file carries its hunks and counts what moved', () {
    const diff = '''
diff --git a/lib/gate.dart b/lib/gate.dart
index 1a2b3c4..5d6e7f8 100644
--- a/lib/gate.dart
+++ b/lib/gate.dart
@@ -1,4 +1,5 @@
 import 'dart:io';
-final old = 1;
+final fresh = 1;
+final alsoFresh = 2;
 void main() {}
''';

    final files = parseUnifiedDiff(diff);

    expect(files, hasLength(1));
    expect(files.single.path, 'lib/gate.dart');
    expect(files.single.what, 'changed');
    expect(files.single.insertions, 2);
    expect(files.single.deletions, 1);
    expect(files.single.lines.first.kind, DiffLineKind.hunk);
  });

  test('git headers are not rendered as changed lines', () {
    // `index 1a2b3c4..5d6e7f8` begins with no marker and sits outside every hunk. Rendered as a
    // line it would read as something the work did.
    const diff = '''
diff --git a/a.txt b/a.txt
index 1a2b3c4..5d6e7f8 100644
--- a/a.txt
+++ b/a.txt
@@ -1 +1 @@
-one
+two
''';

    final lines = parseUnifiedDiff(diff).single.lines;

    expect(lines.map((line) => line.text), <String>['@@ -1 +1 @@', 'one', 'two']);
  });

  test('a file the work created is marked as added', () {
    const diff = '''
diff --git a/new.txt b/new.txt
new file mode 100644
--- /dev/null
+++ b/new.txt
@@ -0,0 +1 @@
+hello
''';

    final file = parseUnifiedDiff(diff).single;

    expect(file.added, isTrue);
    expect(file.what, 'added');
    expect(file.path, 'new.txt');
  });

  test('a file it deleted is marked as removed, and keeps the name it had', () {
    const diff = '''
diff --git a/gone.txt b/gone.txt
deleted file mode 100644
--- a/gone.txt
+++ /dev/null
@@ -1 +0,0 @@
-was here
''';

    final file = parseUnifiedDiff(diff).single;

    expect(file.removed, isTrue);
    expect(file.what, 'removed');
    expect(file.path, 'gone.txt');
  });

  test('a file it moved says where it was', () {
    const diff = '''
diff --git a/old/place.dart b/new/place.dart
similarity index 98%
--- a/old/place.dart
+++ b/new/place.dart
@@ -1 +1 @@
-one
+two
''';

    final file = parseUnifiedDiff(diff).single;

    expect(file.path, 'new/place.dart');
    expect(file.wasAt, 'old/place.dart');
    expect(file.what, 'moved');
  });

  test('several files come back separately, in the order the diff had them', () {
    const diff = '''
diff --git a/first.txt b/first.txt
--- a/first.txt
+++ b/first.txt
@@ -1 +1 @@
-a
+b
diff --git a/second.txt b/second.txt
--- a/second.txt
+++ b/second.txt
@@ -1 +1 @@
-c
+d
''';

    expect(parseUnifiedDiff(diff).map((file) => file.path),
        <String>['first.txt', 'second.txt']);
  });

  test('nothing at all reads as no files, not as a broken review', () {
    expect(parseUnifiedDiff(''), isEmpty);
  });

  test('an unfamiliar header does not stop the lines that follow being read', () {
    // git's output, not a promise in the IDL. A review that refused to render because a header
    // was new would be worse than one that shows what it understood.
    const diff = '''
diff --git a/a.txt b/a.txt
something-new-from-a-later-git 1234
--- a/a.txt
+++ b/a.txt
@@ -1 +1 @@
-one
+two
''';

    expect(parseUnifiedDiff(diff).single.insertions, 1);
  });
}
