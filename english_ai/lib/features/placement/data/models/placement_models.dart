// Data models for the CEFR placement test (v2).
//
// The backend returns a mix of typed dictionaries and dynamic section payloads,
// so these models focus on tolerant parsing rather than strict codegen.

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<dynamic> _list(dynamic value) {
  if (value is List) return value;
  return const <dynamic>[];
}

String _str(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  return value.toString();
}

double _double(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? fallback;
}

int _int(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? fallback;
}

List<String> _strings(dynamic value) {
  return _list(value).map((item) => item.toString()).toList();
}

// ──────────────────────────────────────────────
// Content / configuration
// ──────────────────────────────────────────────

class PlacementOptionModel {
  final String key;
  final String text;

  const PlacementOptionModel({required this.key, required this.text});

  factory PlacementOptionModel.fromJson(Map<String, dynamic> json) {
    final rawKey = _str(json['key']);
    final text = _str(json['text'], rawKey);
    return PlacementOptionModel(
      key: rawKey,
      text: text,
    );
  }
}

class PlacementPassageModel {
  final String title;
  final String text;

  const PlacementPassageModel({required this.title, required this.text});

  factory PlacementPassageModel.fromJson(Map<String, dynamic> json) {
    return PlacementPassageModel(
      title: _str(json['title']),
      text: _str(json['text']),
    );
  }

  bool get isEmpty => text.trim().isEmpty;
}

class PlacementItemModel {
  final String id;
  final String skill;
  final String level;
  final String type;
  final String stem;
  final List<PlacementOptionModel> options;
  final PlacementPassageModel? passage;
  final String? audioUrl;
  final int playLimit;
  final int timeSeconds;

  const PlacementItemModel({
    required this.id,
    required this.skill,
    required this.level,
    required this.type,
    required this.stem,
    required this.options,
    this.passage,
    this.audioUrl,
    this.playLimit = 2,
    this.timeSeconds = 60,
  });

  factory PlacementItemModel.fromJson(Map<String, dynamic> json) {
    final rawPassage = _map(json['passage']);
    return PlacementItemModel(
      id: _str(json['id']),
      skill: _str(json['skill']),
      level: _str(json['level'], 'B1'),
      type: _str(json['type'], 'mcq_single'),
      stem: _str(json['stem']),
      options: _list(json['options'])
          .map((item) => PlacementOptionModel.fromJson(_map(item)))
          .where((item) => item.key.isNotEmpty)
          .toList(),
      passage: rawPassage.isEmpty
          ? null
          : PlacementPassageModel.fromJson(rawPassage),
      audioUrl: (json['audio_url'] as String?)?.trim().isEmpty == true
          ? null
          : json['audio_url'] as String?,
      playLimit: _int(json['play_limit'], 2),
      timeSeconds: _int(json['time_seconds'], 60),
    );
  }

  bool get isMultiSelect => type == 'mcq_multi';
}

class PlacementWritingTaskModel {
  final String id;
  final String level;
  final String type;
  final String title;
  final String prompt;
  final String instructionsVi;
  final int minWords;
  final int maxWords;
  final int timeMinutes;

  const PlacementWritingTaskModel({
    required this.id,
    required this.level,
    required this.type,
    required this.title,
    required this.prompt,
    required this.instructionsVi,
    required this.minWords,
    required this.maxWords,
    required this.timeMinutes,
  });

  factory PlacementWritingTaskModel.fromJson(Map<String, dynamic> json) {
    return PlacementWritingTaskModel(
      id: _str(json['id']),
      level: _str(json['level'], 'B1'),
      type: _str(json['type'], 'essay'),
      title: _str(json['title']),
      prompt: _str(json['prompt']),
      instructionsVi: _str(json['instructions_vi']),
      minWords: _int(json['min_words'], 80),
      maxWords: _int(json['max_words'], 300),
      timeMinutes: _int(json['time_minutes'], 30),
    );
  }
}

class PlacementSpeakingTaskModel {
  final String id;
  final String level;
  final String type;
  final String title;
  final String prompt;
  final List<String> bullets;
  final String referenceText;
  final int prepSeconds;
  final int responseSeconds;

