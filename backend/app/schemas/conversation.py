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
VoiceMode = Literal["pending", "fish_audio", "mock", "none"]
AudioStatusValue = Literal["pending", "ready", "error"]


class VocabItem(BaseModel):
    word: str = Field(description="Từ mới bằng tiếng Nhật")
    reading: str = Field(default="", description="Cách đọc (furigana)")
    meaning_vi: str = Field(default="", description="Nghĩa tiếng Việt")


class MouthCue(BaseModel):
    t_ms: int = Field(description="Thời điểm tính từ đầu audio (ms)")
    mouth: float = Field(description="Độ mở miệng 0..1")


class GeminiTurnOutput(BaseModel):
    """JSON schema yêu cầu Gemini trả về (mục 8.3)."""

    transcript_ja: str = Field(description="Lời người học nói, phiên âm tiếng Nhật")
    reply_ja: str = Field(description="Câu trả lời của Miku bằng tiếng Nhật")
    correction_ja: Optional[str] = Field(default=None, description="Câu sửa ngữ pháp nếu có")
    explanation_vi: Optional[str] = Field(default=None, description="Giải thích lỗi bằng tiếng Việt")
    emotion: Emotion = Field(default="neutral", description="Cảm xúc của Miku")
    difficulty: JpLevel = Field(default="N5", description="Độ khó nhận định")
    vocabulary: list[VocabItem] = Field(default_factory=list, description="Từ mới trong lượt")


class ConversationRequest(BaseModel):
    session_id: Optional[str] = None
    mode: Mode = "free_talk"
    jlpt_level: JpLevel = "N5"
    scenario: Optional[str] = None
    # text hỗ trợ Phase 1 — chat text thuần (không cần audio)
    text: Optional[str] = None


class ConversationResult(BaseModel):
    """Response cho POST /v1/conversation/turn (mục 12.2)."""

    turn_id: str
    session_id: str
    transcript_ja: str
    reply_ja: str
    correction_ja: Optional[str] = None
    explanation_vi: Optional[str] = None
    emotion: Emotion = "neutral"
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
