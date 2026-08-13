import 'dart:math';
import '../../domain/domain.dart';
import '../models/models.dart';
import 'recruitment_interview_content.dart';
import 'rng.dart';

class RecruitmentInterviewEngine {
  const RecruitmentInterviewEngine._();

  static ApplicantValue applicantValue(Applicant a, int seed) {
    final weights = <ApplicantValue, int>{
      ApplicantValue.salaryFocused: a.desiredMonthlySalary ~/ 100000,
      ApplicantValue.growthFocused: a.hidden.growthPotential * 2,
      ApplicantValue.stabilityFocused: a.hidden.retention * 2,
      ApplicantValue.workLifeBalanceFocused: a.desiredWorkStyle.name == 'fullRemote' ? 12 : 4,
      ApplicantValue.careerFocused: max(a.techSkills.leader, a.techSkills.manager) * 2 + 2,
    };
    final rng = seededRandom(seed, 0, 'value:${a.id}');
    var roll = rng.nextInt(weights.values.fold(0, (x, y) => x + y));
    for (final entry in weights.entries) { roll -= entry.value; if (roll < 0) return entry.key; }
    return ApplicantValue.careerFocused;
  }

  static RecruitmentInterviewSession start({required int seed, required int week, required Applicant applicant, required int companyCredit, required OfficeType officeType, required int companySize}) {
    final value = applicantValue(applicant, seed);
    final rng = seededRandom(seed, week, 'interview:${applicant.id}');
    final salaryPressure = applicant.desiredMonthlySalary >= 500000 ? -5 : applicant.desiredMonthlySalary <= 320000 ? 4 : 0;
    final impression = (48 + rng.nextInt(17) + companyCredit ~/ 20 + officeConfigs[officeType]!.moraleModifier + min(companySize, 8) ~/ 2 + salaryPressure).clamp(0, 100);
    return RecruitmentInterviewSession(id: 'interview-${applicant.id}', applicantId: applicant.id, startedWeek: week, applicantValue: value, companyImpression: impression);
  }

  static RecruitmentInterviewSession ask({required RecruitmentInterviewSession session, required Applicant applicant, required int seed, required InterviewQuestionCategory category}) {
    if (session.completed || session.questionsComplete || session.selectedQuestions.contains(category)) return session;
    final answer = generateAnswer(applicant: applicant, seed: seed, category: category);
    final observation = observe(answer, applicant);
    final asked = [...session.selectedQuestions, category];
    final reverse = asked.length == 3 ? selectReverseQuestion(applicantValue: session.applicantValue, applicantId: applicant.id, seed: seed) : session.reverseQuestion;
    final gain = (10 + answer.specificity ~/ 12 + answer.consistency ~/ 18).clamp(10, 25);
    return session.copyWith(selectedQuestions: asked, applicantAnswers: [...session.applicantAnswers, answer], observations: [...session.observations, observation], candidateKnowledge: (session.candidateKnowledge + gain).clamp(0, 100), reverseQuestion: reverse);
  }

  static ApplicantAnswer generateAnswer({required Applicant applicant, required int seed, required InterviewQuestionCategory category}) {
    final rng = seededRandom(seed, 0, 'answer:${applicant.id}:${category.name}');
    final skill = applicant.skillFor(applicant.mainLanguage).actualSkill;
    final dishonesty = applicant.personality.dishonesty;
    final comm = applicant.personality.communication;
    int base;
    switch (category) {
      case InterviewQuestionCategory.technical: base = skill;
      case InterviewQuestionCategory.career: base = (applicant.techSkills.leader + applicant.techSkills.manager) * 10 + comm * 8;
      case InterviewQuestionCategory.reasonForChange: base = applicant.hidden.retention * 12 + applicant.personality.seriousness * 8;
      case InterviewQuestionCategory.teamwork: base = comm * 13 + applicant.personality.seriousness * 7;
      case InterviewQuestionCategory.futureCareer: base = applicant.hidden.growthPotential * 15 + applicant.personality.seriousness * 5;
      case InterviewQuestionCategory.workStyle: base = applicant.hidden.stressTolerance * 12 + comm * 5;
    }
    var specificity = (base + rng.nextInt(25) - 12 - dishonesty * 3).clamp(5, 95);
    var consistency = (base + rng.nextInt(21) - 10 - dishonesty * 5).clamp(5, 95);
    // Dishonesty is a tendency, not a guarantee: occasionally even a habitual
    // embellisher gives a grounded, checkable account.
    if (dishonesty >= 4 && rng.nextInt(5) == 0) {
      specificity = (specificity + 35).clamp(5, 95);
      consistency = (consistency + 35).clamp(5, 95);
    }
    final confidence = (comm * 13 + dishonesty * 9 + rng.nextInt(18)).clamp(10, 95);
    final credibility = ((specificity + consistency) ~/ 2 - max(0, confidence - specificity) ~/ 2).clamp(5, 95);
    final detailed = specificity >= 60;
    final vague = specificity < 38;
    final lang = applicant.mainLanguage.name;
    final variants = _answers(category, lang, applicant, detailed, vague, dishonesty >= 4 && confidence > specificity);
    final answer = variants[rng.nextInt(variants.length)];
    return ApplicantAnswer(category: category, question: interviewQuestionTexts[category]!, answer: answer, specificity: specificity, consistency: consistency, confidence: confidence, credibility: credibility);
  }

