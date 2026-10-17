/// Reading a varlink contract's text, for tests that hold this client to what a daemon serves.
library;

/// The declaration in [contract] that starts with [head], up to where it closes: a `type` closes
/// once, a method twice, its parameters and then ") -> (" and its reply. Null where it is not there.
String? declarationIn(String contract, String head) {
  final start = contract.indexOf(head);
  if (start == -1) return null;
  var end = contract.indexOf('\n)', start);
  if (end == -1) return contract.substring(start);
  if (contract.startsWith('\n) -> (', end)) {
    final reply = contract.indexOf('\n)', end + 1);
    end = reply == -1 ? contract.length : reply;
  }
  return contract.substring(start, end);
}

/// Whether [declaration] names [field] as a field of its own, `field: `, and not inside another name.
bool declares(String declaration, String field) => RegExp('\\b${RegExp.escape(field)}: ').hasMatch(declaration);
