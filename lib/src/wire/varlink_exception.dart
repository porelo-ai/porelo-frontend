/// An error reply from a varlink service.
///
/// Errors are answers, not faults. `HOLDS_WORK` from a stop, a clearance refused because the task
/// is gone, a method an older backend does not have - each is something the interface has to
/// show, so each arrives here with its name intact rather than flattened into a message.
class VarlinkException implements Exception {
  /// Fully-qualified error name, such as `org.fuin.porelo.Tasks1.NoSuchLog`.
  final String name;

  /// Whatever the service sent with it.
  final Map<String, dynamic> parameters;

  /// Constructor with the error's name and parameters.
  const VarlinkException(this.name, [this.parameters = const {}]);

  /// Whether this is the service saying it has no such method.
  ///
  /// The signal a client degrades on: a backend older than this build answers it for anything
  /// added since, and the right response is to disable that one feature rather than to fail.
  bool get isMethodNotFound => name == 'org.varlink.service.MethodNotFound';

  /// The part after the last dot, for a caller matching on one specific refusal.
  String get simpleName => name.substring(name.lastIndexOf('.') + 1);

  @override
  String toString() => parameters.isEmpty ? name : '$name $parameters';
}

/// The connection failed, or ended before the call was answered.
///
/// Distinct from [VarlinkException] on purpose: one means the far end refused, the other means it
/// is not there. An interface must show a lost tunnel as a disconnection and never as a machine
/// with nothing running on it.
class VarlinkDisconnected implements Exception {
  /// What happened, for a person.
  final String message;

  /// Constructor with the reason.
  const VarlinkDisconnected(this.message);

  @override
  String toString() => 'Disconnected: $message';
}
