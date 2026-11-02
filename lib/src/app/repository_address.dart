import 'run_here.dart' show WorkspaceRefused;

/// Refuses an address with credentials or unsafe Git source syntax, without repeating it: it may hold a token.
void checkRepositoryAddress(String repository) {
  final uri = Uri.tryParse(repository);
  final https = uri != null && uri.scheme == 'https' && uri.host.isNotEmpty && uri.userInfo.isEmpty;
  final ssh = RegExp(r'^git@[A-Za-z0-9][A-Za-z0-9.-]*:[A-Za-z0-9_./-]+$').hasMatch(repository);
  if ((!https && !ssh) ||
      (https && (uri.hasQuery || uri.hasFragment)) ||
      RegExp(r'[\s\x00-\x1f\x7f\\]').hasMatch(repository)) {
    throw const WorkspaceRefused(
      'A repository address is a git@ or https address without a user name, password or token.',
    );
  }
}
