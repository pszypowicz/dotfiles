#!/usr/bin/env python3
"""Format Markdown and Terraform files named in a completed patch."""

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys


def changed_paths(patch):
    paths = []
    for line in patch.splitlines():
        if line.startswith(('*** Add File: ', '*** Update File: ',
                            '*** Delete File: ', '*** Move to: ')):
            paths.append(line.split(': ', 1)[1])
    return list(dict.fromkeys(paths))


def run_tool(name, arguments, cwd, warnings):
    executable = shutil.which(name)
    if executable is None:
        warnings.add(f'{name} is not installed. Formatting skipped.')
        return
    try:
        subprocess.run([executable, *arguments], cwd=cwd, check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       timeout=15)
    except (OSError, subprocess.SubprocessError):
        warnings.add(f'{name} failed. Run it manually to inspect the error.')


def main():
    parser = argparse.ArgumentParser(
        description='Format edited files from a Codex hook JSON payload on stdin.',
        epilog='Example: format-edits.py < hook-event.json')
    parser.parse_args()
    warnings = set()
    try:
        payload = json.load(sys.stdin)
        if payload.get('tool_name') != 'apply_patch':
            return
        patch = payload.get('tool_input', {}).get('command', '')
        cwd = Path(payload['cwd']).resolve()
        modules = set()
        for name in changed_paths(patch):
            path = (cwd / name).resolve()
            if path.suffix == '.md' and path.is_file():
                run_tool('prettier', ['--write', str(path)], cwd, warnings)
            elif path.suffix == '.tf':
                if path.is_file():
                    run_tool('terraform', ['fmt', str(path)], cwd, warnings)
                for directory in path.parents:
                    if (directory / '.terraform-docs.yml').is_file():
                        modules.add(directory)
                        break
                    if (directory / '.git').exists():
                        break
        for module in sorted(modules):
            run_tool('terraform-docs', ['.'], module, warnings)
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        warnings.add('Cannot read the patch event. Formatting skipped.')
    if warnings:
        print(json.dumps({'systemMessage': ' '.join(sorted(warnings))}))


if __name__ == '__main__':
    main()
