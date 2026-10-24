import 'dart:convert';

import 'steps.dart';

/// Prints one machine-readable step and its human words.
void writeHostStep(Step step, {required StringSink output, required StringSink errors, DateTime Function()? now}) {
  final fields = jsonDecode(step.toLine()) as Map<String, Object?>;
  fields['at'] = (now ?? DateTime.now)().toUtc().toIso8601String();
  output.writeln(jsonEncode(fields));
  if (step.state == StepState.plan) return;
  errors.writeln(hostStepWords(step));
}

/// The stderr echo paired with a machine-readable step.
String hostStepWords(Step step) {
  final said = <String?>[step.words, step.fix].whereType<String>().join(': ');
  return '${step.step} ${step.state.name}${said.isEmpty ? '' : ' — $said'}';
}
