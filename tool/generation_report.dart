// Dev-only reporting script — NOT part of the shipped app.
//
// Prints summary statistics for ApplicantGenerator/ProjectGenerator output
// so distribution tables in lib/domain/generation/ can be sanity-checked
// and rebalanced by eye. Run with:
//
//   dart run tool/generation_report.dart
//
// This intentionally lives outside lib/ so production code stays free of
// bulk `print` calls (see the Phase 0 design doc, section 25).
// ignore_for_file: avoid_print
import 'package:smile_enjoy_story/domain/domain.dart';

void main() {
  _reportApplicants();
  print('');
  _reportProjects();
}

void _reportApplicants() {
  const sampleSize = 1000;
  final applicants = ApplicantGenerator(seed: 2026).generate(sampleSize);

  print('=== Applicant Generation Report (n=$sampleSize) ===');

  final typeCounts = <ApplicantType, int>{};
  final languageCounts = <ProgrammingLanguage, int>{};
  var ageSum = 0;
  var salarySum = 0;
  var expMonthsSum = 0;
  var communicationSum = 0;
  var dishonestySum = 0;

  for (final a in applicants) {
    typeCounts[a.type] = (typeCounts[a.type] ?? 0) + 1;
    languageCounts[a.mainLanguage] = (languageCounts[a.mainLanguage] ?? 0) + 1;
    ageSum += a.age;
    salarySum += a.desiredMonthlySalary;
    expMonthsSum += a.totalItExperienceMonths;
    communicationSum += a.personality.communication;
    dishonestySum += a.personality.dishonesty;
  }

  print('-- type distribution --');
  for (final type in ApplicantType.values) {
    final count = typeCounts[type] ?? 0;
    print('  ${type.name.padRight(24)} ${_pct(count, sampleSize)}');
  }

  print('-- mainLanguage distribution --');
  for (final lang in ProgrammingLanguage.values) {
    final count = languageCounts[lang] ?? 0;
    print('  ${lang.name.padRight(24)} ${_pct(count, sampleSize)}');
  }

  print('-- averages --');
  print(
    '  age                      ${(ageSum / sampleSize).toStringAsFixed(1)}',
  );
  print(
    '  desiredMonthlySalary     ¥${(salarySum / sampleSize).toStringAsFixed(0)}',
  );
  print(
    '  totalItExperienceMonths  ${(expMonthsSum / sampleSize).toStringAsFixed(1)} '
    '(${(expMonthsSum / sampleSize / 12).toStringAsFixed(1)} yrs)',
  );
  print(
    '  communication            ${(communicationSum / sampleSize).toStringAsFixed(2)}',
  );
  print(
    '  dishonesty               ${(dishonestySum / sampleSize).toStringAsFixed(2)}',
  );
}

void _reportProjects() {
  const sampleSize = 1000;
  final projects = ProjectGenerator(
    seed: 2026,
    clients: sampleClients,
  ).generate(sampleSize);

  print('=== Project Generation Report (n=$sampleSize) ===');

  final typeCounts = <ProjectType, int>{};
  final rankCounts = <ProjectRank, int>{};
  final languageCounts = <ProgrammingLanguage, int>{};
  final clientCounts = <String, int>{};
  var rateSum = 0;

  for (final p in projects) {
    typeCounts[p.type] = (typeCounts[p.type] ?? 0) + 1;
    rankCounts[p.rank] = (rankCounts[p.rank] ?? 0) + 1;
    for (final l in p.requiredLanguages) {
      languageCounts[l] = (languageCounts[l] ?? 0) + 1;
    }
    clientCounts[p.clientId] = (clientCounts[p.clientId] ?? 0) + 1;
    rateSum += p.monthlyRate;
  }

  print('-- type distribution --');
  for (final type in ProjectType.values) {
    final count = typeCounts[type] ?? 0;
    print('  ${type.name.padRight(24)} ${_pct(count, sampleSize)}');
  }

  print('-- rank distribution --');
  for (final rank in ProjectRank.values) {
    final count = rankCounts[rank] ?? 0;
    print('  ${rank.name.padRight(24)} ${_pct(count, sampleSize)}');
  }

  print('-- average monthly rate --');
  print('  ¥${(rateSum / sampleSize).toStringAsFixed(0)}');

  print('-- required language distribution (of projects requiring one) --');
  for (final lang in ProgrammingLanguage.values) {
    final count = languageCounts[lang] ?? 0;
    if (count == 0) continue;
    print('  ${lang.name.padRight(24)} ${_pct(count, sampleSize)}');
  }

  print('-- projects by client --');
  for (final client in sampleClients) {
    final count = clientCounts[client.id] ?? 0;
    print('  ${client.name.padRight(24)} ${_pct(count, sampleSize)}');
  }
}

String _pct(int count, int total) {
  final pct = (count / total * 100).toStringAsFixed(1);
  return '${count.toString().padLeft(5)}  ($pct%)';
}
