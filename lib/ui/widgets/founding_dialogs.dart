import 'package:flutter/material.dart';

import '../../game/game.dart';
import '../../presentation/events/event_image_mapper.dart';
import 'first_contract_celebration.dart';
import 'labels.dart';

/// Content for a one-time founding-tutorial dialog (celebration or
/// contextual explanation, §13-14, §19-20, §25, §37, §39, §47).
///
/// Also the common presentation for image-backed event modals (画像付き
/// イベントモーダル Phase 1): setting [imageAssetPath] (selected by
/// [EventImageMapper] — never a hardcoded `'assets/images/...'` string)
/// puts a full-width photo above [category]/[title] in
/// [showFoundingEventDialog]. Both [imageAssetPath] and [category] are
/// optional and default to `null`, so every existing plain-text dialog
/// (the tutorials that don't set them) renders exactly as before — Phase 1
/// only adds an image to the handful of events picked out in
/// `buildFoundingEventDialog`/`buildBeginnerModeDialog`, not to every
/// [OneTimeEvent]/[BeginnerMilestone] wholesale.
class FoundingEventDialog {
  final String title;
  final String body;
  final String primaryLabel;
  final bool celebration;

  /// Extra structured content shown under [body] (Playable 0.4C.3 §9) —
  /// used by the first-assignment celebration to surface unit price /
  /// gross margin / payment terms / first-payment estimate without
  /// cramming numbers into the plain-text body.
  final Widget? extra;

  /// An event image selected by [EventImageMapper] shown full-width above the
  /// title, or
  /// `null` for a plain text-only dialog (the pre-Phase-1 default look).
  final String? imageAssetPath;

  /// Short category label (e.g. "取引先からの連絡", "採用・応募") shown above
  /// [title] when [imageAssetPath] is set. Purely a presentation label —
  /// never read by game logic, so it carries no information [title]/[body]
  /// don't already state in full sentences (§9 accessibility: images and
  /// their labels are decoration, not the only place progression-relevant
  /// information appears).
  final String? category;

  const FoundingEventDialog({
    required this.title,
    required this.body,
    this.primaryLabel = 'OK',
    this.celebration = false,
    this.extra,
    this.imageAssetPath,
    this.category,
  });
}

