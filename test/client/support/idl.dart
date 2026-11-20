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

/// The parameters of a method's [declaration]: what stands before its reply.
String parametersOf(String declaration) {
  final reply = declaration.indexOf(') -> (');
  return reply == -1 ? declaration : declaration.substring(0, reply);
}

/// Each method a client's [source] calls through `_call` or `_callMore` with a map written in place, and the keys it
/// writes there; a call that passes a map built elsewhere names none.
Map<String, Set<String>> parametersSent(String source) {
  final sent = <String, Set<String>>{};
  for (final call in RegExp(r"_call(?:More)?\(\s*'([A-Za-z0-9]+)'").allMatches(source)) {
    final names = sent.putIfAbsent(call.group(1)!, () => <String>{});
    // Up to the call's own closing parenthesis; the first brace on the way opens the map written in place.
    var depth = 1;
    var i = call.end;
    var mapAt = -1;
    while (i < source.length && depth > 0) {
      final c = source[i];
      if (c == '(') depth++;
      if (c == ')') depth--;
      if (c == '{' && mapAt == -1 && depth == 1) mapAt = i;
      i++;
    }
    if (mapAt == -1) continue;
    var braces = 0;
    for (var j = mapAt; j < i; j++) {
      final c = source[j];
      if (c == '{') braces++;
      if (c == '}') {
        braces--;
        if (braces == 0) break;
      }
      if (braces == 1 && c == "'") {
        final key = RegExp(r"'([A-Za-z0-9_]+)':").matchAsPrefix(source, j);
        if (key != null) names.add(key.group(1)!);
      }
    }
  }
  return sent;
}

/// Whether [declaration] names [field] as a field of its own, `field: `, and not inside another name.
bool declares(String declaration, String field) => RegExp('\\b${RegExp.escape(field)}: ').hasMatch(declaration);
