"""Exercise command routing and daemon repair without touching a real server."""

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
MOCK = r"""#!/usr/bin/env python3
import json, os, pathlib, sys
tool = pathlib.Path(sys.argv[0]).name
scenario = os.environ['CODEX_TEST_SCENARIO']
if tool == 'lsof':
    print('4242\n4243' if scenario == 'ambiguous' else '4242')
elif tool == 'realpath':
    print(sys.argv[1])
elif tool == 'ps':
    field = sys.argv[-1]
    if field == 'uid=':
        print(os.getuid() + (1 if scenario == 'wrong_user' else 0))
    elif field == 'comm=':
        print('other-process' if scenario == 'wrong_process' else 'codex')
    elif field == 'command=':
        print('codex app-server --listen unix://')
    elif field == 'lstart=':
        print('Sat Oct 24 13:39:28 2026')
    elif field == 'ppid=':
        print('4242')
else:
    log = pathlib.Path(os.environ['CODEX_TEST_LOG'])
    with log.open('a') as output:
        output.write(json.dumps(sys.argv[1:]) + '\n')
    verb = sys.argv[3] if len(sys.argv) > 3 else ''
    if verb == 'version':
        finished = log.read_text().count('"version"') > 1
        running = finished or scenario in ('ancestor', 'ambiguous', 'wrong_user', 'wrong_process')
        version = '0.164.0' if finished and scenario == 'mismatch' else '0.166.0'
        print(json.dumps(dict(status='running' if running else 'notRunning', backend='pid',
            cliVersion='0.166.0', managedCodexVersion='0.166.0', appServerVersion=version,
            socketPath='/unused/control.sock')))
    elif verb == 'update':
        print(json.dumps(dict(status='unsupported' if scenario == 'unsupported' else 'updated')))
    elif verb == 'bootstrap':
        print(json.dumps(dict(autoUpdateEnabled=scenario != 'no_updater')))
"""


class CodexCommandsTest(unittest.TestCase):
    """Keep unsafe repair attempts read-only and route CLI updates to the daemon."""

    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix=".codex-test-", dir=REPO / "tests")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.bin_dir = self.root / "bin"
        self.bin_dir.mkdir()
        for tool in ("codex", "lsof", "ps", "realpath"):
            target = self.bin_dir / tool
            target.write_text(MOCK)
            target.chmod(0o755)
        self.codex_home = self.root / "codex-home"
        self.managed = self.codex_home / "packages/app-server-daemon/current/bin/codex"
        self.managed.parent.mkdir(parents=True)
        self.managed.write_text(MOCK)
        self.managed.chmod(0o755)
        self.log = self.root / "commands.jsonl"
        self.environment = os.environ | {
            "CODEX_HOME": str(self.codex_home),
            "CODEX_TEST_LOG": str(self.log),
            "CODEX_TEST_SCENARIO": "success",
            "PATH": f"{self.bin_dir}:{os.environ['PATH']}",
        }

    def run_command(
        self, name: str, *args: str, scenario: str = "success"
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(REPO / "bin" / name), *args],
            env=self.environment | {"CODEX_TEST_SCENARIO": scenario},
            capture_output=True,
            text=True,
            check=False,
        )

    def calls(self) -> list[list[str]]:
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def test_cli_forwards_arguments_without_shell_expansion(self) -> None:
        args = ["-c", "model='some model'", "a; $(false)"]
        result = self.run_command("codex", *args)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [args])

    def test_update_uses_native_daemon_updater(self) -> None:
        result = self.run_command("codex", "update")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [["app-server", "daemon", "update"]])

    def test_repair_requires_matching_versions_and_live_updater(self) -> None:
        result = self.run_command("codex-daemon-repair")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Native automatic updates are running", result.stdout)
        self.assertEqual(
            [call[2] for call in self.calls()], ["version", "update", "bootstrap", "version"]
        )

    def test_check_never_updates_or_restarts(self) -> None:
        result = self.run_command("codex-daemon-repair", "--check", scenario="ancestor")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [["app-server", "daemon", "version"]])

    def test_unsafe_socket_owners_stop_before_any_mutation(self) -> None:
        for scenario in ("ancestor", "ambiguous", "wrong_user", "wrong_process"):
            with self.subTest(scenario=scenario):
                self.log.write_text("")
                result = self.run_command("codex-daemon-repair", scenario=scenario)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.calls(), [["app-server", "daemon", "version"]])

    def test_failed_native_update_is_not_reported_as_success(self) -> None:
        result = self.run_command("codex-daemon-repair", scenario="unsupported")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("production update did not complete", result.stderr)
        self.assertEqual(len(self.calls()), 2)

    def test_inactive_updater_is_not_reported_as_success(self) -> None:
        result = self.run_command("codex-daemon-repair", scenario="no_updater")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("updater is not running", result.stderr)

    def test_version_mismatch_is_not_reported_as_success(self) -> None:
        result = self.run_command("codex-daemon-repair", scenario="mismatch")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("still differ", result.stderr)

    def test_remote_control_setting_survives_repair(self) -> None:
        settings = self.codex_home / "app-server-daemon/settings.json"
        settings.parent.mkdir()
        settings.write_text('{"remoteControlEnabled": true}')
        result = self.run_command("codex-daemon-repair")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(["app-server", "daemon", "bootstrap", "--remote-control"], self.calls())


if __name__ == "__main__":
    unittest.main()
