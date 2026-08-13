/// A lightweight, playful "what kind of company did you run" read shown on
/// the week-26 result screen (§23). Purely cosmetic — not used anywhere in
/// simulation logic, so the classification heuristic can stay simple.
enum CompanyType {
  steady, // 堅実経営型
  aggressiveHiring, // 積極採用型
  highUtilization, // 高稼働型
  overstaffedWaiting, // 待機過大型
  highProfit; // 高収益型

  String get label => switch (this) {
    CompanyType.steady => '堅実経営型',
    CompanyType.aggressiveHiring => '積極採用型',
    CompanyType.highUtilization => '高稼働型',
    CompanyType.overstaffedWaiting => '待機過大型',
    CompanyType.highProfit => '高収益型',
  };

  String get description => switch (this) {
    CompanyType.steady => '大きな波はなく、着実に経営を続けました。',
    CompanyType.aggressiveHiring => '積極的な採用でチームを大きく拡大しました。',
    CompanyType.highUtilization => 'ほとんどの社員が常に案件で稼働していました。',
    CompanyType.overstaffedWaiting => '待機期間が長く、人件費が重荷になっていました。',
    CompanyType.highProfit => '高い利益率で経営できました。',
  };
}
