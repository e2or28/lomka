"""Обёртки не должны принимать аварийный запуск Godot за успех."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class CheckWrappers(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        shutil.copytree(ROOT / 'tools', self.root / 'tools')
        for name in ('sim', 'game', 'tests'):
            (self.root / name).mkdir()
        (self.root / 'sim' / 'probe.gd').write_text('extends RefCounted\n')
        self.engine = self.root / 'godot'
        self.engine.write_text('#!/bin/bash\nprintf "%s\\n" "$ENGINE_OUTPUT"\nexit "$ENGINE_CODE"\n')
        self.engine.chmod(0o755)

    def run_check(self, script, output='', code=0):
        return subprocess.run(
            ['bash', str(self.root / 'tools' / script)],
            env={**os.environ, 'GODOT': str(self.engine),
                 'ENGINE_OUTPUT': output, 'ENGINE_CODE': str(code)},
            capture_output=True, text=True, timeout=15,
        )

    def test_expected_domain_error_is_allowed(self):
        result = self.run_check('test.sh', 'ERROR: expected rejection\nВСЕ ТЕСТЫ ПРОЙДЕНЫ: 1')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_nested_runtime_error_overrides_success_sentinel(self):
        result = self.run_check('test.sh', 'SCRIPT ERROR: invalid call\nВСЕ ТЕСТЫ ПРОЙДЕНЫ: 1')
        self.assertNotEqual(result.returncode, 0)

    def test_missing_sentinel_fails(self):
        self.assertNotEqual(self.run_check('test.sh').returncode, 0)

    def test_nonzero_exit_overrides_success_sentinel(self):
        self.assertEqual(self.run_check('test.sh', 'ВСЕ ТЕСТЫ ПРОЙДЕНЫ', 7).returncode, 7)

    def test_syntax_audit_rejects_engine_crash(self):
        self.assertNotEqual(self.run_check('audit_syntax.sh', 'engine crashed', 9).returncode, 0)

    def test_syntax_audit_rejects_script_load_failure(self):
        self.assertNotEqual(self.run_check('audit_syntax.sh', 'Failed to load script').returncode, 0)

    def test_status_propagates_failed_checks(self):
        # Никакого обращения к origin и настоящему движку в тесте обёртки.
        git = self.root / 'git'
        git.write_text('#!/bin/bash\nexit 0\n')
        git.chmod(0o755)
        for name in ('test.sh', 'smoke.sh'):
            (self.root / 'tools' / name).write_text('#!/bin/bash\necho broken\nexit 1\n')
        (self.root / 'tools' / 'code_stats.py').write_text('')
        result = subprocess.run(
            ['bash', str(self.root / 'tools' / 'status.sh')],
            env={**os.environ, 'PATH': str(self.root) + os.pathsep + os.environ['PATH']},
            capture_output=True, text=True, timeout=15,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('broken', result.stdout)


if __name__ == '__main__':
    unittest.main()
