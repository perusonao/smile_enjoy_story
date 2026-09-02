import 'package:flutter/foundation.dart';

import '../../../ui/asset_paths.dart';
import 'home_recommended_action.dart';

/// The navigator's expression vocabulary (NAVIGATOR-1A).
///
/// The full set is declared here because it is the *identity* of the
/// character, not a feature: naming only the one value 1A ships would mean
/// the later phases either rename this type or bolt a second one beside it.
/// Declaring it does not implement it — see
/// [HomeNavigatorIdentity.portraitAssetFor], which resolves an asset for
/// [normal] alone and returns `null` for every other value, so an
/// expression this phase has no artwork for degrades through exactly the
/// same path as an asset that fails to decode.
///
/// **NAVIGATOR-1A uses [normal] and nothing else.** No code in this phase
/// selects an expression from game state, and there is deliberately no
/// function anywhere that maps a `PublicDemoState` to one of these.
enum NavigatorExpression { normal, smile, worried, warning, celebration }

/// 佐倉 ひより — the Public Demo's fixed navigator.
///
/// **She is not a new employee.** The Public Demo's founding team is two
/// engineers plus one general-affairs employee, and that third person
/// already exists in the domain and in finance: `PublicDemoState.adminCount`
/// is 1 from `aprilStart()`, and `PublicDemoSalary.adminMonthlySalary`
/// (¥200,000) is already inside `baselineMonthlyExpenses`. This class gives
/// that existing employee a face and a name and does nothing else. Nothing
/// here changes a headcount, a payroll line, a save field, or a domain
/// value — there is no path from this file into any of them.
///
/// It is also deliberately a bag of constants rather than a projection
/// built from state. HOME-RUNTIME-2B and 2C both resolve their display in
/// the owning screen because what they show depends on the authority; this
/// one does not depend on the authority at all, which is the whole point of
/// 1A. Making it a `fromPublicDemoState` factory would create the state
/// coupling the phase exists to avoid, one phase early.
class HomeNavigatorIdentity {
  const HomeNavigatorIdentity._();

  /// Displayed name. The space is part of it — 姓 and 名 are separated the
  /// same way the S.E.S. employee badge in the character reference does it.
  static const String name = '佐倉 ひより';

  /// Shown nowhere in 1A's UI; kept beside [name] so the romanisation has
  /// one home if a later phase needs it.
  static const String romanizedName = 'Hiyori Sakura';

  /// Her department. The same 総務 the domain already counts as
  /// `adminCount`.
  static const String role = '総務';

  /// 1A's single fixed line.
  ///
  /// It is a constant on purpose. Selecting a message from game state —
  /// finance warnings, sales or recruitment suggestions, month-specific
  /// text — is NAVIGATOR-1B and later; this phase introduces the character
  /// to the world and says nothing that could contradict the Recommended
  /// Action above her.
  static const String greeting = '総務の佐倉です。今月もよろしくお願いします。';

  /// Portrait for [expression], or `null` when this phase ships no artwork
  /// for it.
  ///
  /// Presentation-only in both directions: the returned path is a bundled
  /// asset string that never reaches a domain model, a save file, or a
  /// finance calculation, and nothing in the domain can influence which
  /// value comes back.
  static String? portraitAssetFor(NavigatorExpression expression) =>
      switch (expression) {
        NavigatorExpression.normal => AssetPaths.navigatorNormal,
        NavigatorExpression.worried => AssetPaths.navigatorCaution,
        // NAVIGATOR-1A ships one image. Callers must treat null as "draw the
        // fallback", which is what HomeNavigatorSection does.
        NavigatorExpression.smile ||
        NavigatorExpression.warning ||
        NavigatorExpression.celebration => null,
      };
}

/// Presentation copy for the Navigator's inline advice bubble.
///
/// This is presentation data only. NAVIGATOR-1C's adapter receives an
/// already-resolved HOME slot; it never reads game state, ranks candidates,
/// or reconstructs an action.
enum HomeNavigatorAdviceSemantic { neutral, caution }

/// Maps already-resolved Navigator presentation semantics to artwork.
///
/// This is intentionally a pure presentation mapper. It neither accepts nor
/// reads game state, finance, workflow, calendar, save, navigation, or a
/// Recommended Action candidate.
NavigatorExpression navigatorExpressionFor(
  HomeNavigatorAdviceSemantic? semantic,
) => switch (semantic) {
  HomeNavigatorAdviceSemantic.caution => NavigatorExpression.worried,
  HomeNavigatorAdviceSemantic.neutral || null => NavigatorExpression.normal,
};

