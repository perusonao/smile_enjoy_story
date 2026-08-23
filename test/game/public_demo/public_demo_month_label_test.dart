import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_month_label.dart';

/// 12MONTH-3: internal months run 4-15 so every domain comparison stays
/// simple int arithmetic (see public_demo_month_label.dart). This proves
/// the one place that converts back to a calendar label never leaks the
/// raw internal value for the January-March months.
void main() {
  group('publicDemoMonthLabel', () {
    test('April through December map to themselves', () {
      for (var month = 4; month <= 12; month++) {
        expect(publicDemoMonthLabel(month), '$month月');
      }
    });

    test('13/14/15 map to January/February/March, never "13月"/"14月"/"15月"', () {
      expect(publicDemoMonthLabel(13), '1月');
      expect(publicDemoMonthLabel(14), '2月');
      expect(publicDemoMonthLabel(15), '3月');
      expect(publicDemoMonthLabel(13), isNot('13月'));
      expect(publicDemoMonthLabel(14), isNot('14月'));
      expect(publicDemoMonthLabel(15), isNot('15月'));
    });
  });
}
