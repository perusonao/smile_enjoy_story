import '../../domain/models/programming_language.dart';
import 'public_demo_growth_engine.dart';

/// A presentation-neutral snapshot of one engineer's completed monthly growth.
///
/// This is deliberately smaller than [PublicDemoGrowthResult]: it is safe to
/// persist with [PublicDemoState] and lets EG-4 render the completed month
/// without re-running the growth engine.
class PublicDemoMonthlyGrowth {
  const PublicDemoMonthlyGrowth({
    required this.engineerId,
    required this.source,
    required this.primaryLanguage,
    required this.capabilityBefore,
    required this.capabilityAfter,
    required this.actualExperienceMonthsDelta,
    required this.industryExperienceMonthsDelta,
  });

  final String engineerId;
  final PublicDemoGrowthSource source;
  final ProgrammingLanguage primaryLanguage;
  final int capabilityBefore;
  final int capabilityAfter;
  final int actualExperienceMonthsDelta;
  final int industryExperienceMonthsDelta;

  Map<String, dynamic> toJson() => {
    'engineerId': engineerId,
    'source': source.name,
    'primaryLanguage': primaryLanguage.jsonValue,
    'capabilityBefore': capabilityBefore,
    'capabilityAfter': capabilityAfter,
    'actualExperienceMonthsDelta': actualExperienceMonthsDelta,
    'industryExperienceMonthsDelta': industryExperienceMonthsDelta,
  };

  factory PublicDemoMonthlyGrowth.fromJson(Map<String, dynamic> json) =>
      PublicDemoMonthlyGrowth(
        engineerId: json['engineerId'] as String,
        source: PublicDemoGrowthSource.values.byName(json['source'] as String),
        primaryLanguage: ProgrammingLanguage.fromJson(
          json['primaryLanguage'] as String,
        ),
        capabilityBefore: json['capabilityBefore'] as int,
        capabilityAfter: json['capabilityAfter'] as int,
        actualExperienceMonthsDelta: json['actualExperienceMonthsDelta'] as int,
        industryExperienceMonthsDelta:
            json['industryExperienceMonthsDelta'] as int,
      );
}