/// Builds the dialog copy for [event] from the current [state]. Returns
/// `null` if there's nothing sensible to show (defensive — callers only
/// invoke this for events [ProgressionEngine.pendingEvents] already
/// confirmed are true).
FoundingEventDialog? buildFoundingEventDialog(
  OneTimeEvent event,
  GameState state,
) {
  switch (event) {
    case OneTimeEvent.interviewOfferCelebration:
      final offer =
          state.interviewOffers
              .where((o) => o.status == InterviewOfferStatus.pending)
              .firstOrNull ??
          state.interviewOffers.firstOrNull;
      if (offer == null) return null;
      final employee = state.engineers
          .where((e) => e.id == offer.employeeId)
          .firstOrNull;
      final project = state.openProjects
          .where((e) => e.project.id == offer.projectId)
          .firstOrNull
          ?.project;
      // Always source the sender from InterviewOffer.clientId — the
      // authoritative, always-populated field — never from a re-derived
      // `project?.clientId`, which silently goes empty the moment the
      // project itself has left `openProjects` (P1-2 fix). A `null` here
      // means [offer.clientId] itself doesn't resolve to a known client
      // (only possible on a corrupted/unrecognized save); render a
      // sensible fallback sentence rather than an empty-string prefix.
      final clientName = clientDisplayNameOrNull(offer.clientId);
      final senderLabel = clientName != null ? '$clientNameから' : '案件担当者から';
      return FoundingEventDialog(
        title: '🎉 面談依頼が届きました！',
        body:
            '$senderLabel\n'
            '${employee?.profile.name ?? '社員'}さんへ面談依頼があります。\n\n'
            '案件:\n${project?.title ?? '（詳細は面談依頼画面でご確認ください）'}',
        primaryLabel: '面談依頼を見る',
        celebration: true,
        imageAssetPath: EventImageMapper.imageAssetForCategory('取引先からの連絡'),
        category: '取引先からの連絡',
      );
    case OneTimeEvent.firstAssignmentCelebration:
      final assignment = state.activeAssignments.firstOrNull;
      final employee = assignment == null
          ? null
          : state.engineers
                .where((e) => e.id == assignment.engineerId)
                .firstOrNull;
      if (assignment == null || employee == null) return null;
      // Title/body left empty on purpose: for a player who reaches their
      // first assignment without playing the Founding Prologue (自由に開始),
      // this dialog *is* the flagship celebration the Prologue's own
      // completion screen otherwise gives (§20) — [FirstContractCelebration]
      // already carries its own headline, so a duplicate title here would
      // just repeat "🎉 初案件参画" twice in the same dialog.
      return FoundingEventDialog(
        title: '',
        body: '',
        primaryLabel: '会社状況を見る',
        celebration: true,
        extra: FirstContractCelebration(
          assignment: assignment,
          employee: employee,
        ),
      );
    case OneTimeEvent.recruitmentUnlockCelebration:
      return FoundingEventDialog(
        title: '🎉 新機能解放: 採用',
        body: '会社を拡大するため、新しいエンジニアを採用できるようになりました。',
        primaryLabel: '採用を見る',
        celebration: true,
        imageAssetPath: EventImageMapper.imageAssetForCategory('採用・応募'),
        category: '採用・応募',
      );
    case OneTimeEvent.clientInterviewCelebration:
      return FoundingEventDialog(
        title: '初めての客先面談が終わりました',
        body:
            '営業では不合格になることもあります。\n'
            'SkillSheetを見直すか、次の面談依頼を待ちましょう。',
        primaryLabel: 'OK',
        imageAssetPath: EventImageMapper.imageAssetForCategory('案件面談'),
        category: '案件面談',
      );
    case OneTimeEvent.recruitmentInterviewCelebration:
      return FoundingEventDialog(
        title: '初めての採用面接が終わりました',
        body: '採用面接の結果をもとに、内定を出すか判断できます。',
        primaryLabel: 'OK',
        imageAssetPath: EventImageMapper.imageAssetForCategory('採用・応募'),
        category: '採用・応募',
      );
    case OneTimeEvent.welfareUnlockCelebration:
      return FoundingEventDialog(
        title: '🎉 新機能解放: 社員環境 / 福利厚生',
        body:
            '会社は社員に案件を用意するだけではありません。\n'
            'PC、健康診断、賞与などへ投資すると、Moraleや会社へのTrustに影響します。',
        primaryLabel: '社員環境を見る',
        celebration: true,
        imageAssetPath: EventImageMapper.imageAssetForCategory('会社経営'),
        category: '会社経営',
      );
    case OneTimeEvent.firstOfferTutorial:
      return const FoundingEventDialog(
        title: '参画オファーとは',
        body:
            '選考を通過すると、正式な参画オファーが届きます。\n'
            '回答期限までに受諾するか辞退するか判断してください。',
      );
    case OneTimeEvent.firstArTutorial:
      final ar = state.accountsReceivable.lastOrNull;
      if (ar == null) return null;
      final client = FinanceEngine.clientById(ar.clientId);
      return FoundingEventDialog(
        title: '売上が発生しました',
        body:
            'ただし売上はすぐ現金になるとは限りません。\n\n'
            '${client.name}の支払サイト: ${client.paymentTermDays}日\n'
            '今回の売上は ${GameCalendar.monthEndLabel(ar.dueMonth)} に入金されます。',
      );
    case OneTimeEvent.fieldLeadTutorial:
      return const FoundingEventDialog(
        title: 'Field Lead とは',
        body:
            '現場に参画している社員から、増員予定などの案件情報が届くことがあります。\n'
            '会社への信頼が高い社員ほど、情報を持ち帰りやすくなります。',
      );
    case OneTimeEvent.contractRenewalTutorial:
      return const FoundingEventDialog(
        title: '契約更新の判断',
        body:
            '契約終了の4週間前になると、延長するか撤退するかを判断できます。\n'
            '本人の希望と異なる判断をすると、モチベーションや信頼に影響することがあります。',
      );
    case OneTimeEvent.clientUnlockTutorial:
      return const FoundingEventDialog(
        title: '新規取引先が増えました',
        body:
            '実績や信頼を積むことで、取引可能な会社が増えていきます。\n'
            '取引先が増えるほど、案件の選択肢も広がります。',
      );
  }
}

