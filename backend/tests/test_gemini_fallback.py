import unittest
from types import SimpleNamespace
from unittest.mock import patch

from app.services.gemini_service import GeminiService


class _ApiError(Exception):
    def __init__(self, code):
        super().__init__(f"{code} error")
        self.code = code


class _Models:
    def __init__(self, failures):
        self.failures = failures
        self.calls = []

    def generate_content(self, model, contents, config):
        self.calls.append(model)
        if model in self.failures:
            raise self.failures[model]
        return SimpleNamespace(text="{}", model=model)


def _service(failures):
    svc = GeminiService.__new__(GeminiService)
    svc._mock = False
    svc._cooldown_until = {}
    svc._client = SimpleNamespace(models=_Models(failures))
    return svc


class GeminiFallbackTest(unittest.TestCase):
    def setUp(self):
        p = patch.multiple(
            "app.services.gemini_service.settings",
            GEMINI_MODEL="primary",
            GEMINI_FALLBACK_MODELS="backup1, backup2",
            GEMINI_TIMEOUT_SECONDS=10.0,
            GEMINI_COOLDOWN_SECONDS=300.0,
        )
        p.start()
        self.addCleanup(p.stop)

    def _config(self):
        from google.genai import types
        return types.GenerateContentConfig()

    def test_overloaded_primary_falls_back_and_cools_down(self):
        svc = _service({"primary": _ApiError(503)})
        self.assertEqual(svc._generate("hi", self._config()).model, "backup1")
        # Lượt sau không chờ model chính nữa.
        self.assertEqual(svc._generate("hi", self._config()).model, "backup1")
        self.assertEqual(svc._client.models.calls, ["primary", "backup1", "backup1"])

    def test_timeout_falls_back(self):
        svc = _service({"primary": TimeoutError("slow")})
        self.assertEqual(svc._generate("hi", self._config()).model, "backup1")

    def test_bad_request_is_not_retried(self):
        svc = _service({"primary": _ApiError(400)})
        with self.assertRaises(_ApiError):
            svc._generate("hi", self._config())
        self.assertEqual(svc._client.models.calls, ["primary"])

    def test_all_models_fail_raises_last_error(self):
        svc = _service({m: _ApiError(503) for m in ("primary", "backup1", "backup2")})
        with self.assertRaises(_ApiError):
            svc._generate("hi", self._config())

    def test_timeout_is_set_on_request(self):
        svc = _service({})
        cfg = self._config()
        svc._generate("hi", cfg)
        self.assertEqual(cfg.http_options.timeout, 10000)


if __name__ == "__main__":
    unittest.main()
