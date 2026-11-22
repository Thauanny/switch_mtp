import 'package:flutter_test/flutter_test.dart';
import 'package:switch_mtp/ui/format.dart';

void main() {
  test('formatBytes', () {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(1536), '1.5 KB');
    expect(formatBytes(5 * 1024 * 1024 * 1024), '5.0 GB');
  });
}
