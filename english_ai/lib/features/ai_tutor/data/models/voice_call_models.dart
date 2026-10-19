import 'ai_tutor_models.dart';

enum CallStateEnum {
  connecting,
  listening,
  thinking,
  speaking,
  ended,
}

class CallTurnModel {
  final String id;
  final String userText;
  final String aiText;
  final List<AICorrectionModel> corrections;
  final String? translationVi;
  final DateTime timestamp;
  final int turnIndex;

  const CallTurnModel({
    required this.id,
    required this.userText,
    required this.aiText,
    this.corrections = const [],
    this.translationVi,
    required this.timestamp,
    required this.turnIndex,
  });

  CallTurnModel copyWith({
    String? id,
    String? userText,
    String? aiText,
    List<AICorrectionModel>? corrections,
    String? translationVi,
    DateTime? timestamp,
    int? turnIndex,
  }) {
    return CallTurnModel(
      id: id ?? this.id,
      userText: userText ?? this.userText,
      aiText: aiText ?? this.aiText,
      corrections: corrections ?? this.corrections,
      translationVi: translationVi ?? this.translationVi,
      timestamp: timestamp ?? this.timestamp,
      turnIndex: turnIndex ?? this.turnIndex,
    );
  }
}

class VoiceCallSummaryModel {
  final String persona;
  final int durationSeconds;
  final int totalTurns;
  final List<AICorrectionModel> allCorrections;
  final List<CallTurnModel> turns;
  final int fluencyScore;
  final String feedbackVi;

  const VoiceCallSummaryModel({
    required this.persona,
    required this.durationSeconds,
    required this.totalTurns,
    this.allCorrections = const [],
    this.turns = const [],
    required this.fluencyScore,
    required this.feedbackVi,
  });

  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get personaDisplayName {
    switch (persona.toLowerCase()) {
      case 'harrison':
        return 'Mr. Harrison';
      case 'emma':
        return 'Emma (IELTS)';
      default:
        return 'Sarah';
    }
  }

  String get fluencyRating {
    if (fluencyScore >= 85) return 'Xuất sắc';
    if (fluencyScore >= 70) return 'Tự tin & Lưu loát';
    if (fluencyScore >= 55) return 'Khá tốt';
    return 'Cần luyện thêm phản xạ';
  }
}