  const PlacementSpeakingTaskModel({
    required this.id,
    required this.level,
    required this.type,
    required this.title,
    required this.prompt,
    required this.bullets,
    required this.referenceText,
    required this.prepSeconds,
    required this.responseSeconds,
  });

  factory PlacementSpeakingTaskModel.fromJson(Map<String, dynamic> json) {
    return PlacementSpeakingTaskModel(
      id: _str(json['id']),
      level: _str(json['level'], 'B1'),
      type: _str(json['type'], 'monologue'),
      title: _str(json['title']),
      prompt: _str(json['prompt']),
      bullets: _strings(json['bullets']),
      referenceText: _str(json['reference_text']),
      prepSeconds: _int(json['prep_seconds'], 20),
      responseSeconds: _int(json['response_seconds'], 60),
    );
  }
}

class PlacementModeModel {
  final String key;
  final String label;
  final String description;
  final List<String> skills;
  final int stages;
  final int itemsPerStage;
  final int timeLimitSeconds;
  final int writingTasks;
  final int speakingTasks;

  const PlacementModeModel({
    required this.key,
    required this.label,
    required this.description,
    required this.skills,
    required this.stages,
    required this.itemsPerStage,
    required this.timeLimitSeconds,
    required this.writingTasks,
    required this.speakingTasks,
  });

  factory PlacementModeModel.fromJson(String key, Map<String, dynamic> json) {
    return PlacementModeModel(
      key: key,
      label: _str(json['label'], key),
      description: _str(json['description']),
      skills: _strings(json['skills']),
      stages: _int(json['stages'], 3),
      itemsPerStage: _int(json['items_per_stage'], 4),
      timeLimitSeconds: _int(json['time_limit_seconds'], 1200),
      writingTasks: _int(json['writing_tasks']),
      speakingTasks: _int(json['speaking_tasks']),
    );
  }

  int get receptiveItems => skills.length * stages * itemsPerStage;
  int get totalItems => receptiveItems + writingTasks + speakingTasks;
}

class PlacementConfigModel {
  final String version;
  final String description;
  final Map<String, String> skillLabels;
  final Map<String, PlacementModeModel> modes;
  final Map<String, double> cutScores;
  final Map<String, String> levelLabels;
  final Map<String, String> levelDescriptionsVi;
  final Map<String, dynamic> examMapping;
  final Map<String, dynamic> canDo;

  const PlacementConfigModel({
    required this.version,
    required this.description,
    required this.skillLabels,
    required this.modes,
    required this.cutScores,
    required this.levelLabels,
    required this.levelDescriptionsVi,
    required this.examMapping,
    required this.canDo,
  });

  factory PlacementConfigModel.fromJson(Map<String, dynamic> json) {
    final rawModes = _map(json['modes']);
    final modes = <String, PlacementModeModel>{};
    rawModes.forEach((key, value) {
      modes[key] = PlacementModeModel.fromJson(key, _map(value));
    });
    final rawCuts = _map(json['cut_scores']);
    final cuts = <String, double>{};
    rawCuts.forEach((key, value) => cuts[key] = _double(value));

    return PlacementConfigModel(
      version: _str(json['version'], '2.0.0'),
      description: _str(json['description']),
      skillLabels: _map(json['skill_labels'])
          .map((key, value) => MapEntry(key, _str(value, key))),
      modes: modes,
      cutScores: cuts,
      levelLabels: _map(json['level_labels'])
          .map((key, value) => MapEntry(key, _str(value, key))),
      levelDescriptionsVi: _map(json['level_descriptions_vi'])
          .map((key, value) => MapEntry(key, _str(value))),
      examMapping: _map(json['exam_mapping']),
      canDo: _map(json['can_do']),
    );
  }

  String skillLabel(String skill) => skillLabels[skill] ?? skill;
  String levelLabel(String level) => levelLabels[level] ?? level;
  String levelDescription(String level) =>
      levelDescriptionsVi[level] ?? '';
}

// ──────────────────────────────────────────────
// Session snapshot
// ──────────────────────────────────────────────

class PlacementSkillProgressModel {
  final bool completed;
  final double? theta;
  final double? se;

