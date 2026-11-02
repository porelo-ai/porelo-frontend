import 'package:porelo_host/porelo_host.dart';

import 'forge.dart';

/// The forge token an instance is started with, read for the forge [forgeTokenForgeVariable] names and no other.
const forgeTokenVariable = 'PORELO_FORGE_TOKEN';

/// The forge [forgeTokenVariable] is for, such as `github.com`.
const forgeTokenForgeVariable = 'PORELO_FORGE_TOKEN_FORGE';

/// The central token an instance is started with, which a terminal hands to a host.
const centralTokenVariable = 'PORELO_CENTRAL_TOKEN';

/// Where the central push, the pull and a host's `org refresh` take their token from: the variable an instance was
/// started with, or the person's own [chosen] file, its master password typed in the terminal. Null where neither is.
CentralToken? centralToken(String? chosen, Map<String, String> environment) {
  if ((environment[centralTokenVariable] ?? '').isNotEmpty) return EnvironmentCentralToken(centralTokenVariable);
  return chosen == null ? null : SecretsFile(chosen);
}

/// The forge token of an instance started with one, for its one forge; every other forge reads [otherwise].
///
/// **A token never goes to a forge it was not given for.** Nothing is kept from here for that forge either: a token
/// typed would be lost when the instance ends, while seeming kept, so it is refused.
class EnvironmentForgeTokens implements ForgeTokens {
  /// Reads [environment] for its one forge, and [otherwise] for the rest.
  EnvironmentForgeTokens(Map<String, String> environment, this.otherwise)
    : _token = environment[forgeTokenVariable] ?? '',
      _forge = environment[forgeTokenForgeVariable] ?? '';

  /// Where every other forge's token is kept.
  final ForgeTokens otherwise;

  final String _token;
  final String _forge;

  bool _given(String forge) => _token.isNotEmpty && _forge.isNotEmpty && forgeAddress(_forge) == forgeAddress(forge);

  @override
  Future<String?> read(String forge) async => _given(forge) ? _token : otherwise.read(forge);

  @override
  Future<void> write(String forge, String token) async => _given(forge)
      ? throw ForgeRefused('This instance was started with its token for $forge; nothing was kept.')
      : otherwise.write(forge, token);

  @override
  Future<void> delete(String forge) async => _given(forge)
      ? throw ForgeRefused('This instance was started with its token for $forge; nothing was deleted.')
      : otherwise.delete(forge);
}
