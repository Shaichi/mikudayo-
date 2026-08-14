/// Model dữ liệu cho API hội thoại (mục 12.2 của tài liệu).
library;

/// Cảm xúc của Miku (theo enum trong tài liệu).
enum MikuEmotion {
  neutral,
  happy,
  excited,
  thinking,
  embarrassed,
  sad;

  static MikuEmotion fromApi(String? raw) {
    for (final e in MikuEmotion.values) {
      if (e.name == raw) return e;
    }
    return MikuEmotion.neutral;
  }

  /// Emoji hiển thị cho từng cảm xúc.
  String get emoji => switch (this) {
    MikuEmotion.neutral => '😊',
    MikuEmotion.happy => '😄',
    MikuEmotion.excited => '😆',
    MikuEmotion.thinking => '🤔',
    MikuEmotion.embarrassed => '😳',
    MikuEmotion.sad => '😢',
  };

  /// Nhãn tiếng Việt cho từng cảm xúc.
  String get label => switch (this) {
    MikuEmotion.neutral => 'Vui vẻ',
    MikuEmotion.happy => 'Hạnh phúc',
    MikuEmotion.excited => 'Phấn khích',
    MikuEmotion.thinking => 'Suy nghĩ',
    MikuEmotion.embarrassed => 'Xấu hổ',
    MikuEmotion.sad => 'Buồn',
  };
}

/// Một từ vựng mới trong lượt hội thoại.
class VocabItem {
  const VocabItem({required this.word, this.reading = '', this.meaningVi = ''});

  final String word;
  final String reading;
  final String meaningVi;

  factory VocabItem.fromJson(Map<String, dynamic> json) => VocabItem(
    word: (json['word'] as String?) ?? '',
    reading: (json['reading'] as String?) ?? '',
    meaningVi: (json['meaning_vi'] as String?) ?? '',
  );
}

/// Cue chuyển động miệng (Phase 5 — giữ model sẵn).
class MouthCue {
  const MouthCue({required this.tMs, required this.mouth});

  final int tMs;
  final double mouth;

  factory MouthCue.fromJson(Map<String, dynamic> json) => MouthCue(
    tMs: (json['t_ms'] as num?)?.toInt() ?? 0,
    mouth: (json['mouth'] as num?)?.toDouble() ?? 0,
  );
}

/// Kết quả một lượt hội thoại từ backend.
class ConversationResult {
  const ConversationResult({
    required this.turnId,
    required this.sessionId,
    required this.transcriptJa,
    required this.replyJa,
    this.correctionJa,
    this.explanationVi,
    this.emotion = MikuEmotion.neutral,
    this.vocabulary = const [],
    this.audioUrl = '',
    this.voiceMode = 'mock',
    this.mouthCues = const [],
    this.timingMs = const {},
  });

  final String turnId;
  final String sessionId;
  final String transcriptJa;
  final String replyJa;
  final String? correctionJa;
  final String? explanationVi;
  final MikuEmotion emotion;
  final List<VocabItem> vocabulary;
  final String audioUrl;
  final String voiceMode;
  final List<MouthCue> mouthCues;
  final Map<String, dynamic> timingMs;

  factory ConversationResult.fromJson(Map<String, dynamic> json) {
    return ConversationResult(
      turnId: (json['turn_id'] as String?) ?? '',
      sessionId: (json['session_id'] as String?) ?? '',
      transcriptJa: (json['transcript_ja'] as String?) ?? '',
      replyJa: (json['reply_ja'] as String?) ?? '',
      correctionJa: json['correction_ja'] as String?,
      explanationVi: json['explanation_vi'] as String?,
      emotion: MikuEmotion.fromApi(json['emotion'] as String?),
      vocabulary: ((json['vocabulary'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(VocabItem.fromJson)
          .toList(),
      audioUrl: (json['audio_url'] as String?) ?? '',
      voiceMode: (json['voice_mode'] as String?) ?? 'mock',
      mouthCues: ((json['mouth_cues'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MouthCue.fromJson)
          .toList(),
      timingMs: (json['timing_ms'] as Map<String, dynamic>?) ?? const {},
    );
  }
}

/// Trạng thái tạo giọng nền sau khi backend đã trả text của Miku.
class ConversationAudioStatus {
  const ConversationAudioStatus({
    required this.status,
    this.audioUrl = '',
    this.voiceMode = 'pending',
    this.mouthCues = const [],
    this.timingMs = const {},
    this.error,
  });

  final String status;
  final String audioUrl;
  final String voiceMode;
  final List<MouthCue> mouthCues;
  final Map<String, dynamic> timingMs;
  final String? error;

  bool get isReady => status == 'ready' && audioUrl.isNotEmpty;
  bool get isError => status == 'error';

  factory ConversationAudioStatus.fromJson(Map<String, dynamic> json) {
    return ConversationAudioStatus(
      status: (json['status'] as String?) ?? 'pending',
      audioUrl: (json['audio_url'] as String?) ?? '',
      voiceMode: (json['voice_mode'] as String?) ?? 'pending',
      mouthCues: ((json['mouth_cues'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MouthCue.fromJson)
          .toList(),
      timingMs: (json['timing_ms'] as Map<String, dynamic>?) ?? const {},
      error: json['error'] as String?,
    );
  }
}