  const PlacementSkillProgressModel({
    required this.completed,
    this.theta,
    this.se,
  });

  factory PlacementSkillProgressModel.fromJson(Map<String, dynamic> json) {
    return PlacementSkillProgressModel(
      completed: json['completed'] == true,
      theta: json['theta'] == null ? null : _double(json['theta']),
      se: json['se'] == null ? null : _double(json['se']),
    );
  }
}

class PlacementProgressModel {
  final int answered;
  final int expectedItems;
  final double percent;
  final List<String> completedSkills;
  final Map<String, PlacementSkillProgressModel> skills;

  const PlacementProgressModel({
    required this.answered,
    required this.expectedItems,
    required this.percent,
    required this.completedSkills,
    required this.skills,
  });

  factory PlacementProgressModel.fromJson(Map<String, dynamic> json) {
    final rawSkills = _map(json['skills']);
    final skills = <String, PlacementSkillProgressModel>{};
    rawSkills.forEach((key, value) {
      skills[key] = PlacementSkillProgressModel.fromJson(_map(value));
    });
    return PlacementProgressModel(
      answered: _int(json['answered']),
      expectedItems: _int(json['expected_items']),
      percent: _double(json['percent']),
      completedSkills: _strings(json['completed_skills']),
      skills: skills,
    );
  }

  static const empty = PlacementProgressModel(
    answered: 0,
    expectedItems: 0,
    percent: 0,
    completedSkills: [],
    skills: {},
  );
}

class PlacementCurrentModel {
  final String section;
  final String skill;
  final int stage;
  final int stageCount;
  final String stageToken;
  final String? startedAt;
  final String? expiresAt;
  final int timeLimitSeconds;
  final int timeRemainingSeconds;
  final List<PlacementItemModel> items;
  final List<PlacementWritingTaskModel> writingTasks;
  final List<PlacementSpeakingTaskModel> speakingTasks;
  final Map<String, List<String>> answers;
  final List<String> submittedTaskIds;
  final Map<String, String> drafts;

  const PlacementCurrentModel({
    required this.section,
    required this.skill,
    required this.stage,
    required this.stageCount,
    required this.stageToken,
    this.startedAt,
    this.expiresAt,
    required this.timeLimitSeconds,
    required this.timeRemainingSeconds,
    required this.items,
    required this.writingTasks,
    required this.speakingTasks,
    required this.answers,
    required this.submittedTaskIds,
    required this.drafts,
  });

  factory PlacementCurrentModel.fromJson(Map<String, dynamic> json) {
    final rawAnswers = _map(json['answers']);
    final answers = <String, List<String>>{};
    rawAnswers.forEach((key, value) => answers[key] = _strings(value));
    final rawDrafts = _map(json['drafts']);
    final drafts = <String, String>{};
    rawDrafts.forEach((key, value) => drafts[key] = _str(value));

    return PlacementCurrentModel(
      section: _str(json['section'], 'done'),
      skill: _str(json['skill']),
      stage: _int(json['stage']),
      stageCount: _int(json['stage_count']),
      stageToken: _str(json['stage_token']),
      startedAt: json['started_at'] as String?,
      expiresAt: json['expires_at'] as String?,
      timeLimitSeconds: _int(json['time_limit_seconds']),
      timeRemainingSeconds: _int(json['time_remaining_seconds']),
      items: _list(json['items'])
          .map((item) => PlacementItemModel.fromJson(_map(item)))
          .toList(),
      writingTasks: _list(json['tasks'])
          .map((item) => PlacementWritingTaskModel.fromJson(_map(item)))
          .toList(),
      speakingTasks: _list(json['tasks'])
          .map((item) => PlacementSpeakingTaskModel.fromJson(_map(item)))
          .toList(),
      answers: answers,
      submittedTaskIds: _strings(json['submitted_task_ids']),
      drafts: drafts,
    );
  }

  static const empty = PlacementCurrentModel(
    section: 'done',
    skill: '',
    stage: 0,
    stageCount: 0,
    stageToken: '',
    timeLimitSeconds: 0,
    timeRemainingSeconds: 0,
    items: [],
    writingTasks: [],
    speakingTasks: [],
    answers: {},
    submittedTaskIds: [],
    drafts: {},
  );

