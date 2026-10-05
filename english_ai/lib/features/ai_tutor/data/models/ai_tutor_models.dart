class AICorrectionModel {
  final String original;
  final String correction;
  final String explanationVi;

  const AICorrectionModel({
    required this.original,
    required this.correction,
    required this.explanationVi,
  });

  factory AICorrectionModel.fromJson(Map<String, dynamic> json) {
    return AICorrectionModel(
      original: json['original'] as String? ?? '',
      correction: json['correction'] as String? ?? '',
      explanationVi: json['explanation_vi'] as String? ?? '',
    );
  }
}

class ChatMessageModel {
  final String id;
  final String role; // 'user' or 'assistant'
  final String content;
  final List<AICorrectionModel> corrections;
  final List<String> suggestedReplies;
  final DateTime createdAt;

  const ChatMessageModel({
    required this.id,
    required this.role,
    required this.content,
    this.corrections = const [],
    this.suggestedReplies = const [],
    required this.createdAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    final rawCorrections = json['corrections'] as List<dynamic>? ?? [];
    final rawSuggestions = json['suggested_replies'] as List<dynamic>? ?? [];

    return ChatMessageModel(
      id: json['id'] as String? ?? UniqueKey().toString(),
      role: json['role'] as String? ?? 'assistant',
      content: json['content'] as String? ?? '',
      corrections: rawCorrections
          .map((c) => AICorrectionModel.fromJson(c as Map<String, dynamic>))
          .toList(),
      suggestedReplies: rawSuggestions.map((s) => s.toString()).toList(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  bool get isUser => role == 'user';
}

class UniqueKey {
  static int _counter = 0;
  @override
  String toString() => 'msg_${DateTime.now().millisecondsSinceEpoch}_${++_counter}';
}