  static List<String> _answers(InterviewQuestionCategory c, String lang, Applicant a, bool detailed, bool vague, bool boasting) {
    switch (c) {
      case InterviewQuestionCategory.technical:
        if (detailed) return ['$langの業務システムでAPIとDB周りを担当し、遅い処理をログとSQLから切り分けました。', '最も難しかったのは$lang案件の性能改善です。計測してボトルネックを特定し、レビューを受けながら修正しました。', '要件が曖昧な機能で、利用者と確認しながら小さく実装して手戻りを抑えました。', '$langで既存機能を改修し、テストを追加してから段階的にリリースしました。'];
        if (boasting) return ['$langは大規模案件でかなり経験があります。設計から幅広く中心になって対応しました。', '難しい案件も多かったですが、技術面はほぼ私がリードして解決しました。', '$langなら一通り何でもできます。詳細はチーム全体で進めていました。', 'かなり重要な部分を任されていましたが、具体的な範囲は守秘義務で話しづらいです。'];
        return vague ? ['$langを使う開発で、主にチームの指示に沿って実装しました。', 'Webシステムで難しい課題があり、周囲と相談して対応しました。', '詳細設計と実装を担当しました。特に大きな問題なく完了しました。', '複数の機能を担当し、必要に応じて調査しながら進めました。'] : ['$langのWebシステムで、主に詳細設計と実装を担当しました。', '既存機能の改修で影響範囲の確認に苦労し、先輩と相談して進めました。', 'API開発を担当し、仕様確認とテストを意識して進めました。', 'チームで障害原因を調べ、担当部分の修正と確認を行いました。'];
      case InterviewQuestionCategory.career: return detailed ? ['実装から始め、最近はレビューと2〜3名の進捗確認も担当しました。', '詳細設計・実装・テストを中心に、顧客との仕様確認にも同席しました。', '担当機能の見積もりと実装、後輩のコードレビューを行いました。', 'メンバーとして開発しつつ、障害時は切り分け役を担当しました。'] : ['主に開発メンバーとして幅広く対応しました。', '案件ごとに必要な役割を柔軟に担当しました。', '設計からテストまで一通り経験しています。', 'チームの状況を見ながら開発を進めました。'];
      case InterviewQuestionCategory.reasonForChange: return a.hidden.turnoverIntent > 60 ? ['今の環境では希望する経験を積みにくく、新しい案件へ移りたいと考えました。', '評価や働き方を含め、より自分に合う環境を探しています。', '同じ仕事が続いたため、環境を変えて成長したいと思いました。', '条件と仕事内容の両方を見直したい時期だと考えました。'] : ['長く働きながら、今後伸ばしたい技術に近い案件へ挑戦したいためです。', '役割を広げられる環境で腰を据えて経験を積みたいと思いました。', 'これまでの経験を生かしつつ、次の専門性を作りたいからです。', '会社の方針変更を機に、将来像に合う環境を探しています。'];
      case InterviewQuestionCategory.teamwork: return detailed ? ['認識違いを議事録で整理し、担当者ごとに確認してから短い打合せで合意しました。', '障害時に責任追及を避け、ログと事実を共有して役割を分けました。', 'レビュー意見が割れたため、判断基準と期限を決めて小さく検証しました。', '遅れているメンバーと作業を分解し、早めにリーダーへ共有しました。'] : ['まず話を聞き、チームで相談して対応しました。', '状況を整理して上司へ報告しました。', 'できるだけ相手の立場を考えて解決しました。', '必要な人とコミュニケーションを取りました。'];
      case InterviewQuestionCategory.futureCareer: return a.hidden.growthPotential >= 4 ? ['技術の軸を作り、将来は設計判断を説明できるリードエンジニアになりたいです。', '実装力を高めつつ、要件整理から関われるエンジニアを目指します。', '得意分野を深め、後輩へ知識を共有できる役割を担いたいです。', '新しい技術を試すだけでなく、現場へ適用できる力を伸ばしたいです。'] : ['まずは今の経験を生かせる現場で安定して働きたいです。', '無理なく担当範囲を広げていきたいです。', '具体的にはまだ決めていませんが、経験を増やしたいです。', '任された仕事を着実にこなせるエンジニアでいたいです。'];
      case InterviewQuestionCategory.workStyle: return a.desiredWorkStyle.name == 'fullRemote' ? ['集中できるリモート中心を希望しますが、必要な対面の機会は相談できます。', '原則リモートを希望しています。成果と連絡の時間は明確にしたいです。', '通勤負担を抑えたいので、在宅中心の案件を探しています。', 'リモートでも進捗共有を細かく行える環境を希望します。'] : ['チームと相談しやすい働き方を希望し、案件に応じて出社も可能です。', 'ハイブリッドで集中と対話を両立できると理想です。', '働く場所より、無理のない稼働と役割の明確さを重視します。', '案件の状況に合わせますが、出社頻度は事前に確認したいです。'];
    }
  }