  bool get isReceptive => section == 'receptive';
  bool get isWriting => section == 'writing';
  bool get isSpeaking => section == 'speaking';
}

class PlacementSessionModel {
  final String sessionId;
  final String mode;
  final String targetExam;
  final String status;
  final String blueprintVersion;
  final PlacementCurrentModel current;
  final PlacementProgressModel progress;
  final bool completed;
  final PlacementResultModel? result;
  final String? serverTime;

  const PlacementSessionModel({
    required this.sessionId,
    required this.mode,
    required this.targetExam,
    required this.status,
    required this.blueprintVersion,
    required this.current,
    required this.progress,
    required this.completed,
    this.result,
    this.serverTime,
  });

  factory PlacementSessionModel.fromJson(Map<String, dynamic> json) {
    final rawResult = json['result'];
    return PlacementSessionModel(
      sessionId: _str(json['session_id']),
      mode: _str(json['mode'], 'quick'),
      targetExam: _str(json['target_exam'], 'general'),
      status: _str(json['status'], 'in_progress'),
      blueprintVersion: _str(json['blueprint_version'], '2.0.0'),
      current: PlacementCurrentModel.fromJson(_map(json['current'])),
      progress: PlacementProgressModel.fromJson(_map(json['progress'])),
      completed: json['completed'] == true,
      result: rawResult == null
          ? null
          : PlacementResultModel.fromJson(_map(rawResult)),
      serverTime: json['server_time'] as String?,
    );
  }

  bool get isInProgress => status == 'in_progress';
}

// ──────────────────────────────────────────────
// Result
// ──────────────────────────────────────────────

class PlacementOverallModel {
  final String level;
  final double theta;
  final double se;
  final List<String> levelRange;
  final String confidence;
  final String confidenceVi;
  final String levelLabel;
  final String descriptionVi;

  const PlacementOverallModel({
    required this.level,
    required this.theta,
    required this.se,
    required this.levelRange,
    required this.confidence,
    required this.confidenceVi,
    required this.levelLabel,
    required this.descriptionVi,
  });

  factory PlacementOverallModel.fromJson(Map<String, dynamic> json) {
    return PlacementOverallModel(
      level: _str(json['level'], 'A1'),
      theta: _double(json['theta']),
      se: _double(json['se']),
      levelRange: _strings(json['level_range']),
      confidence: _str(json['confidence'], 'medium'),
      confidenceVi: _str(json['confidence_vi'], 'Trung bình'),
      levelLabel: _str(json['level_label']),
      descriptionVi: _str(json['description_vi']),
    );
  }
}

class PlacementProductiveTaskModel {
  final String taskId;
  final String level;
  final Map<String, double> criteria;
  final double average;
  final String feedback;
  final List<String> strengths;
  final List<String> improvements;
  final int wordCount;
  final String? transcript;
  final double? pronunciationScore;
  final String engine;

  const PlacementProductiveTaskModel({
    required this.taskId,
    required this.level,
    required this.criteria,
    required this.average,
    required this.feedback,
    required this.strengths,
    required this.improvements,
    required this.wordCount,
    this.transcript,
    this.pronunciationScore,
    required this.engine,
  });

  factory PlacementProductiveTaskModel.fromJson(Map<String, dynamic> json) {
    final rawCriteria = _map(json['criteria']);
    final criteria = <String, double>{};
    rawCriteria.forEach((key, value) => criteria[key] = _double(value));
    return PlacementProductiveTaskModel(
      taskId: _str(json['task_id']),
      level: _str(json['level'], 'B1'),
      criteria: criteria,
      average: _double(json['average']),
      feedback: _str(json['feedback']),
      strengths: _strings(json['strengths']),
      improvements: _strings(json['improvements']),
      wordCount: _int(json['word_count']),
      transcript: json['transcript'] as String?,
      pronunciationScore: json['pronunciation_score'] == null
          ? null
          : _double(json['pronunciation_score']),
      engine: _str(json['engine'], 'ai'),
    );
  }
}

