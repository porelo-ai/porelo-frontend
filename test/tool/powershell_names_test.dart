import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The names a PowerShell script takes as parameters, from its `param(...)` block.
Set<String> _parameters(String script) {
  final block = RegExp(r'^param\s*\(([\s\S]*?)^\)', multiLine: true).firstMatch(script)?.group(1) ?? '';
  return {for (final match in RegExp(r'\$(\w+)').allMatches(block)) match.group(1)!};
}

/// Each variable the script assigns, as written, where the assignment opens a statement.
Iterable<({int line, String name})> _assigned(String script) sync* {
  final lines = script.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final match = RegExp(r'^\s*\$(\w+)\s*=[^=]').firstMatch(lines[i]);
    if (match != null) yield (line: i + 1, name: match.group(1)!);
  }
}

void main() {
  // Harm: PowerShell names ignore case, so a variable written like a parameter in another case overwrites the parameter;
  // windows-prepare.ps1 set `$release` to False and then wrote porelo-host.exe under a folder named false, which no
  // Linux run of the build sees.
  test('no PowerShell script assigns a parameter of its own under another case', () {
    final scripts = Process.runSync('git', [
      'ls-files',
      '*.ps1',
    ]).stdout.toString().split('\n').where((p) => p.isNotEmpty);
    expect(scripts, isNotEmpty);
    final clashes = <String>[];
    for (final path in scripts) {
      final script = File(path).readAsStringSync();
      final parameters = _parameters(script);
      for (final (:line, :name) in _assigned(script)) {
        for (final parameter in parameters) {
          if (parameter != name && parameter.toLowerCase() == name.toLowerCase()) {
            clashes.add('$path:$line assigns \$$name over the parameter \$$parameter');
          }
        }
      }
    }
    expect(clashes, isEmpty);
  });
}
