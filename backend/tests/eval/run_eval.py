"""Chạy golden set với Gemini THẬT.  Cách chạy (từ thư mục backend):

    python -X utf8 -m tests.eval.run_eval [--only prefix] [--out file.json]

Không nằm trong `unittest discover` (cần mạng và tốn quota).
"""
from __future__ import annotations

import argparse
import json
import time

from app.db.seed_grammar import seed_grammar
from app.db.sqlite import init_db
from app.services.gemini_service import GeminiService
from app.services.turn_pipeline import run_turn

from .cases import CASES
from .checks import run_check


PACE_SECONDS = 4.5  # free tier: 15 request/phút/model


def _call(gemini, case, retries: int = 3):
    for attempt in range(retries + 1):
        time.sleep(PACE_SECONDS)
        try:
            return run_turn(
                gemini, user_text=case.text, mode=case.mode, level=case.level, scenario=case.scenario,
            )
        except Exception as exc:  # noqa: BLE001
            if "429" in str(exc) and attempt < retries:
                time.sleep(25)
                continue
            raise


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--out", default="")
    args = ap.parse_args()

    init_db()
    seed_grammar()
    gemini = GeminiService()
    if gemini.is_mock:
        print("Gemini đang ở chế độ mock — thiếu GEMINI_API_KEY.")
        return 2

    selected = [c for c in CASES if c.id.startswith(args.only)]
    results, failed_checks = [], 0
    for case in selected:
        t0 = time.perf_counter()
        try:
            out, info = _call(gemini, case)
        except Exception as exc:  # noqa: BLE001
            results.append({"id": case.id, "error": str(exc)[:200]})
            failed_checks += len(case.checks)
            print(f"ERR  {case.id}: {str(exc)[:100]}")
            continue
        ms = int((time.perf_counter() - t0) * 1000)
        row = {"id": case.id, "ms": ms, "policy": info.policy, "notes": info.notes, "reply": out.reply_ja,
               "correction": out.correction_ja, "emotion": out.emotion, "gesture": out.gesture, "checks": {}}
        bad = []
        for name in case.checks:
            ok, detail = run_check(name, out, case)
            row["checks"][name] = ok
            if not ok:
                bad.append(f"{name}({detail})")
        failed_checks += len(bad)
        results.append(row)
        print(f"{'FAIL' if bad else 'ok  '} {case.id:16} {ms:5}ms {info.policy:7}| {out.reply_ja[:40]} | {', '.join(bad)}")

    total = sum(len(c.checks) for c in selected)
    print(f"\nChecks đạt: {total - failed_checks}/{total}")
    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            json.dump(results, f, ensure_ascii=False, indent=1)
    return 0 if failed_checks == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
