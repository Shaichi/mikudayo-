"""Schema Pydantic cho API hội thoại.

Định nghĩa theo mục 12 (API contract) của tài liệu. Backend validate output
Gemini bằng Pydantic trước khi trả về Flutter.
"""
from __future__ import annotations

from typing import Any, Literal, Optional

from pydantic import BaseModel, Field

Mode = Literal["free_talk", "correction", "roleplay"]
JpLevel = Literal["N5", "N4", "N3"]
Emotion = Literal["neutral", "happy", "excited", "thinking", "embarrassed", "sad"]
Gesture = Literal["none", "wave", "nod", "clap", "sad", "thinking", "surprise"]
VoiceMode = Literal["pending", "fish_audio", "mock", "none"]
AudioStatusValue = Literal["pending", "ready", "error"]


class VocabItem(BaseModel):
    word: str = Field(min_length=1, max_length=80, description="Từ mới bằng tiếng Nhật")
    reading: str = Field(default="", max_length=120, description="Cách đọc (furigana)")
    meaning_vi: str = Field(default="", max_length=240, description="Nghĩa tiếng Việt")


class MouthCue(BaseModel):
    t_ms: int = Field(ge=0, description="Thời điểm tính từ đầu audio (ms)")
    mouth: float = Field(ge=0.0, le=1.0, description="Độ mở miệng 0..1")


class GeminiTurnOutput(BaseModel):
    """JSON schema yêu cầu Gemini trả về (mục 8.3)."""

    transcript_ja: str = Field(min_length=1, max_length=10000, description="Lời người học nói, phiên âm tiếng Nhật")
    reply_ja: str = Field(min_length=1, max_length=2000, description="Câu trả lời của Miku bằng tiếng Nhật")
    correction_ja: Optional[str] = Field(default=None, max_length=2000, description="Câu sửa ngữ pháp nếu có")
    explanation_vi: Optional[str] = Field(default=None, max_length=4000, description="Giải thích lỗi bằng tiếng Việt")
    emotion: Emotion = Field(default="neutral", description="Cảm xúc của Miku")
    gesture: Gesture = Field(default="none", description="Cử chỉ thân/tay cho avatar")
    difficulty: JpLevel = Field(default="N5", description="Độ khó nhận định")
    vocabulary: list[VocabItem] = Field(default_factory=list, max_length=4, description="Từ mới trong lượt")


ErrorType = Literal[
    "none",
    "particle_motion", "particle_place", "particle_preference", "particle_wa_ga",
    "permission", "desire", "request", "adjective", "give_receive", "conditional",
    "passive", "causative", "reason", "sou", "okage_seide",
    "wake_dewa_nai", "wake_ga_nai", "chigainai_hazu", "wake_niwa_ikanai", "nimokakawarazu",
    "tense", "conjugation", "word_choice", "other",
]


class ErrorDetection(BaseModel):
    """Kết quả bước phát hiện lỗi ngữ pháp (feat-ai-guardrails R1)."""

    has_error: bool = False
    error_type: ErrorType = "none"
    quote: str = Field(default="", max_length=200, description="Đoạn sai nguyên văn trong câu người học")


class ConversationRequest(BaseModel):
    session_id: Optional[str] = Field(default=None, max_length=100)
    mode: Mode = "free_talk"
    jlpt_level: JpLevel = "N5"
    scenario: Optional[str] = Field(default=None, max_length=240)
    # text hỗ trợ Phase 1 — chat text thuần (không cần audio)
    text: Optional[str] = Field(default=None, max_length=2000)


class ConversationResult(BaseModel):
    """Response cho POST /v1/conversation/turn (mục 12.2)."""

    turn_id: str
    session_id: str
    transcript_ja: str
    reply_ja: str
    correction_ja: Optional[str] = None
    explanation_vi: Optional[str] = None
    emotion: Emotion = "neutral"
    gesture: Gesture = "none"
    vocabulary: list[VocabItem] = Field(default_factory=list)
    audio_url: str = Field(description="URL để Flutter phát audio (có thể rỗng ở mock)")
    voice_mode: VoiceMode = "fish_audio"
    mouth_cues: list[MouthCue] = Field(default_factory=list)
    timing_ms: dict[str, Any] = Field(default_factory=dict)


class AudioGenerationStatus(BaseModel):
    """Trạng thái job tạo giọng chạy nền cho một lượt hội thoại."""

    status: AudioStatusValue = "pending"
    audio_url: str = ""
    voice_mode: VoiceMode = "pending"
    mouth_cues: list[MouthCue] = Field(default_factory=list)
    timing_ms: dict[str, Any] = Field(default_factory=dict)
    error: Optional[str] = None


class HealthStatus(BaseModel):
    status: str
    gemini: bool
    fish_audio: bool
    mode: str
    model: str
    tts_model: str


class TurnRecord(BaseModel):
    id: str
    session_id: str
    transcript_ja: Optional[str]
    reply_ja: str
    correction_ja: Optional[str]
    explanation_vi: Optional[str]
    emotion: str
    gesture: str = "none"
    difficulty: str = "N5"
    audio_path: Optional[str] = None
    created_at: str


class SessionRecord(BaseModel):
    id: str
    mode: str
    jlpt_level: str
    scenario: Optional[str]
    summary: Optional[str]
    created_at: str
    turn_count: int = 0


class VocabularyRecord(BaseModel):
    id: int
    word: str
    reading: Optional[str]
    meaning_vi: Optional[str]
    first_seen_at: str
    review_count: int


class DeleteResult(BaseModel):
    deleted: bool
    session_id: str
