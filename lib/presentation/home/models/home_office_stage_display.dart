import 'package:flutter/foundation.dart' show immutable;

import '../../../ui/asset_paths.dart';

// WHY THERE IS NO PER-EMPLOYEE STATUS HERE (HOME-RUNTIME-2B)
//
// An office scene that distinguished "at a client" from "in the office"
// would read better, and it was implemented first. It was then removed,
// because Public Demo 0.1 has three authorities for that fact and they are
// legitimately out of step with each other at different points in a month:
//
//  * `PublicDemoState.engineersAssigned` — the finance-side count the KPI
//    row directly above this section already renders. It advances at month
//    close.
//  * `PublicDemoWorkflowState.assignments` — the assignment roster, which
//    `assignOrderedForMay` does not build until `closeMay`. It is therefore
//    empty for the whole of May, while the count above already reads 1.
//  * `PublicDemoEngineerSales.stage == ordered` — the engineer's own won
//    order. It moves the instant the player wins one, and a joined
//    applicant who was `juneOrdered` becomes an engineer at the default
//    `waiting` stage, so this misses them.
//
// Picking one would have put a per-employee claim on screen that
// contradicts the KPI two rows above it in at least one month; reconciling
// them is Assignment/Domain work, which this phase must not touch. And
// restating the 参画/待機 split at all would undo HOME-RUNTIME-2A's rule
// that every fact has exactly one place on screen — the KPI owns that one.
//
// So the Office Stage shows who works here and how many there are, and
// leaves per-employee state to the Employee tab 2E is planned to add.
//
// HOME-COMPACT-1B.4 ADDS ONE AGGREGATE LINE — STILL NOT A PER-EMPLOYEE CLAIM
//
// The acceptance criteria for the 経営ダッシュボード visual target ask this
// section to be readable as a company summary on its own — headcount, plus
// whether anyone is currently idle — without requiring a scroll back up to
// the KPI row to answer either question. [employeeCount] and [waitingCount]
// below are the answer, and they do not reopen the question above: both are
// read from the exact same single authority the KPI's 社員/待機 tiles
// already use (`PublicDemoState.engineerCount` /
// `.engineersWaiting`), passed down verbatim by the owning screen — never a
// second count derived here, and never a per-employee "this one is
// waiting" label, which is the actual claim the note above explains this
// section cannot safely make. Optional and defaulted to `null` precisely so
// every existing construction site that has no aggregate to pass (in
// particular every widget-level test built directly from a member list)
// keeps rendering exactly as before this addition.

/// One employee as the Office Stage draws them (HOME-RUNTIME-2B) — a face
/// and a name, and deliberately nothing else (see the note above).
///
/// Presentation-only, like every other `presentation/home` model: this is
/// built *from* already-authoritative facts by the owning screen and never
/// becomes a second source of truth for them. In particular [id] is carried
/// only so the portrait pick can be keyed off a stable identity (see
/// [homeOfficeStagePortraitFor]) and so a rebuild cannot reshuffle the
/// scene — it is never used to address, mutate, or look anything up in
/// `PublicDemoWorkflowState`.
@immutable
class HomeOfficeStageMember {
  const HomeOfficeStageMember({
    required this.id,
    required this.name,
    this.portraitAssetPath,
  });

  /// The employee's authoritative id, used as the deterministic portrait
  /// key and nothing else.
  final String id;

  final String name;

  /// Bundled portrait asset, or `null` to draw the generic silhouette.
  ///
  /// Nullable on purpose even though [homeOfficeStagePortraitFor] always
  /// resolves to a real bundled asset today: it keeps the silhouette a
  /// representable, testable state rather than one that only appears if an
  /// image decode happens to fail at runtime.
  final String? portraitAssetPath;

  @override
  bool operator ==(Object other) =>
      other is HomeOfficeStageMember &&
      other.id == id &&
      other.name == name &&
      other.portraitAssetPath == portraitAssetPath;

  @override
  int get hashCode => Object.hash(id, name, portraitAssetPath);
}

/// Everything the Office Stage needs to draw one frame of the company
/// (HOME-RUNTIME-2B).
///
/// Read-only and total: the widget that renders this performs no selection,
/// no truncation arithmetic and no asset resolution of its own — all three
/// happen here, once, so that "which three people are on the stage" is a
/// property of the data and can be asserted directly.
@immutable
class HomeOfficeStageDisplay {
  const HomeOfficeStageDisplay({
    required this.members,
    this.backgroundAssetPath = AssetPaths.locationOfficeDayHomeBanner,
    this.employeeCount,
    this.waitingCount,
  });

  /// The company's employees in authoritative emission order — see
  /// [visibleMembers] for which of them actually appear.
  final List<HomeOfficeStageMember> members;

  /// The office scene behind the employees.
  ///
  /// HOME-COMPACT-1B.3 defaults this to [AssetPaths.locationOfficeDayHomeBanner]
  /// — a wide-aspect crop made specifically for this section's horizontal
  /// banner, with no text baked into the image. It is a constructor
  /// parameter rather than a constant inside the widget precisely so a
  /// later phase that introduces office tiers can choose the scene at this
  /// construction site, without the rendering widget gaining any knowledge
  /// of tiers — and without inventing an asset name that is not in the
  /// bundle today.
  final String backgroundAssetPath;

