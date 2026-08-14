from __future__ import annotations

import unittest

from app.main import app


class ConversationContractTest(unittest.TestCase):
    def test_conversation_endpoint_accepts_text_but_not_microphone_audio(self) -> None:
        openapi = app.openapi()
        operation = openapi["paths"]["/v1/conversation/turn"]["post"]
        request_schema = operation["requestBody"]["content"]
        form_schema = request_schema["application/x-www-form-urlencoded"]["schema"]
        schema_name = form_schema["$ref"].rsplit("/", 1)[-1]
        properties = openapi["components"]["schemas"][schema_name]["properties"]

        self.assertIn("text", properties)
        self.assertNotIn("audio", properties)

    def test_audio_status_endpoint_is_exposed(self) -> None:
        openapi = app.openapi()
        operation = openapi["paths"]["/v1/audio/{turn_id}/status"]["get"]
        response_schema = operation["responses"]["200"]["content"][
            "application/json"
        ]["schema"]
        self.assertEqual(
            response_schema["$ref"],
            "#/components/schemas/AudioGenerationStatus",
        )


if __name__ == "__main__":
    unittest.main()