class PlacementSkillResultModel {
  final String key;
  final String label;
  final String level;
  final double theta;
  final double se;
  final List<String> levelRange;
  final String type;
  final int correct;
  final int total;
  final double percent;
  final double weight;
  final List<String> canDo;
  final double? rubricAverage;
  final Map<String, double> criteria;
  final List<PlacementProductiveTaskModel> tasks;

  const PlacementSkillResultModel({
    required this.key,
    required this.label,
    required this.level,
    required this.theta,
    required this.se,
    required this.levelRange,
    required this.type,
    required this.correct,
    required this.total,
    required this.percent,
    required this.weight,
    required this.canDo,
    this.rubricAverage,
    required this.criteria,
    required this.tasks,
  });

  factory PlacementSkillResultModel.fromJson(
    String key,
    Map<String, dynamic> json,
  ) {
    final rawCriteria = _map(json['criteria']);
    final criteria = <String, double>{};
    rawCriteria.forEach((key, value) => criteria[key] = _double(value));
    return PlacementSkillResultModel(
      key: key,
      label: _str(json['label'], key),
      level: _str(json['level'], 'A1'),
      theta: _double(json['theta']),
      se: _double(json['se']),
      levelRange: _strings(json['level_range']),
      type: _str(json['type'], 'receptive'),
      correct: _int(json['correct']),
      total: _int(json['total']),
      percent: _double(json['percent']),
      weight: _double(json['weight']),
      canDo: _strings(json['can_do']),
      rubricAverage: json['rubric_average'] == null
          ? null
          : _double(json['rubric_average']),
      criteria: criteria,
      tasks: _list(json['tasks'])
          .map((item) => PlacementProductiveTaskModel.fromJson(_map(item)))
          .toList(),
    );
  }

  bool get isProductive => type == 'productive';
}

class PlacementStrengthModel {
  final String skill;
  final String label;
  final String level;
  final String note;

  const PlacementStrengthModel({
    required this.skill,
    required this.label,
    required this.level,
    required this.note,
  });

  factory PlacementStrengthModel.fromJson(Map<String, dynamic> json) {
    return PlacementStrengthModel(
      skill: _str(json['skill']),
      label: _str(json['label'], json['skill'] ?? ''),
      level: _str(json['level'], 'A1'),
      note: _str(json['note']),
    );
  }

  bool get isWeakness => false;
}

class PlacementRoadmapStepModel {
  final String skill;
  final String label;
  final String level;
  final String priority;
  final String action;
  final String route;

  const PlacementRoadmapStepModel({
    required this.skill,
    required this.label,
    required this.level,
    required this.priority,
    required this.action,
    required this.route,
  });

  factory PlacementRoadmapStepModel.fromJson(Map<String, dynamic> json) {
    return PlacementRoadmapStepModel(
      skill: _str(json['skill']),
      label: _str(json['label'], json['skill'] ?? ''),
      level: _str(json['level'], 'A1'),
      priority: _str(json['priority'], 'maintain'),
      action: _str(json['action']),
      route: _str(json['route'], '/learn'),
    );
  }

  bool get isHighPriority => priority == 'high';
}

class PlacementReviewItemModel {
  final String itemId;
  final String skill;
  final String level;
  final String stem;
  final List<String> selected;
  final List<String> correct;
  final bool isCorrect;
  final String explanationVi;

  const PlacementReviewItemModel({
    required this.itemId,
    required this.skill,
    required this.level,
    required this.stem,
    required this.selected,
    required this.correct,
    required this.isCorrect,
    required this.explanationVi,
  });

  factory PlacementReviewItemModel.fromJson(Map<String, dynamic> json) {
    return PlacementReviewItemModel(
      itemId: _str(json['item_id']),
      skill: _str(json['skill']),
      level: _str(json['level'], 'A1'),
      stem: _str(json['stem']),
      selected: _strings(json['selected']),
      correct: _strings(json['correct']),
      isCorrect: json['is_correct'] == true,
      explanationVi: _str(json['explanation_vi']),
    );
  }
}

