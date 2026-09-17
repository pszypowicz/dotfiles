import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class CodexHooksTest(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.log = self.root / 'calls.jsonl'
        self.env = dict(os.environ, PATH=str(self.bin) + ':' + os.environ['PATH'],
                        TEST_LOG=str(self.log))

    def tool(self, name, body):
        script = self.bin / name
        script.write_text('#!/usr/bin/env python3\n' + body)
        script.chmod(0o755)

    def run_hook(self, name, command, tool_name):
        payload = dict(cwd=str(self.root), tool_name=tool_name,
                       tool_input={'command': command})
        return subprocess.run([str(ROOT / 'etc/codex/hooks' / name)],
                              input=json.dumps(payload), text=True,
                              capture_output=True, env=self.env, check=True)

    def test_patch_formats_changed_files_and_refreshes_module_once(self):
        for tool in ('prettier', 'terraform', 'terraform-docs'):
            self.tool(tool, 'import json, os, sys\n'
                      'with open(os.environ["TEST_LOG"], "a") as f:\n'
                      ' f.write(json.dumps([os.path.basename(sys.argv[0]), sys.argv[1:], os.getcwd()]) + "\\n")\n')
        for name in ('notes with spaces.md', 'renamed.md', 'main.tf', 'outputs.tf', 'untouched.md'):
            (self.root / name).write_text('content\n')
        (self.root / '.terraform-docs.yml').write_text('formatter: markdown\n')
        patch = ('*** Begin Patch\n*** Update File: notes with spaces.md\n'
                 '*** Update File: old.md\n*** Move to: renamed.md\n'
                 '*** Add File: main.tf\n*** Update File: outputs.tf\n'
                 '*** Delete File: removed.md\n*** End Patch\n')
        result = self.run_hook('format-edits.py', patch, 'apply_patch')
        self.assertEqual(result.stdout, '')
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        self.assertEqual(sum(call[0] == 'terraform-docs' for call in calls), 1)
        formatted = [Path(call[1][-1]).name for call in calls if call[0] != 'terraform-docs']
        self.assertCountEqual(formatted, ['notes with spaces.md', 'renamed.md', 'main.tf', 'outputs.tf'])

    def test_formatter_reports_failure_without_blocking(self):
        self.tool('prettier', 'import sys\nsys.exit(1)\n')
        (self.root / 'notes.md').write_text('content\n')
        result = self.run_hook('format-edits.py', '*** Begin Patch\n*** Add File: notes.md\n*** End Patch', 'apply_patch')
        self.assertIn('prettier', json.loads(result.stdout)['systemMessage'])

    def test_deleted_terraform_file_refreshes_docs_without_formatting(self):
        self.tool('terraform-docs', 'import os\n'
                  'with open(os.environ["TEST_LOG"], "a") as f: f.write("docs\\n")\n')
        self.tool('terraform', 'raise AssertionError("Cannot format a deleted file")\n')
        (self.root / '.terraform-docs.yml').write_text('formatter: markdown\n')
        result = self.run_hook('format-edits.py',
                               '*** Begin Patch\n*** Delete File: variables.tf\n*** End Patch',
                               'apply_patch')
        self.assertEqual(result.stdout, '')
        self.assertEqual(self.log.read_text(), 'docs\n')

    def test_formatter_ignores_other_tools(self):
        result = self.run_hook('format-edits.py', 'echo hello', 'Bash')
        self.assertEqual(result.stdout, '')
        self.assertFalse(self.log.exists())

    def test_formatter_ignores_deleted_and_unrelated_files(self):
        result = self.run_hook('format-edits.py',
                               '*** Begin Patch\n*** Delete File: removed.md\n'
                               '*** Add File: missing.md\n*** Update File: code.py\n*** End Patch',
                               'apply_patch')
        self.assertEqual(result.stdout, '')
        self.assertFalse(self.log.exists())

    def test_force_push_guard(self):
        subprocess.run(['git', 'init', '-q', str(self.root)], check=True)
        subprocess.run(['git', '-C', str(self.root), 'remote', 'add', 'origin',
                        'https://github.com/example/project.git'], check=True)
        self.tool('gh', 'import os, sys\n'
                  'sys.exit(1) if os.environ.get("TEST_GH_FAIL") else None\n'
                  'print(os.environ.get("TEST_PRS", "[]"))\n')
        self.env['TEST_PRS'] = '[{"number": 1, "url": "https://github.com/example/project/pull/1"}]'
        for command in ('git push --force origin topic', 'git push -fu origin topic',
                        'git push origin +HEAD:topic', 'git push --force-with-lease origin topic'):
            with self.subTest(command=command):
                result = self.run_hook('block-force-push.sh', command, 'Bash')
                self.assertEqual(json.loads(result.stdout)['hookSpecificOutput']['permissionDecision'], 'deny')
        self.assertEqual(self.run_hook('block-force-push.sh', 'git push origin topic', 'Bash').stdout, '')
        self.env['TEST_PRS'] = '[]'
        self.assertEqual(self.run_hook('block-force-push.sh', 'git push -f origin topic', 'Bash').stdout, '')
        self.env['TEST_GH_FAIL'] = '1'
        self.assertEqual(json.loads(self.run_hook('block-force-push.sh', 'git push -f origin topic', 'Bash').stdout)['hookSpecificOutput']['permissionDecision'], 'deny')

    def test_bootstrap_installs_hooks_and_skips_matching_files(self):
        package = self.root / 'package'
        shutil.copytree(ROOT / 'etc', package / 'etc')
        installed = self.root / 'installed'
        bootstrap = package / 'bootstrap'
        bootstrap.write_text((ROOT / 'bootstrap').read_text().replace('"/etc/codex"', json.dumps(str(installed))))
        self.tool('sudo', 'import os, sys\n'
                  'with open(os.environ["TEST_LOG"], "a") as f: f.write("sudo\\n")\n'
                  'os.execvp(sys.argv[1], sys.argv[1:])\n')
        def run():
            return subprocess.run(['bash', str(bootstrap), 'codex'], env=self.env,
                                  capture_output=True, text=True, check=True)
        run()
        for relative in ('config.toml', 'hooks/block-force-push.sh', 'hooks/format-edits.py'):
            self.assertEqual((installed / relative).read_bytes(), (package / 'etc/codex' / relative).read_bytes())
        self.log.unlink()
        run()
        self.assertFalse(self.log.exists())
        (installed / 'hooks/format-edits.py').write_text('stale\n')
        run()
        self.assertTrue(self.log.exists())
        self.assertEqual((installed / 'hooks/format-edits.py').read_bytes(), (package / 'etc/codex/hooks/format-edits.py').read_bytes())


if __name__ == '__main__':
    unittest.main()
