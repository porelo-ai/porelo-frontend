import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/container_names.dart';

void main() {
  // Harm: the walk's forward step and a task's tab take the task from this; a cut that leaves part of the prefix or takes
  // part of the task names a task that does not exist, so the forward step asks the machine about none or the wrong one.
  group('a container name without its prefix', () {
    test('drops the prefix of either new shape and only that prefix', () {
      expect(withoutContainerPrefix('porelo_fix-rounding'), 'fix-rounding');
      expect(withoutContainerPrefix('porelo-checkout_fix-rounding'), 'fix-rounding');
      expect(withoutContainerPrefix('porelo-e2e-mx_write'), 'write');
      expect(withoutContainerPrefix('porelo-porelo-tools_lint'), 'lint');
    });

    test('drops only porelo- from a name of before, which does not say where its project ends', () {
      expect(withoutContainerPrefix('porelo-fix-rounding'), 'fix-rounding');
      expect(withoutContainerPrefix('porelo-checkout-fix-rounding'), 'checkout-fix-rounding');
    });

    test('keeps a name that is none of porelod\'s, or whose prefix has nothing after it', () {
      expect(withoutContainerPrefix('somebody-else_fix'), 'somebody-else_fix');
      expect(withoutContainerPrefix('porelox_fix'), 'porelox_fix');
      expect(withoutContainerPrefix('porelo_'), 'porelo_');
      expect(withoutContainerPrefix('porelo-checkout_'), 'porelo-checkout_');
      expect(withoutContainerPrefix('porelo-'), 'porelo-');
    });
  });
}
