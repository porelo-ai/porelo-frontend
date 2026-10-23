// A literal reference, independent of the implementation and this machine's environment.
const expectedPinnedOptions = <String>[
  '-o',
  'StrictHostKeyChecking=yes',
  '-o',
  'UserKnownHostsFile="/trust/host_keys"',
  '-o',
  'GlobalKnownHostsFile=none',
  '-o',
  'KnownHostsCommand=none',
  '-o',
  'VerifyHostKeyDNS=no',
  '-o',
  'UpdateHostKeys=no',
  '-o',
  'BatchMode=yes',
  '-o',
  'IdentitiesOnly=yes',
  '-o',
  'ControlMaster=no',
  '-o',
  'ControlPath=none',
  '-i',
  '/keys/host identity',
];

/// What breaks ssh's first-value rule in [command], empty when the pinned trust policy leads it and
/// nothing later names another source of trusted keys. Free of any test library, so both the
/// package and the interface use it.
List<String> pinnedCommandProblems(
  List<String> command, {
  String knownHosts = '/trust/host_keys',
  String identity = '/keys/host identity',
}) {
  final expected = expectedPinnedOptions
      .map(
        (s) => s == 'UserKnownHostsFile="/trust/host_keys"'
            ? 'UserKnownHostsFile="$knownHosts"'
            : s == '/keys/host identity'
            ? identity
            : s,
      )
      .toList();
  final problems = <String>[];
  final leading = command.skip(1).take(expected.length).toList();
  if (leading.join('\u0000') != expected.join('\u0000')) {
    problems.add('the pinned trust policy must precede every other option: $leading');
  }
  final later = command.skip(1 + expected.length).takeWhile((word) => word != '--').toList();
  for (final setting in <String>[
    'StrictHostKeyChecking',
    'UserKnownHostsFile',
    'GlobalKnownHostsFile',
    'KnownHostsCommand',
    'VerifyHostKeyDNS',
  ]) {
    if (later.any((word) => word.toLowerCase().contains(setting.toLowerCase()))) {
      problems.add('a later option redefines $setting');
    }
  }
  if (command.contains('-F')) problems.add('-F drops the ProxyJump a person may need from ssh config');
  return problems;
}
