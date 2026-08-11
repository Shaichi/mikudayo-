/// Model cho lịch sử hội thoại (sessions + turns).
library;

class SessionRecord {
  const SessionRecord({
    required this.id,
    required this.mode,
    required this.jlptLevel,
    this.scenario,
    this.summary,
    required this.createdAt,
    this.turnCount = 0,
  });

  final String id;
  final String mode;
  final String jlptLevel;
  final String? scenario;
  final String? summary;
  final String createdAt;
  final int turnCount;

  factory SessionRecord.fromJson(Map<String, dynamic> json) => SessionRecord(
        id: (json['id'] as String?) ?? '',
        mode: (json['mode'] as String?) ?? 'free_talk',
        jlptLevel: (json['jlpt_level'] as String?) ?? 'N5',
        scenario: json['scenario'] as String?,
        summary: json['summary'] as String?,
        createdAt: (json['created_at'] as String?) ?? '',
        turnCount: (json['turn_count'] as num?)?.toInt() ?? 0,
      );

  String get modeLabel => switch (mode) {
        'free_talk' => 'Tự do',
        'correction' => 'Sửa lỗi',
        'roleplay' => 'Đóng vai',
        _ => mode,
      };
}

class TurnRecord {
  const TurnRecord({
    required this.id,
    required this.sessionId,
    this.transcriptJa,
    required this.replyJa,
    this.correctionJa,
    this.explanationVi,
    required this.emotion,
    required this.createdAt,
  });

  final String id;
  final String sessionId;
  final String? transcriptJa;
  final String replyJa;
  final String? correctionJa;
  final String? explanationVi;
  final String emotion;
  final String createdAt;

  factory TurnRecord.fromJson(Map<String, dynamic> json) => TurnRecord(
        id: (json['id'] as String?) ?? '',
        sessionId: (json['session_id'] as String?) ?? '',
        transcriptJa: json['transcript_ja'] as String?,
        replyJa: (json['reply_ja'] as String?) ?? '',
        correctionJa: json['correction_ja'] as String?,
        explanationVi: json['explanation_vi'] as String?,
        emotion: (json['emotion'] as String?) ?? 'neutral',
        createdAt: (json['created_at'] as String?) ?? '',
      );
}
