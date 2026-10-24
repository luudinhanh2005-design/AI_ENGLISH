// Data models for the IELTS Mock Test feature.
//
// The JSON shape is defined in docs/ielts_mock_test_contract.md.
// Keep field names in sync with the backend contract.

class MockTestSummary {
  final String id;
  final String type; // academic | general
  final String title;
  final String description;
  final int durationMinutes;
  final List<String> skills;

  const MockTestSummary({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.durationMinutes,
    required this.skills,
  });

  factory MockTestSummary.fromJson(Map<String, dynamic> json) {
    return MockTestSummary(
      id: _str(json['id']),
      type: _str(json['type'], fallback: 'academic'),
      title: _str(json['title']),
      description: _str(json['description']),
      durationMinutes: _int(json['duration_minutes'], fallback: 165),
      skills: _strList(json['skills']),
    );
  }

  String get typeLabel => type == 'general' ? 'General Training' : 'Academic';
}

class MockTestSet {
  final String id;
  final String type;
  final String title;
  final String description;
  final List<String> skills;
  final ListeningSection? listening;
  final ReadingSection? reading;
  final WritingSection? writing;
  final SpeakingSection? speaking;

  const MockTestSet({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.skills,
    this.listening,
    this.reading,
    this.writing,
    this.speaking,
  });

  factory MockTestSet.fromJson(Map<String, dynamic> json) {
    final sections = _map(json['sections']);
    return MockTestSet(
      id: _str(json['id']),
      type: _str(json['type'], fallback: 'academic'),
      title: _str(json['title']),
      description: _str(json['description']),
      skills: _strList(json['skills']),
      listening: sections['listening'] == null
          ? null
          : ListeningSection.fromJson(_map(sections['listening'])),
      reading: sections['reading'] == null
          ? null
          : ReadingSection.fromJson(_map(sections['reading'])),
      writing: sections['writing'] == null
          ? null
          : WritingSection.fromJson(_map(sections['writing'])),
      speaking: sections['speaking'] == null
          ? null
          : SpeakingSection.fromJson(_map(sections['speaking'])),
    );
  }

  String get typeLabel => type == 'general' ? 'General Training' : 'Academic';
}

// ─────────────────────────────────────────────────────────
// Shared question structures
// ─────────────────────────────────────────────────────────

class QuestionOption {
  final String key;
  final String text;

  const QuestionOption({required this.key, required this.text});

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      key: _str(json['key']),
      text: _str(json['text']),
    );
  }
}

class ExamQuestion {
  final String id;
  final int number;
  final String prompt;

  const ExamQuestion({
    required this.id,
    required this.number,
    required this.prompt,
  });

  factory ExamQuestion.fromJson(Map<String, dynamic> json) {
    return ExamQuestion(
      id: _str(json['id']),
      number: _int(json['number']),
      prompt: _str(json['prompt']),
    );
  }
}

class QuestionGroup {
  final String id;
  final String type;
  final String instructions;
  final List<QuestionOption> options;
  final List<ExamQuestion> questions;

  const QuestionGroup({
    required this.id,
    required this.type,
    required this.instructions,
    required this.options,
    required this.questions,
  });

  factory QuestionGroup.fromJson(Map<String, dynamic> json) {
    return QuestionGroup(
      id: _str(json['id']),
      type: _str(json['type']),
      instructions: _str(json['instructions']),
      options: _list(json['options'])
          .map((e) => QuestionOption.fromJson(_map(e)))
          .toList(),
      questions: _list(json['questions'])
          .map((e) => ExamQuestion.fromJson(_map(e)))
          .toList(),
    );
  }

  bool get isChoiceType =>
      type == 'mcq' ||
      type == 'matching' ||
      type == 'matching_headings' ||
      type == 'matching_information' ||
      type == 'map_labelling';

  bool get isTrueFalseType => type == 'tfng' || type == 'ynng';
}

// ─────────────────────────────────────────────────────────
// Listening
// ─────────────────────────────────────────────────────────

class ListeningSection {
  final int durationSeconds;
  final int reviewSeconds;
  final List<ListeningPart> parts;

  const ListeningSection({
    required this.durationSeconds,
    required this.reviewSeconds,
    required this.parts,
  });

