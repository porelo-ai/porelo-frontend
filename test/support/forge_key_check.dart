import 'package:porelo_frontend/src/app/forge_key_check.dart';

/// Answers each read with [reading], counting the reads.
class FakeForgeKeyCheck implements ForgeKeyCheck {
  FakeForgeKeyCheck(this.reading);
  ForgeKeyReading reading;
  int reads = 0;

  @override
  Future<ForgeKeyReading> read() async {
    reads++;
    return reading;
  }
}
