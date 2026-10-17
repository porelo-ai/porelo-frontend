import 'dart:io';

/// The value of [name] in [environment], or null when it is unset **or empty**, without a trailing
/// slash.
///
/// The XDG base directory specification treats an empty variable as unset, and `"$empty/porelo"` is a
/// directory at the root that nobody can write to — the operation history was then never kept.
String? setIn(String name, [Map<String, String>? environment]) {
  final value = (environment ?? Platform.environment)[name];
  if (value == null || value.isEmpty) return null;
  return value.length > 1 && value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}