  /// How many employees the stage draws at most.
  ///
  /// The Office Stage is a glance at the company, not its roster: past
  /// three faces at 360pt the portraits stop being recognisable and the
  /// name labels start colliding. Employees beyond this are summarised by
  /// [hiddenMemberCount] instead of dropped silently.
  static const int visibleSlotCount = 3;

  /// The employees actually drawn, deterministically.
  ///
  /// The rule is "the first [visibleSlotCount] in authoritative emission
  /// order" — the same stable-scan tie-break HOME-RUNTIME-2C already uses
  /// for recommendation ranking. There is no sampling, no shuffling and no
  /// recency or score ordering anywhere in this path, so two builds of the
  /// same state always put the same three people on the stage, in the same
  /// slots.
  List<HomeOfficeStageMember> get visibleMembers =>
      members.take(visibleSlotCount).toList(growable: false);

  /// Employees present in the company but not drawn — surfaced as `+N名`
  /// so the scene never silently under-reports the headcount the KPI row
  /// above it states.
  int get hiddenMemberCount {
    final hidden = members.length - visibleSlotCount;
    return hidden > 0 ? hidden : 0;
  }

  /// The company's total headcount, or `null` to render no summary line at
  /// all — see the class-group doc above [HomeOfficeStageMember] for what
  /// this is (and, just as deliberately, is not) a claim about.
  final int? employeeCount;

  /// How many of [employeeCount] are currently idle, or `null` alongside
  /// [employeeCount] for no summary line.
  final int? waitingCount;

  /// Whether the short aggregate status line renders at all — both counts
  /// must be supplied together, since "3名 / 待機—" would read as a broken
  /// fact rather than an absent one.
  bool get hasHeadcountSummary => employeeCount != null && waitingCount != null;

  @override
  bool operator ==(Object other) =>
      other is HomeOfficeStageDisplay &&
      other.backgroundAssetPath == backgroundAssetPath &&
      other.employeeCount == employeeCount &&
      other.waitingCount == waitingCount &&
      _listEquals(other.members, members);

  @override
  int get hashCode => Object.hash(
    backgroundAssetPath,
    employeeCount,
    waitingCount,
    Object.hashAll(members),
  );

  static bool _listEquals(
    List<HomeOfficeStageMember> a,
    List<HomeOfficeStageMember> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// The founding team's hand-picked portraits.
///
/// These two ids (`eng-01` 佐藤 健, `eng-02` 鈴木 葵) are fixed constants of
/// Public Demo 0.1 — see `publicDemoInitialEngineers` — so an explicit pick
/// is genuinely possible for them, and is made to match the experience each
/// one's own `summary` already states (3 years Java/SQL, 2 years
/// JavaScript/Flutter). Every other employee is a generated hire whose id
/// is not known ahead of time and therefore goes through
/// [_genericPortraits].
const Map<String, String> _explicitPortraits = {
  'eng-01': AssetPaths.engineerMidlevel,
  'eng-02': AssetPaths.engineerJunior,
};

/// The generic engineer portraits, in a fixed order.
///
/// Only the `engineer_*` crops are eligible: the catalogue's other faces
/// are a recruiter, two sales staff, a client contact and an *applicant*,
/// none of which depicts an employee of the player's company.
const List<String> _genericPortraits = [
  AssetPaths.engineerJunior,
  AssetPaths.engineerMidlevel,
  AssetPaths.engineerVeteran,
];

/// Presentation-only portrait pick for one employee, by id.
///
/// Follows the same principle as the existing [portraitAssetFor] in
/// `ui/widgets/engineer_avatar.dart`: no `portraitId`, `imagePath` or
/// `asset` field is added to any Domain, Workflow or Save model, and
/// nothing here is persisted. The employee's already-permanent id is the
/// key, so a face is stable across rebuilds, across a save/load cycle, and
/// across app restarts, for free.
///
/// The chain is, in order:
///
///  1. an explicit mapping, where one exists ([_explicitPortraits]);
///  2. otherwise a deterministic generic portrait, chosen by a stable hash
///     of the id — not `id.hashCode`, which Dart does not guarantee to be
///     stable across runs or platforms, and which would therefore let a
///     face change between the VM and the web build of the same save;
///  3. the caller may pass `null` through to
///     [HomeOfficeStageMember.portraitAssetPath] for the silhouette, which
///     is also what the renderer falls back to if an asset fails to decode.
String homeOfficeStagePortraitFor(String employeeId) {
  final explicit = _explicitPortraits[employeeId];
  if (explicit != null) return explicit;
  return _genericPortraits[_stableHash(employeeId) % _genericPortraits.length];
}

/// FNV-1a over the id's UTF-16 code units, masked to 31 bits.
///
/// Deliberately hand-rolled and tiny: it must produce the *same* number on
/// the Dart VM and in the web build's JavaScript number semantics, which is
/// why it masks to 31 bits after every step rather than relying on 64-bit
/// integer wraparound.
int _stableHash(String value) {
  var hash = 0x811c9dc5;
  for (var i = 0; i < value.length; i++) {
    hash = (hash ^ value.codeUnitAt(i)) & 0x7fffffff;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}
