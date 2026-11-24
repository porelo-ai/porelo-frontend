import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/gate.dart';

void main() {
  // Harm: a command copied from the page runs on another push, or a name breaks out of its word in the shell.
  test('the command names the push, its project and repository in their long forms', () {
    expect(
      reviewCommentsCommand(name: 'fix-login', project: 'shop', repository: 'app'),
      'porelo gate comments fix-login --project shop --repository app',
    );
  });

  test('a value that is not a plain word is quoted for the shell, a quote in it included', () {
    expect(
      reviewCommentsCommand(name: "it's done", project: 'my shop', repository: 'app'),
      r"porelo gate comments 'it'\''s done' --project 'my shop' --repository app",
    );
  });

  // Harm: a check that did not finish reads as clean, or one in a word this build does not know as finished.
  test('only a complete run with none found reads "no findings"', () {
    String words(String completeness, int findings) =>
        ChecksRead.runWords(ReviewRun(name: 'owner review', completeness: completeness, findings: findings));
    expect(words('complete', 0), 'owner review: complete · no findings');
    expect(words('complete', 1), 'owner review: complete · 1 finding');
    for (final word in ['partial', 'failed', 'unknown', 'not-a-word-this-build-knows']) {
      expect(words(word, 0), 'owner review: $word · 0 findings so far');
    }
    expect(words('', 0), 'owner review: no word given · 0 findings so far', reason: 'a blank is never clean');
    expect(words('  ', 0), 'owner review: no word given · 0 findings so far');
  });
}