  factory ListeningSection.fromJson(Map<String, dynamic> json) {
    return ListeningSection(
      durationSeconds: _int(json['duration_seconds'], fallback: 1800),
      reviewSeconds: _int(json['review_seconds'], fallback: 120),
      parts: _list(json['parts'])
          .map((e) => ListeningPart.fromJson(_map(e)))
          .toList(),
    );
  }

  int get totalQuestions =>
      parts.fold(0, (sum, part) => sum + part.totalQuestions);
}

class ListeningPart {
  final String id;
  final String title;
  final String audioUrl;
  final String instructions;
  final List<QuestionGroup> groups;

  const ListeningPart({
    required this.id,
    required this.title,
    required this.audioUrl,
    required this.instructions,
    required this.groups,
  });

  factory ListeningPart.fromJson(Map<String, dynamic> json) {
    return ListeningPart(
      id: _str(json['id']),
      title: _str(json['title']),
      audioUrl: _str(json['audio_url']),
      instructions: _str(json['instructions']),
      groups: _list(json['groups'])
          .map((e) => QuestionGroup.fromJson(_map(e)))
          .toList(),
    );
  }

  int get totalQuestions =>
      groups.fold(0, (sum, group) => sum + group.questions.length);
}

// ─────────────────────────────────────────────────────────
// Reading
// ─────────────────────────────────────────────────────────

class ReadingSection {
  final int durationSeconds;
  final List<ReadingPassage> passages;

  const ReadingSection({
    required this.durationSeconds,
    required this.passages,
  });

  factory ReadingSection.fromJson(Map<String, dynamic> json) {
    return ReadingSection(
      durationSeconds: _int(json['duration_seconds'], fallback: 3600),
      passages: _list(json['passages'])
          .map((e) => ReadingPassage.fromJson(_map(e)))
          .toList(),
    );
  }

  int get totalQuestions =>
      passages.fold(0, (sum, passage) => sum + passage.totalQuestions);
}

class ReadingPassage {
  final String id;
  final String title;
  final String text;
  final String instructions;
  final List<QuestionGroup> groups;

  const ReadingPassage({
    required this.id,
    required this.title,
    required this.text,
    required this.instructions,
    required this.groups,
  });

  factory ReadingPassage.fromJson(Map<String, dynamic> json) {
    return ReadingPassage(
      id: _str(json['id']),
      title: _str(json['title']),
      text: _str(json['text']),
      instructions: _str(json['instructions']),
      groups: _list(json['groups'])
          .map((e) => QuestionGroup.fromJson(_map(e)))
          .toList(),
    );
  }

  int get totalQuestions =>
      groups.fold(0, (sum, group) => sum + group.questions.length);
}

// ─────────────────────────────────────────────────────────
// Writing
// ─────────────────────────────────────────────────────────

class WritingSection {
  final int durationSeconds;
  final List<WritingTask> tasks;

  const WritingSection({
    required this.durationSeconds,
    required this.tasks,
  });

  factory WritingSection.fromJson(Map<String, dynamic> json) {
    return WritingSection(
      durationSeconds: _int(json['duration_seconds'], fallback: 3600),
      tasks: _list(json['tasks'])
          .map((e) => WritingTask.fromJson(_map(e)))
          .toList(),
    );
  }
}

class WritingTask {
  final String id;
  final int task;
  final int minWords;
  final int recommendedMinutes;
  final String prompt;
  final WritingVisual? visual;
  final List<String> guidance;

  const WritingTask({
    required this.id,
    required this.task,
    required this.minWords,
    required this.recommendedMinutes,
    required this.prompt,
    this.visual,
    this.guidance = const [],
  });

  factory WritingTask.fromJson(Map<String, dynamic> json) {
    return WritingTask(
      id: _str(json['id']),
      task: _int(json['task'], fallback: 1),
      minWords: _int(json['min_words'], fallback: 150),
      recommendedMinutes: _int(json['recommended_minutes'], fallback: 20),
      prompt: _str(json['prompt']),
      visual: json['visual'] == null
          ? null
          : WritingVisual.fromJson(_map(json['visual'])),
      guidance: _strList(json['guidance']),
    );
  }
}

class WritingVisual {
  final String type;
  final String title;
  final String description;
  final List<WritingDatum> data;

  const WritingVisual({
    required this.type,
    required this.title,
    required this.description,
    required this.data,
  });

  factory WritingVisual.fromJson(Map<String, dynamic> json) {
    return WritingVisual(
      type: _str(json['type']),
      title: _str(json['title']),
      description: _str(json['description']),
      data: _list(json['data'])
          .map((e) => WritingDatum.fromJson(_map(e)))
          .toList(),
    );
  }
}