const TextStyle _celebrationTitleStyle = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.bold,
);
const TextStyle _plainTitleStyle = TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.bold,
);
final TextStyle _categoryStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.bold,
  letterSpacing: 0.5,
  color: Colors.blueGrey.shade600,
);

/// Shows [dialog] and returns `true` if the player tapped the primary
/// action (used by callers that then navigate somewhere on confirm).
///
/// Title/body are optional (Playable 0.4C.4 §20): a dialog whose [extra]
/// already carries its own headline (e.g. [FirstContractCelebration]) can
/// leave both empty rather than repeat itself above a second, identical
/// title.
///
/// When [FoundingEventDialog.imageAssetPath] is set (Phase 1 image-backed
/// event modal), the image is rendered edge-to-edge above
/// [FoundingEventDialog.category]/[FoundingEventDialog.title] instead of
/// using [AlertDialog.title] — that keeps the image full-width, unpadded by
/// the dialog's default title inset. Everything else (body, [extra],
/// actions) is unchanged from the plain-text layout: [AlertDialog.actions]
/// stays outside the scrollable area regardless, so the primary CTA is
/// always reachable even when the image pushes the text below the fold on
/// a short viewport (§3: "画像が大きすぎてCTAが画面外へ押し出されないように").
Future<bool> showFoundingEventDialog(
  BuildContext context,
  FoundingEventDialog dialog,
) async {
  final hasImage = dialog.imageAssetPath != null;
  // Only the image layout needs an explicit style here — it moved the
  // title out of AlertDialog.title (which supplied its own default text
  // style) into plain content, so it needs a stand-in default. The
  // no-image path keeps its pre-existing behavior exactly (`null` = the
  // theme's own AlertDialog title style) so none of the plain tutorial
  // dialogs change appearance.
  final imageTitleStyle = dialog.celebration
      ? _celebrationTitleStyle
      : _plainTitleStyle;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      // Material3's default Dialog shape is a 28px-radius rounded rect, but
      // Dialog itself defaults to clipBehavior: Clip.none — content isn't
      // actually clipped to that shape unless asked. Harmless for the
      // no-image path (its content stays padded well away from the edges),
      // but _EventImage sits flush against the top edge (contentPadding:
      // zero below), so without this its own corner rounding could paint
      // outside the dialog's rounded silhouette at the two top corners
      // (Codex review on PR #24). Clipping here — rather than hand-matching
      // _EventImage's own radius to 28px — stays correct even if the app's
      // dialog theme shape ever changes, since it defers to whatever shape
      // Material resolves instead of duplicating the value.
      clipBehavior: Clip.antiAlias,
      // `null` (the no-image branch) leaves Flutter's own default content
      // padding in place, unchanged from before this dialog supported
      // images. Only the image layout overrides it to zero, so the photo
      // can sit flush against the dialog's edges.
      contentPadding: hasImage ? EdgeInsets.zero : null,
      // Moving the title out of AlertDialog.title (image layout) also
      // moves its `Semantics(namesRoute: true)` — replace it with an
      // explicit semanticLabel so the dialog keeps an accessible name
      // built from the same category/title text a sighted player sees.
      semanticLabel: hasImage
          ? [
              if (dialog.category != null) dialog.category!,
              dialog.title,
            ].where((s) => s.isNotEmpty).join(' — ')
          : null,
      title: hasImage || dialog.title.isEmpty
          ? null
          : Text(
              dialog.title,
              style: dialog.celebration ? _celebrationTitleStyle : null,
            ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          // .stretch (not .start) at this outer level only: it's what lets
          // _EventImage fill the dialog's full width via ordinary
          // constraint-based layout (no explicit `width: double.infinity`
          // anywhere), the same way AlertDialog stretches its own Material3
          // content — the width/height explicitly set here comes purely
          // from those tight constraints, not from an unbounded value that
          // would fight `IntrinsicWidth` the way AspectRatio did (see
          // _EventImage's own doc comment). The inner Column below (title/
          // body text) keeps its own .start, so text still left-aligns.
          crossAxisAlignment: hasImage
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.start,
          children: [
            if (hasImage) _EventImage(assetPath: dialog.imageAssetPath!),
            Padding(
              padding: hasImage
                  ? const EdgeInsets.fromLTRB(20, 16, 20, 4)
                  : EdgeInsets.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasImage && dialog.category != null) ...[
                    Text(dialog.category!, style: _categoryStyle),
                    const SizedBox(height: 4),
                  ],
                  if (hasImage && dialog.title.isNotEmpty) ...[
                    Text(dialog.title, style: imageTitleStyle),
                    const SizedBox(height: 8),
                  ],
                  if (dialog.body.isNotEmpty) Text(dialog.body),
                  if (dialog.extra != null) ...[
                    if (dialog.body.isNotEmpty) const SizedBox(height: 14),
                    dialog.extra!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(dialog.primaryLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Full-width event photo at the top of an image-backed
/// [showFoundingEventDialog] (§3 layout spec): a moderate fixed height
/// (not the whole viewport — §3: "高さは固定しすぎない") with the image
/// filling that box via [BoxFit.cover], rather than [AspectRatio] — an
/// [AlertDialog]'s content sits inside Flutter's own `IntrinsicWidth`
/// (dialog.dart, sizes the dialog to its content), and [AspectRatio]'s
/// intrinsic-width computation from an unbounded height is a known
/// incompatibility with that ("'input.isFinite': is not true" at layout
/// time) — a fixed-height [SizedBox] has no such interaction.
///
/// Width is deliberately *not* set here (no `width: double.infinity` on
/// this [SizedBox] or the [Image] itself) — an explicit infinite width is
/// the same shape of value that made [AspectRatio] fail against
/// `IntrinsicWidth` above, so it's avoided defensively even though it
/// wasn't observed to reproduce the same crash. Instead this widget fills
/// its parent's width the ordinary, constraint-based way:
/// [showFoundingEventDialog] gives the [Column] that directly contains
/// this widget `crossAxisAlignment: CrossAxisAlignment.stretch`, so the
/// tight width constraint arrives from the parent — the same mechanism
/// [AlertDialog]'s own Material3 content [Column] already uses internally.
/// (Verified full-width at both 360px and 390px via an actual rendered
/// screenshot, not just the absence of a layout exception.)
///
/// [showFoundingEventDialog]'s scrollable content plus the CTA staying
/// outside that scroll area is what actually keeps the primary action
/// reachable regardless of image size (§3: CTA must never be pushed
/// off-screen).
///
/// Purely decorative (§9 accessibility): [category]/[title]/[body] already
/// say everything a player needs in text, so the image itself is excluded
/// from the semantics tree rather than read aloud as an unlabeled image.
class _EventImage extends StatelessWidget {
  const _EventImage({required this.assetPath});

  final String assetPath;

  static const double _height = 170;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: SizedBox(
          height: _height,
          child: Image.asset(assetPath, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
  T? get lastOrNull => isEmpty ? null : last;
}
