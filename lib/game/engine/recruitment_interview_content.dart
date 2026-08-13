import '../models/recruitment_interview.dart';

const interviewQuestionTexts = <InterviewQuestionCategory, String>{
  InterviewQuestionCategory.technical: 'これまでで一番難しかった開発について教えてください',
  InterviewQuestionCategory.career: 'これまでどのような役割を担当してきましたか？',
  InterviewQuestionCategory.reasonForChange: '今回の転職理由を教えてください',
  InterviewQuestionCategory.teamwork: 'チームで問題が起きたとき、どう対応しましたか？',
  InterviewQuestionCategory.futureCareer: '今後どのようなエンジニアになりたいですか？',
  InterviewQuestionCategory.workStyle: '希望する働き方について教えてください',
};

const interviewQuestionLabels = <InterviewQuestionCategory, String>{
  InterviewQuestionCategory.technical: '技術経験', InterviewQuestionCategory.career: '役割・経歴',
  InterviewQuestionCategory.reasonForChange: '転職理由', InterviewQuestionCategory.teamwork: 'チームワーク',
  InterviewQuestionCategory.futureCareer: '将来像', InterviewQuestionCategory.workStyle: '働き方',
};

const reverseQuestionTexts = <ReverseQuestionCategory, String>{
  ReverseQuestionCategory.salary: '昇給や給与評価はどのようになっていますか？',
  ReverseQuestionCategory.projectChoice: '参画する案件は自分の希望を出せますか？',
  ReverseQuestionCategory.waiting: '待機期間中の給与はどうなりますか？',
  ReverseQuestionCategory.remote: 'リモート勤務の案件はありますか？',
  ReverseQuestionCategory.careerGrowth: 'スキルアップや研修について教えてください',
  ReverseQuestionCategory.overtime: '残業が多い案件もありますか？',
  ReverseQuestionCategory.companyStability: '創業したばかりとのことですが、経営は大丈夫でしょうか？',
};

class CompanyAnswerChoice {
  final String text;
  final int quality;
  final Set<ApplicantValue> suitedValues;
  const CompanyAnswerChoice(this.text, this.quality, this.suitedValues);
}

const companyAnswerChoices = <ReverseQuestionCategory, List<CompanyAnswerChoice>>{
  ReverseQuestionCategory.salary: [
    CompanyAnswerChoice('成果と役割を半年ごとに確認し、昇給へ反映します', 10, {ApplicantValue.salaryFocused, ApplicantValue.careerFocused}),
    CompanyAnswerChoice('会社の業績と案件単価を見ながら相談します', 0, {}),
    CompanyAnswerChoice('今は制度が小さいため、個別に話し合って決めます', -7, {ApplicantValue.stabilityFocused}),
  ],
  ReverseQuestionCategory.projectChoice: [
    CompanyAnswerChoice('希望を聞き、Fitを見ながら複数案件から一緒に選びます', 10, {ApplicantValue.careerFocused, ApplicantValue.growthFocused}),
    CompanyAnswerChoice('営業状況との兼ね合いですが、希望は必ず確認します', 2, {}),
    CompanyAnswerChoice('会社の判断を優先して参画先を決めます', -11, {ApplicantValue.stabilityFocused}),
  ],
  ReverseQuestionCategory.waiting: [
    CompanyAnswerChoice('待機中でも給与は満額支給します', 11, {ApplicantValue.stabilityFocused, ApplicantValue.salaryFocused}),
    CompanyAnswerChoice('待機を短くするため案件探しを一緒に進めます。給与は変わりません', 7, {ApplicantValue.careerFocused}),
    CompanyAnswerChoice('状況に応じて働き方を相談しますが、給与条件は維持します', 2, {}),
  ],
  ReverseQuestionCategory.remote: [
    CompanyAnswerChoice('リモート可の案件も探し、希望とのFitを重視します', 10, {ApplicantValue.workLifeBalanceFocused}),
    CompanyAnswerChoice('案件次第ですが、出社頻度の希望は営業時に伝えます', 2, {}),
    CompanyAnswerChoice('現状は出社案件を中心に考えています', -10, {ApplicantValue.stabilityFocused}),
  ],
  ReverseQuestionCategory.careerGrowth: [
    CompanyAnswerChoice('研修制度はまだありませんが、希望分野の案件選びと学習目標を支援します', 8, {ApplicantValue.growthFocused, ApplicantValue.careerFocused}),
    CompanyAnswerChoice('制度は準備中です。まず現場経験を積んでもらいます', 0, {}),
    CompanyAnswerChoice('基本的には各自で学習してもらう方針です', -10, {ApplicantValue.stabilityFocused}),
  ],
  ReverseQuestionCategory.overtime: [
    CompanyAnswerChoice('稼働状況を確認し、残業が続く案件は営業から調整します', 10, {ApplicantValue.workLifeBalanceFocused, ApplicantValue.stabilityFocused}),
    CompanyAnswerChoice('案件によりますが、面談前に分かる範囲は共有します', 1, {}),
    CompanyAnswerChoice('繁忙期の残業は成長機会としてお願いすることがあります', -11, {ApplicantValue.growthFocused}),
  ],
  ReverseQuestionCategory.companyStability: [
    CompanyAnswerChoice('小規模ですが資金と固定費を毎月管理し、無理な採用はしません', 10, {ApplicantValue.stabilityFocused}),
    CompanyAnswerChoice('創業期なので変化はありますが、数字は率直に共有します', 2, {ApplicantValue.growthFocused}),
    CompanyAnswerChoice('将来は大きく成長する予定なので心配ありません', -9, {ApplicantValue.salaryFocused}),
  ],
};
