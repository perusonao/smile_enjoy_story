import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_raise_dialog.dart';

void main() {
  testWidgets(
    'raise dialog presents the three choices without condition numbers',
    (tester) async {
      final applicant = const PublicDemoApplicant(
        id: 'dialog-hire',
        name: 'Dialog Hire',
        resumeSummary: 'Java 3年',
        interviewScore: 70,
        acceptanceScore: 70,
        salesSkillFit: 70,
        acceptedMonthlySalary: 320000,
      ).join(week: 9);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PublicDemoRaiseDialog(applicant: applicant)),
        ),
      );
      expect(find.text('据え置き'), findsOneWidget);
      expect(find.text('小幅昇給'), findsOneWidget);
      expect(find.text('希望額で昇給'), findsOneWidget);
      expect(find.textContaining('65'), findsNothing);
      expect(find.textContaining('60'), findsNothing);
    },
  );
}
