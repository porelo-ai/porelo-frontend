import 'host_access_contract.dart' show checkedRegistryRevision;

/// Resumes the shared signed-commit and publication stages from durable receipts.
///
/// Filing must deduplicate its durable request ID. Each receipt is saved before
/// the next side effect, so a restart never signs a second change after publication.
Future<String> resumeSignedPublication({
  required String? revision,
  required bool published,
  required Future<void> Function() authorize,
  required Future<String> Function() file,
  required Future<void> Function(String revision) publish,
  required Future<void> Function(String revision, bool published) keep,
  Future<bool> Function(String revision)? publishedAlready,
}) async {
  var intended = revision;
  if (intended == null) {
    await authorize();
    intended = checkedRegistryRevision(await file());
    await keep(intended, false);
  }
  if (!published) {
    // A successful push can outlive its receipt and revoke the actor's signing authority.
    if (await publishedAlready?.call(intended) != true) {
      await authorize();
      await publish(intended);
    }
    await keep(intended, true);
  }
  return intended;
}
