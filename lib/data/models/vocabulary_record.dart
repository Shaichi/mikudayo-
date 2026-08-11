/// Model cho sổ từ vựng (GET /v1/vocabulary).
library;

class VocabularyRecord {
  const VocabularyRecord({
    required this.id,
    required this.word,
    this.reading,
    this.meaningVi,
    required this.firstSeenAt,
    required this.reviewCount,
  });

  final int id;
  final String word;
  final String? reading;
  final String? meaningVi;
  final String firstSeenAt;
  final int reviewCount;

  factory VocabularyRecord.fromJson(Map<String, dynamic> json) =>
      VocabularyRecord(
        id: (json['id'] as num?)?.toInt() ?? 0,
        word: (json['word'] as String?) ?? '',
        reading: json['reading'] as String?,
        meaningVi: json['meaning_vi'] as String?,
        firstSeenAt: (json['first_seen_at'] as String?) ?? '',
        reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      );
}
