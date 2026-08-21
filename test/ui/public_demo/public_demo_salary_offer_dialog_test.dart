import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_salary_offer_dialog.dart';

void main() {
  const applicant = PublicDemoApplicant(
    id: 'test-applicant',
    name: 'テスト応募者',
    resumeSummary: 'Java 3年',
    interviewScore: 70,
    acceptanceScore: 60,
    salesSkillFit: 70,
    requestedMonthlySalary: 320000,
  );

  testWidgets('shows requested salary and three salary choices', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PublicDemoSalaryOfferDialog(applicant: applicant)),
      ),
    );

    expect(find.text('月給 ¥32万'), findsOneWidget);
    expect(find.text('28万円'), findsOneWidget);
    expect(find.text('32万円'), findsOneWidget);
    expect(find.text('36万円'), findsOneWidget);
  });

  testWidgets('returns evaluated salary offer', (tester) async {
    PublicDemoSalaryOffer? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showDialog<PublicDemoSalaryOffer>(
                context: context,
                builder: (_) => const PublicDemoSalaryOfferDialog(applicant: applicant),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('public-demo-salary-offer-280000')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.offeredMonthlySalary, 280000);
    expect(result!.acceptanceScore, lessThan(applicant.acceptanceScore));
    expect(result!.motivationDelta, lessThan(0));
    expect(result!.trustDelta, lessThan(0));
  });
}
