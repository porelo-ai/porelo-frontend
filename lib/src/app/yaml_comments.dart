import 'package:yaml/yaml.dart';

/// Finds YAML comments while excluding hashes inside scalar values.
List<String> yamlComments(String yaml, YamlNode node) {
  final scalars = <(int, int)>[];
  void visit(YamlNode child) {
    if (child is YamlScalar) {
      scalars.add((child.span.start.offset, child.span.end.offset));
    } else if (child is YamlMap) {
      for (final entry in child.nodes.entries) {
        visit(entry.key as YamlNode);
        visit(entry.value);
      }
    } else if (child is YamlList) {
      child.nodes.forEach(visit);
    }
  }

  visit(node);
  final comments = <String>[];
  for (var at = 0; at < yaml.length; at++) {
    if (yaml[at] != '#' || scalars.any((span) => at >= span.$1 && at < span.$2)) continue;
    final newline = yaml.indexOf('\n', at);
    final end = newline < 0 ? yaml.length : newline;
    comments.add(yaml.substring(at, end).trimRight());
    at = end;
  }
  return comments;
}

/// Restores comments yaml_edit removed with an adjacent mapping or list item.
String retainYamlComments(String source, String written) {
  final remaining = <String, int>{};
  for (final comment in yamlComments(written, loadYamlNode(written))) {
    remaining.update(comment, (n) => n + 1, ifAbsent: () => 1);
  }
  final missing = <String>[];
  for (final comment in yamlComments(source, loadYamlNode(source))) {
    final count = remaining[comment] ?? 0;
    if (count == 0) {
      missing.add(comment);
    } else {
      remaining[comment] = count - 1;
    }
  }
  return missing.isEmpty ? written : '${missing.join('\n')}\n$written';
}
