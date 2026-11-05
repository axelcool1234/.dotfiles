"""Integration tests for a built Pi wrapper: python sync-config.py /nix/store/...-pi."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

WRAPPER = Path(sys.argv.pop(1)).resolve()
ADVISOR = {
    "advisor": "openai-codex/gpt-6.1-sol",
    "advisorEffort": "high",
    "advisorDisableSameModel": False,
}


class ConfigSyncTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="pi config test ")
        self.addCleanup(self.temporary.cleanup)
        self.agent = Path(self.temporary.name) / "agent directory"
        self.env = {**os.environ, "PI_CODING_AGENT_DIR": str(self.agent)}

    def run_wrapper(self):
        return subprocess.run(
            [WRAPPER / "bin/pi", "--version"],
            env=self.env, capture_output=True, text=True, check=True,
        )

    def test_fresh_startup_creates_both_writable_configs(self):
        self.run_wrapper()
        generated = WRAPPER / "pi-config"
        for name in ("settings.json", "advisor.json"):
            target = self.agent / name
            self.assertEqual(json.loads(target.read_text()), json.loads((generated / name).read_text()))
            self.assertEqual(target.stat().st_mode & 0o777, 0o600)
            self.assertFalse(target.is_symlink())
        self.assertEqual(json.loads((self.agent / "advisor.json").read_text()), ADVISOR)

    def test_merge_preserves_preferences_and_is_idempotent(self):
        self.agent.mkdir(parents=True)
        (self.agent / "settings.json").write_text(json.dumps({
            "defaultModel": "stale", "userPreference": {"enabled": True},
        }))
        (self.agent / "advisor.json").write_text(json.dumps({
            "advisor": "old/model", "advisorEffort": "low", "advisorDisableSameModel": True,
            "advisorRedactSecrets": True, "advisorGitContext": "none",
            "userPreference": {"enabled": True},
        }))
        self.run_wrapper()
        advisor = json.loads((self.agent / "advisor.json").read_text())
        self.assertEqual({key: advisor[key] for key in ADVISOR}, ADVISOR)
        self.assertTrue(advisor["advisorRedactSecrets"])
        self.assertEqual(advisor["advisorGitContext"], "none")
        for name in ("settings.json", "advisor.json"):
            self.assertEqual(json.loads((self.agent / name).read_text())["userPreference"], {"enabled": True})
        before = {name: (self.agent / name).read_bytes() for name in ("settings.json", "advisor.json")}
        self.run_wrapper()
        self.assertEqual(before, {name: (self.agent / name).read_bytes() for name in before})

    def test_invalid_json_is_not_overwritten_and_temp_files_are_removed(self):
        self.agent.mkdir(parents=True)
        for name in ("settings.json", "advisor.json"):
            with self.subTest(name=name):
                target = self.agent / name
                target.write_text("{invalid JSON")
                command: list[str | Path] = [WRAPPER / "bin/sync-pi-config"]
                if name == "advisor.json":
                    command.extend([name, WRAPPER / "pi-config/advisor.json"])
                result = subprocess.run(command, env=self.env, capture_output=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(target.read_text(), "{invalid JSON")
                self.assertEqual(list(self.agent.glob(".*.XXXXXX")), [])
                self.assertEqual(sorted(path.name for path in self.agent.iterdir()), [name])
                target.unlink()


if __name__ == "__main__":
    unittest.main()