class PlacementResultModel {
  final String resultId;
  final String sessionId;
  final String mode;
  final String targetExam;
  final String blueprintVersion;
  final String completedAt;
  final PlacementOverallModel overall;
  final Map<String, PlacementSkillResultModel> skills;
  final List<PlacementStrengthModel> strengths;
  final List<PlacementStrengthModel> weaknesses;
  final String profileConsistency;
  final String recommendation;
  final List<PlacementRoadmapStepModel> roadmap;
  final Map<String, String> examEquivalents;
  final Map<String, List<String>> canDo;
  final List<PlacementReviewItemModel> review;
  final int xpAwarded;

  const PlacementResultModel({
    required this.resultId,
    required this.sessionId,
    required this.mode,
    required this.targetExam,
    required this.blueprintVersion,
    required this.completedAt,
    required this.overall,
    required this.skills,
    required this.strengths,
    required this.weaknesses,
    required this.profileConsistency,
    required this.recommendation,
    required this.roadmap,
    required this.examEquivalents,
    required this.canDo,
    required this.review,
    required this.xpAwarded,
  });

  factory PlacementResultModel.fromJson(Map<String, dynamic> json) {
    final rawSkills = _map(json['skills']);
    final skills = <String, PlacementSkillResultModel>{};
    rawSkills.forEach((key, value) {
      skills[key] = PlacementSkillResultModel.fromJson(key, _map(value));
    });
    final rawEq = _map(json['exam_equivalents']);
    final equivalents = <String, String>{};
    rawEq.forEach((key, value) => equivalents[key] = _str(value));

    final rawCanDo = json['can_do'];
    final canDo = <String, List<String>>{};
    if (rawCanDo is Map) {
      rawCanDo.forEach((key, value) {
        canDo[key.toString()] = _strings(value);
      });
    } else if (rawCanDo is List) {
      canDo['all'] = _strings(rawCanDo);
    }

    return PlacementResultModel(
      resultId: _str(json['result_id']),
      sessionId: _str(json['session_id']),
      mode: _str(json['mode'], 'quick'),
      targetExam: _str(json['target_exam'], 'general'),
      blueprintVersion: _str(json['blueprint_version'], '2.0.0'),
      completedAt: _str(json['completed_at']),
      overall: PlacementOverallModel.fromJson(_map(json['overall'])),
      skills: skills,
      strengths: _list(json['strengths'])
          .map((item) => PlacementStrengthModel.fromJson(_map(item)))
          .toList(),
      weaknesses: _list(json['weaknesses'])
          .map((item) => PlacementStrengthModel.fromJson(_map(item)))
          .toList(),
      profileConsistency: _str(json['profile_consistency'], 'consistent'),
      recommendation: _str(json['recommendation']),
      roadmap: _list(json['roadmap'])
          .map((item) => PlacementRoadmapStepModel.fromJson(_map(item)))
          .toList(),
      examEquivalents: equivalents,
      canDo: canDo,
      review: _list(json['review'])
          .map((item) => PlacementReviewItemModel.fromJson(_map(item)))
          .toList(),
      xpAwarded: _int(json['xp_awarded']),
    );
  }

  PlacementSkillResultModel? skill(String key) => skills[key];
}

class PlacementHistoryEntryModel {
  final String resultId;
  final String sessionId;
  final String mode;
  final String targetExam;
  final String overallLevel;
  final double overallTheta;
  final double overallSe;
  final String completedAt;

  const PlacementHistoryEntryModel({
    required this.resultId,
    required this.sessionId,
    required this.mode,
    required this.targetExam,
    required this.overallLevel,
    required this.overallTheta,
    required this.overallSe,
    required this.completedAt,
  });

  factory PlacementHistoryEntryModel.fromJson(Map<String, dynamic> json) {
    return PlacementHistoryEntryModel(
      resultId: _str(json['result_id']),
      sessionId: _str(json['session_id']),
      mode: _str(json['mode'], 'quick'),
      targetExam: _str(json['target_exam'], 'general'),
      overallLevel: _str(json['overall_level'], 'A1'),
      overallTheta: _double(json['overall_theta']),
      overallSe: _double(json['overall_se']),
      completedAt: _str(json['completed_at']),
    );
  }

  DateTime? get completedDate => DateTime.tryParse(completedAt)?.toLocal();
}