class WritingDatum {
  final String label;
  final String value;

  const WritingDatum({required this.label, required this.value});

  factory WritingDatum.fromJson(Map<String, dynamic> json) {
    return WritingDatum(
      label: _str(json['label']),
      value: _str(json['value']),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Speaking
// ─────────────────────────────────────────────────────────

class SpeakingSection {
  final int durationSeconds;
  final List<SpeakingTopic> part1Topics;
  final SpeakingPart2 part2;
  final List<String> part3Questions;

  const SpeakingSection({
    required this.durationSeconds,
    required this.part1Topics,
    required this.part2,
    required this.part3Questions,
  });

  factory SpeakingSection.fromJson(Map<String, dynamic> json) {
    final part1 = _map(json['part1']);
    final part2 = _map(json['part2']);
    final part3 = _map(json['part3']);
    return SpeakingSection(
      durationSeconds: _int(json['duration_seconds'], fallback: 840),
      part1Topics: _list(part1['topics'])
          .map((e) => SpeakingTopic.fromJson(_map(e)))
          .toList(),
      part2: SpeakingPart2.fromJson(part2),
      part3Questions: _strList(part3['questions']),
    );
  }
}

class SpeakingTopic {
  final String id;
  final String topic;
  final List<String> questions;

  const SpeakingTopic({
    required this.id,
    required this.topic,
    required this.questions,
  });

  factory SpeakingTopic.fromJson(Map<String, dynamic> json) {
    return SpeakingTopic(
      id: _str(json['id']),
      topic: _str(json['topic']),
      questions: _strList(json['questions']),
    );
  }
}

class SpeakingPart2 {
  final String cueCard;
  final List<String> prompts;
  final int prepSeconds;
  final int speakSeconds;
  final List<String> followUps;

  const SpeakingPart2({
    required this.cueCard,
    required this.prompts,
    required this.prepSeconds,
    required this.speakSeconds,
    required this.followUps,
  });

  factory SpeakingPart2.fromJson(Map<String, dynamic> json) {
    return SpeakingPart2(
      cueCard: _str(json['cue_card']),
      prompts: _strList(json['prompts']),
      prepSeconds: _int(json['prep_seconds'], fallback: 60),
      speakSeconds: _int(json['speak_seconds'], fallback: 120),
      followUps: _strList(json['follow_ups']),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Attempts & results
// ─────────────────────────────────────────────────────────

class AttemptSectionPlan {
  final String skill;
  final int durationSeconds;
  final String status;

  const AttemptSectionPlan({
    required this.skill,
    required this.durationSeconds,
    required this.status,
  });

  factory AttemptSectionPlan.fromJson(Map<String, dynamic> json) {
    return AttemptSectionPlan(
      skill: _str(json['skill']),
      durationSeconds: _int(json['duration_seconds']),
      status: _str(json['status'], fallback: 'pending'),
    );
  }
}

class MockTestAttempt {
  final String id;
  final String setId;
  final String mode;
  final DateTime? startedAt;
  final List<AttemptSectionPlan> sections;
  final DateTime? completedAt;

  const MockTestAttempt({
    required this.id,
    required this.setId,
    required this.mode,
    this.startedAt,
    this.sections = const [],
    this.completedAt,
  });

  factory MockTestAttempt.fromJson(Map<String, dynamic> json) {
    return MockTestAttempt(
      id: _str(json['attempt_id'], fallback: _str(json['id'])),
      setId: _str(json['set_id']),
      mode: _str(json['mode'], fallback: 'strict'),
      startedAt: _date(json['started_at']),
      sections: _list(json['sections'])
          .map((e) => AttemptSectionPlan.fromJson(_map(e)))
          .toList(),
      completedAt: _date(json['completed_at']),
    );
  }

  bool get isStrict => mode == 'strict';
}

class QuestionReview {
  final String questionId;
  final int number;
  final String userAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final String explanation;

  const QuestionReview({
    required this.questionId,
    required this.number,
    required this.userAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    required this.explanation,
  });

  factory QuestionReview.fromJson(Map<String, dynamic> json) {
    return QuestionReview(
      questionId: _str(json['question_id']),
      number: _int(json['number']),
      userAnswer: _str(json['user_answer']),
      correctAnswer: _str(json['correct_answer']),
      isCorrect: json['is_correct'] == true,
      explanation: _str(json['explanation']),
    );
  }
}

class SectionScore {
  final String skill;
  final double band;
  final int? rawScore;
  final int? total;
  final Map<String, double> criteria;
  final String comment;
  final List<QuestionReview> details;
  final List<String> strengths;
  final List<String> improvements;
  final List<Map<String, dynamic>> corrections;
  final Map<String, dynamic> extra;

  const SectionScore({
    required this.skill,
    required this.band,
    this.rawScore,
    this.total,
    this.criteria = const {},
    this.comment = '',
    this.details = const [],
    this.strengths = const [],
    this.improvements = const [],
    this.corrections = const [],
    this.extra = const {},
  });

  factory SectionScore.fromJson(Map<String, dynamic> json) {
    final rawCriteria = _map(json['criteria']);
    return SectionScore(
      skill: _str(json['skill']),
      band: _double(json['band']),
      rawScore: json['raw_score'] == null ? null : _int(json['raw_score']),
      total: json['total'] == null ? null : _int(json['total']),
      criteria: rawCriteria.map(
        (key, value) => MapEntry(key, _double(value)),
      ),
      comment: _str(json['comment']),
      details: _list(json['details'])
          .map((e) => QuestionReview.fromJson(_map(e)))
          .toList(),
      strengths: _strList(json['strengths']),
      improvements: _strList(json['improvements']),
      corrections: _list(json['corrections'])
          .map((e) => _map(e))
          .toList(),
      extra: _map(json['extra']),
    );
  }

  String get skillLabel {
    switch (skill) {
      case 'listening':
        return 'Listening';
      case 'reading':
        return 'Reading';
      case 'writing':
        return 'Writing';
      case 'speaking':
        return 'Speaking';
      default:
        return skill;
    }
  }
}

class MockTestResult {
  final String attemptId;
  final double overallBand;
  final Map<String, SectionScore> skills;
  final int xpAwarded;
  final DateTime? completedAt;

  const MockTestResult({
    required this.attemptId,
    required this.overallBand,
    required this.skills,
    this.xpAwarded = 0,
    this.completedAt,
  });

  factory MockTestResult.fromJson(Map<String, dynamic> json) {
    final rawSkills = _map(json['skills']);
    return MockTestResult(
      attemptId: _str(json['attempt_id']),
      overallBand: _double(json['overall_band']),
      skills: rawSkills.map(
        (key, value) => MapEntry(key, SectionScore.fromJson(_map(value))),
      ),
      xpAwarded: _int(json['xp_awarded']),
      completedAt: _date(json['completed_at']),
    );
  }
}

class MockTestHistoryItem {
  final String attemptId;
  final String setId;
  final String title;
  final String type;
  final String mode;
  final String status;
  final double? overallBand;
  final DateTime? completedAt;
  final Map<String, double> skills;

  const MockTestHistoryItem({
    required this.attemptId,
    required this.setId,
    required this.title,
    required this.type,
    required this.mode,
    required this.status,
    this.overallBand,
    this.completedAt,
    this.skills = const {},
  });

  factory MockTestHistoryItem.fromJson(Map<String, dynamic> json) {
    final rawSkills = _map(json['skills']);
    return MockTestHistoryItem(
      attemptId: _str(json['attempt_id']),
      setId: _str(json['set_id']),
      title: _str(json['title']),
      type: _str(json['type'], fallback: 'academic'),
      mode: _str(json['mode'], fallback: 'strict'),
      status: _str(json['status'], fallback: 'completed'),
      overallBand:
          json['overall_band'] == null ? null : _double(json['overall_band']),
      completedAt: _date(json['completed_at']),
      skills: rawSkills.map((key, value) => MapEntry(key, _double(value))),
    );
  }

  String get typeLabel => type == 'general' ? 'General Training' : 'Academic';
}

// ─────────────────────────────────────────────────────────
// Small JSON helpers
// ─────────────────────────────────────────────────────────

String _str(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

int _int(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _double(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const <String, dynamic>{};
}

List<dynamic> _list(dynamic value) {
  if (value is List) return value;
  return const <dynamic>[];
}

List<String> _strList(dynamic value) {
  return _list(value)
      .map((e) => e?.toString().trim() ?? '')
      .where((e) => e.isNotEmpty)
      .toList();
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
