import '../../../ui/asset_paths.dart';

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
        // NAVIGATOR-1A ships one image. Callers must treat null as "draw the
        // fallback", which is what HomeNavigatorSection does.
        NavigatorExpression.smile ||
        NavigatorExpression.worried ||
        NavigatorExpression.warning ||
        NavigatorExpression.celebration => null,
      };
}
