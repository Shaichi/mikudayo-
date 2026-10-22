"""Bảng cố định error_type -> từ khóa tiêu đề chunk ngữ pháp (feat-ai-guardrails R3).

Chunk được chọn theo loại lỗi do bước phát hiện báo, không theo khoảng cách vector.
Các loại không có chunk (tense, conjugation, word_choice, other) vẫn được sửa nhưng
không có tài liệu tham chiếu.
"""
from __future__ import annotations

from ..repositories import grammar_repository as grammar_repo

ERROR_TYPE_TITLE_KEYS: dict[str, tuple[str, ...]] = {
    "particle_motion": ("đích đến",),
    "particle_place": ("nơi diễn ra",),
    "particle_preference": ("sở thích và khả năng",),
    "particle_wa_ga": ("Chủ ngữ thông tin mới",),
    "permission": ("xin phép",),
    "desire": ("Mong muốn",),
    "request": ("yêu cầu lịch sự",),
    "adjective": ("Phủ định tính từ",),
    "give_receive": ("cho và nhận",),
    "conditional": ("Câu điều kiện",),
    "passive": ("bị động",),
    "causative": ("sai khiến",),
    "reason": ("Nguyên nhân khách quan",),
    "sou": ("そう",),
    "okage_seide": ("おかげで",),
    "wake_dewa_nai": ("わけではない",),
    "wake_ga_nai": ("わけがない",),
    "chigainai_hazu": ("に違いない",),
    "wake_niwa_ikanai": ("わけにはいかない",),
    "nimokakawarazu": ("にもかかわらず",),
}

# Danh sách mô tả cho prompt của bước phát hiện.
ERROR_TYPE_HELP = """\
particle_motion: dùng を với động từ di chuyển (学校を行く) thay vì に/へ
particle_place: dùng に cho nơi diễn ra hành động thay vì で
particle_preference: dùng を với 好き/上手/嫌い/下手 thay vì が
particle_wa_ga: nhầm は/が
permission: sai mẫu xin phép 〜てもいいですか
desire: sai mẫu 〜たい / 〜がほしい
request: sai mẫu 〜てください
adjective: sai chia tính từ い/な (きれいいな, 高いじゃない)
give_receive: nhầm あげる/くれる/もらう
conditional: nhầm 〜たら/〜なら/〜ば
passive / causative: sai thể bị động / sai khiến
reason: nhầm 〜ので/〜から
sou: nhầm 〜そう / 〜そうだ
okage_seide: nhầm おかげで/せいで
wake_dewa_nai, wake_ga_nai, chigainai_hazu, wake_niwa_ikanai, nimokakawarazu: các mẫu N3 tương ứng
tense: sai thì (昨日 ... 行きます)
conjugation: chia sai động từ/tính từ ngoài các loại trên
word_choice: dùng sai từ, sai trợ từ khác các loại trên
other: lỗi ngữ pháp chắc chắn khác
none: không có lỗi ngữ pháp"""


def chunks_for_error(error_type: str, level: str) -> list[dict]:
    keys = ERROR_TYPE_TITLE_KEYS.get(error_type, ())
    if not keys:
        return []
    return grammar_repo.get_chunks_by_title_keys(keys, level)