@immutable
class HomeNavigatorAdvice {
  const HomeNavigatorAdvice({
    required this.title,
    required this.message,
    this.explanation,
    this.semantic = HomeNavigatorAdviceSemantic.neutral,
    this.ctaLabel,
    this.onCtaPressed,
  }) : assert(
         (ctaLabel == null) == (onCtaPressed == null),
         'A Navigator CTA must carry both its label and its owner callback.',
       );

  final String title;
  final String message;

  /// Fixed educational presentation copy explaining why the already-resolved
  /// action matters. It never contains a new decision or a state inference.
  final String? explanation;
  final HomeNavigatorAdviceSemantic semantic;
  final String? ctaLabel;
  final VoidCallback? onCtaPressed;

  static const neutral = HomeNavigatorAdvice(
    title: 'ひよりからのご案内',
    message: '今すぐ必須の操作はありません。',
    explanation: 'SESでは、案件・人員・予定を確認しながら次の対応を進めます。新しい案内が出たら、その内容を確認してください。',
  );
}

/// Fixed educational copy for each already-resolved action kind.
///
/// This exhaustive presentation mapper deliberately receives only a kind.
/// It cannot inspect gameplay, finance, workflow, time, or any other state.
({String message, String explanation, HomeNavigatorAdviceSemantic semantic})
_guidanceCopyFor(HomeRecommendedActionKind kind) => switch (kind) {
  HomeRecommendedActionKind.cashShortageResponse => (
    message: '資金不足への対応を確認しましょう。',
    explanation: '事業を続けるには、必要な対応を確認してから次の手続きを進めることが大切です。',
    semantic: HomeNavigatorAdviceSemantic.caution,
  ),
  HomeRecommendedActionKind.summerBonusDecision => (
    message: '夏季賞与の支給内容を決めましょう。',
    explanation: '賞与は従業員への報酬に関する決定です。内容を確認し、既存の選択肢から方針を決めます。',
    semantic: HomeNavigatorAdviceSemantic.neutral,
  ),
  HomeRecommendedActionKind.raiseRequest => (
    message: '昇給要求への回答を確認しましょう。',
    explanation: '昇給の相談は、従業員との条件を確認する機会です。既存の選択肢を読んで回答を決めます。',
    semantic: HomeNavigatorAdviceSemantic.neutral,
  ),
  HomeRecommendedActionKind.employeeAcceptOrder ||
  HomeRecommendedActionKind.assignmentAcceptNextOrder ||
  HomeRecommendedActionKind.assignmentAcceptReplacementOrder ||
  HomeRecommendedActionKind.applicantJuneOrder => (
    message: '提示された案件の受注を進めましょう。',
    explanation: '受注の手続きは、案件への参画を確定するための操作です。内容を確認して既存の手続きを進めます。',
    semantic: HomeNavigatorAdviceSemantic.neutral,
  ),
  HomeRecommendedActionKind.employeeClientInterview ||
  HomeRecommendedActionKind.assignmentReplacementClientInterview ||
  HomeRecommendedActionKind.applicantClientInterview => (
    message: '客先面談の準備を進めましょう。',
    explanation: '客先面談は、案件への参画に向けて条件や適性を確認する機会です。表示される内容を確認して進めます。',
    semantic: HomeNavigatorAdviceSemantic.neutral,
  ),
  HomeRecommendedActionKind.employeePartnerInterview ||
  HomeRecommendedActionKind.assignmentReplacementPartnerInterview ||
  HomeRecommendedActionKind.applicantPartnerInterview => (
    message: '上位会社との面談を進めましょう。',
    explanation: '上位会社との面談は、案件紹介の次の確認手続きです。必要な情報を確認して進めます。',
    semantic: HomeNavigatorAdviceSemantic.neutral,
  ),
  HomeRecommendedActionKind.employeeIntroduceProject ||
  HomeRecommendedActionKind.assignmentIntroduceReplacementProject ||
  HomeRecommendedActionKind.applicantIntroduceProject => (
    message: '案件の紹介内容を確認しましょう。',
    explanation: '案件紹介では、参画候補となる仕事の内容を確認します。表示された案件情報を読んで進めます。',
    semantic: HomeNavigatorAdviceSemantic.neutral,
  ),
  HomeRecommendedActionKind.employeeResumeSelling ||
  HomeRecommendedActionKind.assignmentResumeReplacementSelling => (
    message: '別案件への営業を進めましょう。',
    explanation: '営業を再開すると、新しい案件との接点を作る手続きを進められます。表示される情報を確認してください。',
    semantic: HomeNavigatorAdviceSemantic.neutral,
  ),
  HomeRecommendedActionKind.employeeBeginSelling ||
  HomeRecommendedActionKind.assignmentBeginReplacementSelling ||
  HomeRecommendedActionKind.applicantBeginPreEntrySelling => (
    message: '営業を開始する準備を進めましょう。',
    explanation: '営業開始は、案件との接点を作るための最初の手続きです。対象者と内容を確認して進めます。',
    semantic: HomeNavigatorAdviceSemantic.neutral,
  ),
  HomeRecommendedActionKind.employeeSkillSheetReview ||
  HomeRecommendedActionKind.applicantBeginPreEntrySkillSheet => (
    message: 'SkillSheetの内容を確認しましょう。',
    explanation: 'SkillSheetは、経験やスキルを案件へ伝えるための資料です。内容を確認して次の手続きに備えます。',
    semantic: HomeNavigatorAdviceSemantic.neutral,
  ),
  HomeRecommendedActionKind.applicantSalaryOffer => (
    message: '給与提示の内容を確認しましょう。',
    explanation: '給与提示は、採用条件を伝える手続きです。表示された条件を確認して進めます。',
    semantic: HomeNavigatorAdviceSemantic.neutral,
  ),
  HomeRecommendedActionKind.applicantInterview => (
    message: '採用面談を進めましょう。',
    explanation: '採用面談は、候補者について確認する機会です。面談内容を確認して既存の手続きを進めます。',
    semantic: HomeNavigatorAdviceSemantic.neutral,
  ),
  HomeRecommendedActionKind.applicantReviewResume => (
    message: '経歴書の内容を確認しましょう。',
    explanation: '経歴書は、候補者の経験や経歴を確認するための資料です。内容を読んで次の手続きに進みます。',
    semantic: HomeNavigatorAdviceSemantic.neutral,
  ),
  HomeRecommendedActionKind.assignmentConfirmNextOrder => (
    message: '翌月分の発注内容を確認しましょう。',
    explanation: '次の発注を確認すると、継続する案件の手続きを進められます。表示された内容を確認してください。',
    semantic: HomeNavigatorAdviceSemantic.neutral,
  ),
  HomeRecommendedActionKind.recruitmentMedia => (
    message: '求人媒体の内容を確認しましょう。',
    explanation: '求人媒体は、候補者を募る方法を選ぶための画面です。表示された選択肢と内容を確認します。',
    semantic: HomeNavigatorAdviceSemantic.neutral,
  ),
  HomeRecommendedActionKind.recoveryAssignment => (
    message: '案件への復帰手続きを進めましょう。',
    explanation: '案件参画が決まった社員は、復帰の手続きを進めることで改めて案件へ参画できます。表示された内容を確認してください。',
    semantic: HomeNavigatorAdviceSemantic.neutral,
  ),
};

/// Purely translates HOME's already-resolved recommendation outcome.
/// It cannot inspect GameState, finance, month gates, terminal reasons, or
/// navigation. `null` preserves the authority's suppression outcome.
HomeNavigatorAdvice? navigatorAdviceFor(HomeRecommendedActionSlot slot) =>
    switch (slot) {
      HomeRecommendedActionSuppressed() => null,
      HomeRecommendedActionNone() => HomeNavigatorAdvice.neutral,
      HomeRecommendedActionAvailable(:final candidate) => () {
        final copy = _guidanceCopyFor(candidate.action.kind);
        return HomeNavigatorAdvice(
          title: 'ひよりからのご案内',
          message: '「${candidate.action.headline}」：${copy.message}',
          explanation: copy.explanation,
          semantic: copy.semantic,
          ctaLabel: candidate.action.ctaLabel,
          onCtaPressed: candidate.invoke,
        );
      }(),
    };
