import 'package:flutter_test/flutter_test.dart';
import 'package:jin_du_progress/main.dart';

void main() {
  test('money formatter formats whole NT dollars', () {
    expect(money(1234567), 'NT\$1,234,567');
  });
}