  static InterviewObservation observe(ApplicantAnswer answer, Applicant applicant) {
    final high = answer.credibility >= 65;
    final low = answer.credibility < 38;
    String text;
    if (answer.confidence - answer.specificity > 28) {
      text = '自信のある話し方だが、具体性に欠ける部分がある';
    } else if (low) {
      text = '説明と経歴書の間に、少し確認したい余白が残る';
    } else if (high && answer.specificity >= 65) {
      text = '具体例を交えており、経験に裏付けられた回答に感じる';
    } else if (answer.category == InterviewQuestionCategory.reasonForChange) {
      text = '転職理由には、まだ語られていない事情もありそうだ';
    } else if (answer.category == InterviewQuestionCategory.teamwork) {
      text = 'チーム内での関わり方をある程度イメージできる';
    } else if (answer.category == InterviewQuestionCategory.workStyle) {
      text = '働き方への希望が比較的はっきりしている';
    } else {
      text = '回答から人物像の一部が見えてきた';
    }
    return InterviewObservation(category: answer.category, text: text, confidence: high ? ObservationConfidence.high : low ? ObservationConfidence.low : ObservationConfidence.medium);
  }

  static ReverseQuestionCategory selectReverseQuestion({required ApplicantValue applicantValue, required String applicantId, required int seed}) {
    final preferred = switch (applicantValue) { ApplicantValue.salaryFocused => [ReverseQuestionCategory.salary, ReverseQuestionCategory.waiting], ApplicantValue.growthFocused => [ReverseQuestionCategory.careerGrowth, ReverseQuestionCategory.projectChoice], ApplicantValue.stabilityFocused => [ReverseQuestionCategory.companyStability, ReverseQuestionCategory.waiting], ApplicantValue.workLifeBalanceFocused => [ReverseQuestionCategory.remote, ReverseQuestionCategory.overtime], ApplicantValue.careerFocused => [ReverseQuestionCategory.projectChoice, ReverseQuestionCategory.careerGrowth] };
    final pool = [...preferred, ...preferred, ...ReverseQuestionCategory.values];
    return pool[seededRandom(seed, 0, 'reverse:$applicantId').nextInt(pool.length)];
  }

  static RecruitmentInterviewSession answerReverse(RecruitmentInterviewSession session, int choiceIndex) {
    if (!session.questionsComplete || session.companyAnswer != null || session.reverseQuestion == null) return session;
    final choices = companyAnswerChoices[session.reverseQuestion]!;
    if (choiceIndex < 0 || choiceIndex >= choices.length) return session;
    final choice = choices[choiceIndex];
    var delta = choice.quality;
    if (choice.suitedValues.contains(session.applicantValue)) delta += choice.quality >= 0 ? 5 : -4;
    final reaction = delta >= 10 ? '応募者は安心したようにうなずいた' : delta <= -8 ? '応募者は少し不安そうな表情を見せた' : '応募者は考えながら話を聞いている';
    return session.copyWith(companyAnswer: choice.text, applicantReaction: reaction, companyImpression: (session.companyImpression + delta).clamp(0, 100));
  }

  static String knowledgeLabel(int value) => value < 35 ? 'まだ判断材料が少ない' : value < 65 ? 'ある程度人物像が見えてきた' : 'かなり人物像をつかめた';
  static String impressionLabel(int value) => value <= 20 ? 'かなり興味が薄そう' : value <= 40 ? 'やや不安を感じている' : value <= 60 ? '判断を迷っているようだ' : value <= 80 ? 'かなり興味を持っている' : 'ぜひ入社したいと感じているようだ';
}
