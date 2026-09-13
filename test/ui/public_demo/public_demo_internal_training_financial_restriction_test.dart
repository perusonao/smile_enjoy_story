// SES First Fun Quarter P1-3 Fresh Audit (Issue #122): the 研修 CTA visibility
// fix. `internalTrainingCard`'s `showAction` gate previously checked
// `s.isCloseBlocked` but not `s.isFinanciallyRestricted` (the
// FINANCE-FAILURE-1A+1B cash-shortage grace period), even though
// `PublicDemoInternalTrainingTransaction.execute` already rejects a purchase
// during it. Since `PublicDemoAggregate.selectInternalTraining` is a silent
// no-op on that rejection (by design), the 研修する button previously stayed
// enabled and tappable with zero visible effect during a cash shortage —
// this pins the fix: the action is hidden with an explanatory reason during
// the shortage, exactly like the existing `isCloseBlocked`/`selected` cases.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_financial_status.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

import 'public_demo_tab_test_helpers.dart';

class _FixedSaveService extends PublicDemoSaveService {
  _FixedSaveService(this._aggregate);
  final PublicDemoAggregate _aggregate;

  @override
  Future<PublicDemoAggregate?> load() async => _aggregate;

  @override
  Future<void> save(PublicDemoAggregate aggregate) async {}

  @override
  Future<bool> clear() async => true;
}

/// Mirrors `withLegacyFoundingApplicants`'s own established technique
/// (`test/game/public_demo/test_support/public_demo_legacy_applicant_test_helpers.dart`)
/// for fabricating a specific state fact via the real `toJson`/`fromJson`
/// round trip, since `PublicDemoAggregate._copyWith` is private —
/// `financialStatus` itself is a plain persisted field with no unforgeable
/// authority attached, exactly like the precedent this mirrors
/// (`PublicDemoState.aprilStart().copyWith(financialStatus: ...)` in
/// `public_demo_01_home_recommended_action_test.dart`).
PublicDemoAggregate withFinancialStatus(
  PublicDemoAggregate aggregate,
  PublicDemoFinancialStatus status,
) {
  final json = aggregate.toJson();
  final stateJson = Map<String, dynamic>.from(json['state'] as Map);
  stateJson['financialStatus'] = status.name;
  return PublicDemoAggregate.fromJson({...json, 'state': stateJson});
}

void main() {
  testWidgets(
    '資金繰り悪化中（cashShortage）は研修ボタンが消え、理由と回復条件が表示される'
    '（カード自体は消えない）',
    (tester) async {
      final aggregate = withFinancialStatus(
        PublicDemoAggregate.initial(),
        PublicDemoFinancialStatus.cashShortage,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PublicDemo01PlaceholderScreen(
            saveService: _FixedSaveService(aggregate),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await switchPublicDemoTab(tester, PublicDemoTab.employees);

      final card = find.byKey(
        const Key('public-demo-internal-training-eng-01'),
      );
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();

      expect(card, findsOneWidget, reason: 'the card itself stays visible');
      expect(
        find.byKey(const Key('public-demo-internal-training-action-eng-01')),
        findsNothing,
        reason: 'the action must be hidden, never a dead tappable button',
      );
      expect(
        find.descendant(
          of: card,
          matching: find.text(
            '資金繰りが悪化しているため、今月は社内研修を利用できません。'
            '現預金が回復すると再び利用できます。',
          ),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '通常の資金状態（normal）では研修ボタンが表示され、上のメッセージは出ない',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PublicDemo01PlaceholderScreen()),
      );
      await tester.pumpAndSettle();
      await switchPublicDemoTab(tester, PublicDemoTab.employees);

      final card = find.byKey(
        const Key('public-demo-internal-training-eng-01'),
      );
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('public-demo-internal-training-action-eng-01')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.textContaining('資金繰りが悪化しているため'),
        ),
        findsNothing,
      );
    },
  );
}
