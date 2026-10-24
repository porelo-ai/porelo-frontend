import 'steps.dart';

/// Prints one machine-readable step and its human words.
void writeHostStep(Step step, {required StringSink output, required StringSink errors}) {
  output.writeln(step.toLine());
  if (step.state == StepState.plan) return;
  final said = <String?>[step.words, step.fix].whereType<String>().join(': ');
  errors.writeln('${step.step} ${step.state.name}${said.isEmpty ? '' : ' — $said'}');
}
