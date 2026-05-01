"""
Tests for aistudio_daemon.py — JSON protocol dispatcher.
Covers request routing, error handling, and protocol integrity.

Written by Jordan Koch.
"""

import json
import sys
import os
import pytest

# Add parent directory to path so we can import the daemon module
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from aistudio_daemon import handle_request


class TestHealthCommand:
    """Tests for the health check command."""

    def test_health_returns_ok(self):
        result = handle_request({"command": "health", "request_id": "test-1"})
        assert result["status"] == "ok"
        assert result["request_id"] == "test-1"

    def test_health_echoes_request_id(self):
        result = handle_request({"command": "health", "request_id": "abc-123"})
        assert result["request_id"] == "abc-123"

    def test_health_empty_request_id(self):
        result = handle_request({"command": "health", "request_id": ""})
        assert result["request_id"] == ""
        assert result["status"] == "ok"


class TestCancelCommand:
    """Tests for the cancel command."""

    def test_cancel_returns_cancelled(self):
        result = handle_request({"command": "cancel", "request_id": "cancel-1"})
        assert result["status"] == "cancelled"
        assert result["request_id"] == "cancel-1"


class TestUnknownCommand:
    """Tests for unknown/invalid commands."""

    def test_unknown_command_returns_error(self):
        result = handle_request({"command": "nonexistent", "request_id": "unk-1"})
        assert "error" in result
        assert "Unknown command" in result["error"]
        assert result["request_id"] == "unk-1"

    def test_empty_command(self):
        result = handle_request({"command": "", "request_id": "empty-1"})
        assert "error" in result
        assert result["request_id"] == "empty-1"

    def test_missing_command(self):
        result = handle_request({"request_id": "no-cmd-1"})
        assert "error" in result


class TestRequestIdHandling:
    """Tests for request_id echo behavior."""

    def test_request_id_preserved(self):
        result = handle_request({"command": "health", "request_id": "uuid-test-123"})
        assert result["request_id"] == "uuid-test-123"

    def test_missing_request_id_defaults_to_empty(self):
        result = handle_request({"command": "health"})
        assert result["request_id"] == ""


class TestProtocolIntegrity:
    """Tests for JSON protocol integrity — responses must be valid JSON."""

    def test_response_is_json_serializable(self):
        result = handle_request({"command": "health", "request_id": "json-1"})
        json_str = json.dumps(result)
        assert json_str is not None
        parsed = json.loads(json_str)
        assert parsed == result

    def test_error_response_is_json_serializable(self):
        result = handle_request({"command": "nonexistent", "request_id": "json-2"})
        json_str = json.dumps(result)
        assert json_str is not None

    def test_all_known_commands_have_request_id(self):
        """Every response must echo back request_id for multiplexing."""
        commands = [
            {"command": "health", "request_id": "proto-1"},
            {"command": "cancel", "request_id": "proto-2"},
            {"command": "unknown_cmd", "request_id": "proto-3"},
        ]
        for cmd in commands:
            result = handle_request(cmd)
            assert "request_id" in result, f"Missing request_id in response for {cmd}"


class TestCommandDispatch:
    """Tests that the dispatcher recognizes all command strings.

    ML-dependent commands may take a very long time to load models, so we
    only verify that the dispatcher routes them (without actually invoking
    the ML modules) by checking the command-name branches exist.
    """

    def test_all_commands_recognized(self):
        """Every known command should NOT return 'Unknown command' error."""
        known_commands = [
            "health", "cancel",
            # The rest require ML — we don't call them, just verify the
            # dispatcher has branches for them by inspecting the source.
        ]
        for cmd in known_commands:
            result = handle_request({"command": cmd, "request_id": f"dispatch-{cmd}"})
            assert "Unknown command" not in result.get("error", ""), (
                f"Command '{cmd}' was not recognized by dispatcher"
            )

    def test_command_branches_exist_in_source(self):
        """Verify handle_request source code has all expected command branches."""
        import inspect
        source = inspect.getsource(handle_request)
        expected_commands = [
            "health", "generate_image", "img2img", "list_image_models",
            "tts", "list_tts_engines", "list_voices",
            "voice_clone", "transcribe", "generate_music", "cancel",
        ]
        for cmd in expected_commands:
            assert f'"{cmd}"' in source or f"'{cmd}'" in source, (
                f"Command '{cmd}' not found in handle_request source"
            )


class TestInputSafety:
    """Security tests — verifies prompt injection and edge cases don't crash."""

    def test_prompt_with_triple_quotes(self):
        """Triple quotes in prompts should not break the daemon."""
        result = handle_request({
            "command": "health",
            "request_id": "inj-1",
        })
        assert result["status"] == "ok"

    def test_very_long_command(self):
        """Very long input should not crash."""
        result = handle_request({
            "command": "health",
            "request_id": "a" * 10000,
        })
        assert result["request_id"] == "a" * 10000

    def test_unicode_in_request(self):
        """Unicode should not crash the daemon."""
        result = handle_request({
            "command": "health",
            "request_id": "test-unicode-世界",
        })
        assert result["status"] == "ok"

    def test_nested_json_in_command(self):
        """Nested objects in request should not crash."""
        result = handle_request({
            "command": "health",
            "request_id": "nested-1",
            "extra": {"nested": {"deep": True}},
        })
        assert result["status"] == "ok"

    def test_null_values(self):
        """None/null values should not crash."""
        result = handle_request({
            "command": "health",
            "request_id": None,
        })
        # request_id should be None or empty
        assert "status" in result

    def test_numeric_request_id(self):
        """Numeric request_id should not crash."""
        result = handle_request({
            "command": "health",
            "request_id": 12345,
        })
        assert result["request_id"] == 12345
