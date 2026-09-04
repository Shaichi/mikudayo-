"""Seed data ngữ pháp chuẩn JLPT N5–N3 cho RAG grounding (feat-rag-grammar)."""
from __future__ import annotations

from ..core.logging import get_logger
from ..db.sqlite import get_conn
from ..repositories import grammar_repository as grammar_repo
from ..services.rag_grammar_service import RagGrammarService

logger = get_logger("seed_grammar")

SEED_CHUNKS = [
    # === JLPT N5 ===
    {
        "title": "Trợ từ chỉ đích đến của động từ di chuyển (に / へ vs を)",
        "jlpt_level": "N5",
        "source": "curated",
        "chunk_text": (
            "【Quy tắc ngữ pháp】: Các động từ chỉ sự di chuyển như 行く (đi), 来る (đến), 帰る (trở về) "
            "sử dụng trợ từ 「に」 hoặc 「へ」 để chỉ điểm đến.\n"
            "【Lỗi sai thường gặp (Anti-patterns)】:\n"
            "× 学校を行きます (Sai: dùng を chỉ đích đến)\n"
            "○ 学校へ行きます / 学校に行きます (Đúng)\n"
            "× 日本を行きたい (Sai: dùng を)\n"
            "○ 日本に行きたい / 日本へ行きたい (Đúng)\n"
            "【Giải thích tiếng Việt】: Điểm đến của động từ di chuyển bắt buộc đi với trợ từ に hoặc へ, tuyệt đối không dùng trợ từ を."
        ),
    },
    {
        "title": "Trợ từ nơi diễn ra hành động (で vs に)",
        "jlpt_level": "N5",
        "source": "curated",
        "chunk_text": (
            "【Quy tắc ngữ pháp】: Trợ từ 「で」 dùng để chỉ địa điểm nơi hành động diễn ra. "
            "Trợ từ 「に」 dùng để chỉ địa điểm tồn tại của người/vật (đi với ある, いる) hoặc điểm đến.\n"
            "【Lỗi sai thường gặp (Anti-patterns)】:\n"
            "× レストランにご飯を食べる (Sai: dùng に nơi hành động)\n"
            "○ レストランでご飯を食べる (Đúng)\n"
            "× 教室に勉強します (Sai: dùng に nơi hành động)\n"
            "○ 教室で勉強します (Đúng)\n"
            "【Giải thích tiếng Việt】: Nơi diễn ra hành động (như ăn cơm, học bài) phải dùng trợ từ 「で」, không dùng 「に」."
        ),
    },
    {
        "title": "Trợ từ đối tượng của sở thích và khả năng (が vs を với 好き/上手)",
        "jlpt_level": "N5",
        "source": "curated",
        "chunk_text": (
            "【Quy tắc ngữ pháp】: Các tính từ đuôi na chỉ sở thích, khả năng như 好き (thích), 嫌い (ghét), 上手 (giỏi), 下手 (kém) "
            "đi với trợ từ 「が」 để chỉ đối tượng được nhắm tới, không dùng trợ từ 「を」.\n"
            "【Lỗi sai thường gặp (Anti-patterns)】:\n"
            "× 日本語を好きです (Sai: dùng を với 好き)\n"
            "○ 日本語が好きです (Đúng)\n"
            "× アニメを上手です (Sai: dùng を với 上手)\n"
            "○ アニメの絵を描くのが上手です / 日本語が上手です (Đúng)\n"
            "【Giải thích tiếng Việt】: Đối tượng của 好き (thích) hay 上手 (giỏi) phải dùng trợ từ 「が」, không dùng 「を」."
        ),
    },
    {
        "title": "Mẫu câu xin phép (〜てもいいですか vs 〜てもだめ)",
        "jlpt_level": "N5",
        "source": "curated",
        "chunk_text": (
            "【Quy tắc ngữ pháp】: Để xin phép làm một việc gì đó, sử dụng thể て của động từ kết hợp với 「もいいですか」.\n"
            "【Lỗi sai thường gặp (Anti-patterns)】:\n"
            "× 写真を撮るもいいですか (Sai: chưa chia thể て)\n"
            "○ 写真を撮ってもいいですか (Đúng)\n"
            "× ここに座るがいいですか (Sai: dùng がいいですか)\n"
            "○ ここに座ってもいいですか (Đúng)\n"
            "【Giải thích tiếng Việt】: Khi xin phép lịch sự trong tiếng Nhật, động từ phải chia về thể て + もいいですか."
        ),
    },
    {
        "title": "Mong muốn làm hành động (〜たい) vs Mong muốn có vật (〜がほしい)",
        "jlpt_level": "N5",
        "source": "curated",
        "chunk_text": (
            "【Quy tắc ngữ pháp】: Muốn thực hiện một HÀNH ĐỘNG gì đó: Động từ bỏ ます + たい (như 食べたい, 行きたい). "
            "Muốn CÓ một vật thể gì đó: Danh từ + がほしい (như 車がほしい, 水がほしい).\n"
            "【Lỗi sai thường gặp (Anti-patterns)】:\n"
            "× 車を買うがほしい (Sai: kết hợp động từ với ほしい)\n"
            "○ 車を買いたい / 車がほしい (Đúng)\n"
            "【Giải thích tiếng Việt】: Muốn làm hành động dùng đuôi 「〜たい」, muốn có đồ vật dùng 「〜がほしい」."
        ),
    },
    {
        "title": "Chủ ngữ thông tin mới và Tiêu đề câu (は vs が)",
        "jlpt_level": "N5",
        "source": "curated",
        "chunk_text": (
            "【Quy tắc ngữ pháp】: 「は」 giới thiệu chủ đề của câu chuyện (đã biết), nhấn mạnh vào thông tin vị ngữ đằng sau. "
            "「が」 dùng để chỉ định đối tượng cụ thể (thông tin mới) hoặc miêu tả hiện tượng tự nhiên trực quan.\n"
            "【Lỗi sai thường gặp (Anti-patterns)】:\n"
            "× 雨は降っています (Sai khi đang miêu tả hiện tượng thời tiết trước mắt)\n"
            "○ 雨が降っています (Đúng)\n"
            "× 誰は来ましたか (Sai: từ để hỏi làm chủ ngữ không đi với は)\n"
            "○ 誰が来ましたか (Đúng)\n"
            "【Giải thích tiếng Việt】: Hiện tượng tự nhiên và từ để hỏi làm chủ ngữ bắt buộc dùng trợ từ 「が」."
        ),
    },
    {
        "title": "Mẫu câu yêu cầu lịch sự (〜てください vs 辞書形)",
        "jlpt_level": "N5",
        "source": "curated",
        "chunk_text": (
            "【Quy tắc ngữ pháp】: Khi muốn nhờ vả, yêu cầu ai đó làm gì một cách lịch sự: Động từ chia thể て + ください.\n"
            "【Lỗi sai thường gặp (Anti-patterns)】:\n"
            "× ここで待つをください (Sai: dùng thể từ điển + を)\n"
            "○ ここで待ってください (Đúng)\n"
            "× 日本語を教えるてください (Sai: chưa chia thể て)\n"
            "○ 日本語を教えてください (Đúng)\n"
            "【Giải thích tiếng Việt】: Động từ đi trước ください bắt buộc phải chia sang thể て."
        ),
    },
    {
        "title": "Phủ định tính từ đuôi い vs Tính từ đuôi な (〜くない vs 〜じゃない)",
        "jlpt_level": "N5",
        "source": "curated",
        "chunk_text": (
            "【Quy tắc ngữ pháp】: Tính từ đuôi い khi phủ định: bỏ い + くない (ví dụ: 高い -> 高くない). "
            "Tính từ đuôi な khi phủ định: bỏ な + じゃない / ではありません (ví dụ: 静か -> 静かじゃない).\n"
            "【Lỗi sai thường gặp (Anti-patterns)】:\n"
            "× 高いじゃない (Sai: nhầm lẫn cách phủ định tính từ đuôi い)\n"
            "○ 高くない (Đúng)\n"
            "× 静かくない (Sai: chia tính từ đuôi な như đuôi い)\n"
            "○ 静かじゃない / 静かではありません (Đúng)\n"
            "【Giải thích tiếng Việt】: Tính từ đuôi い phủ định là 〜くない, không dùng じゃない như tính từ đuôi な."
        ),
    },

    # === JLPT N4 ===
    {
        "title": "Động từ cho và nhận (あげる vs くれる vs もらう)",
        "jlpt_level": "N4",
        "source": "curated",
        "chunk_text": (
            "【Quy tắc ngữ pháp】: "
            "1. あげる: Người nói (hoặc người phe mình) TẶNG cho người khác. "
            "2. くれる: Người khác TẶNG cho người nói (hoặc người thân của người nói). "
            "3. もらう: Người nói NHẬN từ người khác (chủ ngữ là người nhận).\n"
            "【Lỗi sai thường gặp (Anti-patterns)】:\n"
            "× 友達は私にプレゼントをあげました (Sai nghiêm trọng: người khác cho tôi không bao giờ dùng あげる)\n"
            "○ 友達は私にプレゼントをくれました (Đúng: người khác cho tôi dùng くれる)\n"
            "○ 私は友達にプレゼントをもらいました (Đúng: tôi nhận quà từ bạn)\n"
            "【Giải thích tiếng Việt】: Khi người khác làm gì hay tặng gì cho bạn, bắt buộc dùng くれる, tuyệt đối không dùng あげる."
        ),
    },
    {
        "title": "Câu điều kiện (〜たら vs 〜なら)",
        "jlpt_level": "N4",
        "source": "curated",
        "chunk_text": (
            "【Quy tắc ngữ pháp】: "
            "〜たら dùng khi một điều kiện xảy ra xong thì hành động/kết quả sau mới đến (Nếu... thì...). "
            "〜なら dùng khi tiếp nhận thông tin người đối thoại vừa nói để đưa ra gợi ý, lời khuyên (Nếu là chuyện đó thì...).\n"
            "【Lỗi sai thường gặp (Anti-patterns)】:\n"
            "× 日本へ行くなら、富士山が見えます (Sai: kết quả tự nhiên không dùng なら)\n"
            "○ 日本へ行ったら、富士山が見えます (Đúng)\n"
            "○ 日本へ行くなら、春が一番おすすめですよ (Đúng: đưa ra lời khuyên dựa trên chủ đề đối phương nói)\n"
            "【Giải thích tiếng Việt】: Đưa ra lời khuyên dựa trên thông tin người khác nói dùng 「なら」, diễn tả thứ tự trước sau dùng 「たら」."
        ),
    },
    {
        "title": "Thể bị động (受身形: 〜れる / 〜られる)",
        "jlpt_level": "N4",
        "source": "curated",
        "chunk_text": (
            "【Quy tắc ngữ pháp】: Động từ thể bị động diễn tả việc bị/được ai đó tác động lên mình. "
            "Tác nhân gây ra hành động bắt buộc đi kèm trợ từ 「に」, không dùng 「を」.\n"
            "【Lỗi sai thường gặp (Anti-patterns)】:\n"
            "× 私は先生を褒められました (Sai: dùng を cho người tác động)\n"
            "○ 私は先生に褒められました (Đúng)\n"
            "× 電車で隣の人を足を踏まれました (Sai: người dẫm phải đi với に)\n"
            "○ 電車で隣の人に足を踏まれました (Đúng)\n"
            "【Giải thích tiếng Việt】: Trong câu bị động, người thực hiện hành động tác động lên chủ thể phải đi với trợ từ 「に」."
        ),
    },
    {
        "title": "Thể sai khiến (使役形: 〜せる / 〜させる)",
        "jlpt_level": "N4",
        "source": "curated",
        "chunk_text": (
            "【Quy tắc ngữ pháp】: Thể sai khiến thể hiện việc bắt buộc hoặc cho phép ai làm gì. "
            "Với tha động từ (có tân ngữ を), người bị sai khiến đi với trợ từ 「に」 để tránh trùng hai trợ từ を.\n"
            "【Lỗi sai thường gặp (Anti-patterns)】:\n"
            "× 母は子供をご飯を食べさせました (Sai: hai trợ từ を cạnh nhau)\n"
            "○ 母は子供にご飯を食べさせました (Đúng)\n"
            "【Giải thích tiếng Việt】: Trong câu sai khiến có tha động từ, người nhận mệnh lệnh đi với trợ từ 「に」."
        ),
    },
    {
        "title": "Nguyên nhân khách quan (〜ので vs 〜から)",
        "jlpt_level": "N4",
        "source": "curated",
        "chunk_text": (
            "【Quy tắc ngữ pháp】: 「〜ので」 diễn tả lý do khách quan, trang trọng, nhẹ nhàng. "
            "Khi kết hợp với Danh từ hoặc Tính từ đuôi な, bắt buộc phải thêm 「な」 trước ので: Danh từ/Tính từ な + な + ので.\n"
            "【Lỗi sai thường gặp (Anti-patterns)】:\n"
            "× 今日は雨ので、遅れました (Sai: thiếu な sau danh từ 雨)\n"
            "○ 今日は雨なので、遅れました (Đúng)\n"
            "× 暇ので、遊びに行こう (Sai: thiếu な sau tính từ 暇)\n"
            "○ 暇なので、遊びに行こう (Đúng)\n"
            "【Giải thích tiếng Việt】: Danh từ và tính từ đuôi な khi đi trước 「ので」 bắt buộc phải có 「な」."
        ),
    },
    {
        "title": "Dự đoán cảm quan (〜そう) vs Nghe nói (〜そうだ)",
        "jlpt_level": "N4",
        "source": "curated",
        "chunk_text": (
            "【Quy tắc ngữ pháp】: "
            "Dự đoán trực quan bằng mắt (trông có vẻ): Tính từ い bỏ い + そう (美味しそう, 嬉しそう). "
            "Nghe nói lại thông tin: Tính từ い giữ nguyên い + そうだ (美味しいそうだ = nghe nói là ngon).\n"
            "【Lỗi sai thường gặp (Anti-patterns)】:\n"
            "× このケーキは美味しいそうです (Sai khi vừa nhìn bánh vừa khen ngon)\n"
            "○ このケーキは美味しそうです (Đúng: trông có vẻ ngon)\n"
            "【Giải thích tiếng Việt】: Khen 'trông có vẻ ngon' bằng mắt nhìn phải bỏ đuôi い, thành 美味しそう."
        ),
    },

    # === JLPT N3 ===
    {
        "title": "Nguyên nhân kết quả tích cực vs Tiêu cực (おかげで vs せいで)",
        "jlpt_level": "N3",
        "source": "curated",
        "chunk_text": (
            "【Quy tắc ngữ pháp】: "
            "「〜おかげで」 dùng khi nguyên nhân mang lại kết quả TỐT ĐẸP, biết ơn (Nhờ có...). "
            "「〜せいで」 dùng khi nguyên nhân mang lại kết quả TỒI TỆ, tiêu cực, trách móc (Do, tại vì...).\n"
            "【Lỗi sai thường gặp (Anti-patterns)】:\n"
            "× 雨が降ったおかげで、試合が中止になった (Sai nghiêm trọng: trận đấu bị hủy là kết quả xấu, không dùng おかげで)\n"
            "○ 雨が降ったせいで、試合が中止になった (Đúng)\n"
            "○ 先生のおかげで、合格できました (Đúng: đỗ kỳ thi là kết quả tốt)\n"
            "【Giải thích tiếng Việt】: Kết quả tiêu cực dùng せいで, kết quả tích cực dùng おかげで."
        ),
    },
    {
        "title": "Không hẳn là / Chưa chắc đã (〜わけではない)",
        "jlpt_level": "N3",
        "source": "curated",
        "chunk_text": (
            "【Quy tắc ngữ pháp】: Phủ định một phần tính chất, nghĩa là 'không hoàn toàn như vậy' hoặc 'không hẳn là...'. "
            "Khi đi với Tính từ đuôi な: Tính từ な + な + わけではない.\n"
            "【Lỗi sai thường gặp (Anti-patterns)】:\n"
            "× 日本料理が嫌いわけではない (Sai: thiếu な sau tính từ な)\n"
            "○ 日本料理が嫌いなわけではない (Đúng: không hẳn là ghét)\n"
            "【Giải thích tiếng Việt】: Đi kèm tính từ đuôi な với わけではない bắt buộc phải có 「な」."
        ),
    },
    {
        "title": "Tuyệt đối không thể nào (〜わけがない)",
        "jlpt_level": "N3",
        "source": "curated",
        "chunk_text": (
            "【Quy tắc ngữ pháp】: Khẳng định mạnh mẽ dựa trên logic rằng một điều chắc chắn không thể xảy ra (Làm sao mà... được!).\n"
            "【Lỗi sai thường gặp (Anti-patterns)】:\n"
            "× 彼が嘘をつくわけではない (Sai: dùng わけではない chỉ có nghĩa là 'không hẳn nói dối', không thể hiện được sự tin tưởng tuyệt đối)\n"
            "○ 彼が嘘をつくわけがない (Đúng: anh ấy làm sao mà nói dối được!)\n"
            "【Giải thích tiếng Việt】: Phủ định dứt khoát điều không thể xảy ra dùng 「わけがない」."
        ),
    },
    {
        "title": "Chắc chắn là (〜に違いない vs 〜はずだ)",
        "jlpt_level": "N3",
        "source": "curated",
        "chunk_text": (
            "【Quy tắc ngữ pháp】: 「〜に違いない」 thể hiện phán đoán mang tính trực giác, chủ quan cực kỳ chắc chắn của người nói (Chắc chắn là, không sai được). "
            "Liên kết trực tiếp với Thể thông thường (Danh từ không cần だ).\n"
            "【Lỗi sai thường gặp (Anti-patterns)】:\n"
            "× 犯人は彼だに違いない (Sai: thừa だ sau danh từ 彼)\n"
            "○ 犯人は彼に違いない (Đúng)\n"
            "【Giải thích tiếng Việt】: Danh từ đi trực tiếp với 「に違いない」, không kèm theo trợ động từ 「だ」."
        ),
    },
    {
        "title": "Không thể làm vì đạo đức / trách nhiệm (〜わけにはいかない)",
        "jlpt_level": "N3",
        "source": "curated",
        "chunk_text": (
            "【Quy tắc ngữ pháp】: Động từ thể từ điển + わけにはいかない diễn tả việc muốn làm nhưng vì lý do đạo đức, lương tâm, hoặc áp lực xã hội mà không thể làm được.\n"
            "【Lỗi sai thường gặp (Anti-patterns)】:\n"
            "× 大事な試験があるから、今日休むことができない (Diễn đạt khả năng thể chất/thời gian, không toát lên được áp lực bổn phận)\n"
            "○ 大事な試験があるから、今日休むわけにはいかない (Đúng: không thể nghỉ được vì trách nhiệm)\n"
            "【Giải thích tiếng Việt】: Không thể làm một việc vì nghĩa vụ, đạo đức dùng 「〜わけにはいかない」."
        ),
    },
    {
        "title": "Mặc dù ... nhưng vẫn (〜にもかかわらず)",
        "jlpt_level": "N3",
        "source": "curated",
        "chunk_text": (
            "【Quy tắc ngữ pháp】: Thể hiện sự tương phản bất ngờ, trái ngược với dự đoán thông thường (Dù cho... nhưng vẫn...). "
            "Đi trực tiếp với Danh từ hoặc Thể thông thường.\n"
            "【Lỗi sai thường gặp (Anti-patterns)】:\n"
            "× 大雨だにもかかわらず、試合は行われた (Sai: thừa だ sau danh từ 大雨)\n"
            "○ 大雨にもかかわらず、試合は行われた (Đúng)\n"
            "【Giải thích tiếng Việt】: Danh từ đi trực tiếp với 「にもかかわらず」, không chèn 「だ」 ở giữa."
        ),
    },
]


def seed_grammar(force: bool = False) -> int:
    """Nạp dữ liệu ngữ pháp mẫu ban đầu vào database nếu chưa có."""
    with get_conn() as conn:
        existing_titles = {
            row["title"] for row in conn.execute("SELECT title FROM grammar_chunks").fetchall()
        }

    rag_service = RagGrammarService()
    inserted = 0

    for item in SEED_CHUNKS:
        if item["title"] in existing_titles and not force:
            continue

        # Sinh vector embedding cho nội dung chunk
        embedding = rag_service.embed_text(item["chunk_text"], task_type="RETRIEVAL_DOCUMENT")
        chunk_id = grammar_repo.add_chunk(
            title=item["title"],
            chunk_text=item["chunk_text"],
            jlpt_level=item["jlpt_level"],
            source=item["source"],
            embedding=embedding,
        )
        inserted += 1
        logger.info("Đã seed grammar chunk %d: %s", chunk_id, item["title"])

    return inserted
