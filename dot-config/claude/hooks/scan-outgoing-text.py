#!/usr/bin/env python3
"""Deny tool calls that would send a secret to an outside service.

Reads a PreToolUse hook payload on stdin and scans the text the call sends
with betterleaks. That text is every string in an MCP tool's input, and for
gh or az shell commands the command line plus the files those commands name.
A finding denies the call, and so does a scan that cannot run.

gh secret, gh auth, az login, and az keyvault commands exist to hand a
credential to its provider, so they are not scanned.
"""

import argparse
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys

# betterleaks exits 1 on its own errors too, so findings get a distinct code.
LEAK_EXIT = 42
MAX_FILE_BYTES = 1024 * 1024
SCAN_TIMEOUT_SECONDS = 15
FALLBACK_PATHS = ('/opt/homebrew/bin/betterleaks', '/usr/local/bin/betterleaks',
                  '/home/linuxbrew/.linuxbrew/bin/betterleaks')

EXEMPT_SUBCOMMANDS = {'gh': {'secret', 'auth'}, 'az': {'login', 'keyvault'}}
WRAPPERS = {'sudo', 'command', 'env', 'exec', 'time', 'nice', 'nohup'}
OPERATORS = set(';&|()\n')
BOUNDARY = r'[\s;&|(`"\']'
INVOCATION = re.compile(
    rf'(?:^|{BOUNDARY})(?:[^\s;&|(`"\']*/)?(gh|az)(?=\s|$)'
    r'(?:\s+([A-Za-z][\w-]*))?')


def deny(reason):
    print(json.dumps({
        'hookSpecificOutput': {
            'hookEventName': 'PreToolUse',
            'permissionDecision': 'deny',
            'permissionDecisionReason': reason,
        }
    }))


def find_betterleaks():
    found = shutil.which('betterleaks')
    if found:
        return found
    for candidate in FALLBACK_PATHS:
        if os.access(candidate, os.X_OK):
            return candidate
    return None


def sends_text_out(command):
    """True when the command runs gh or az outside the exempt subcommands."""
    for tool, subcommand in INVOCATION.findall(command):
        if subcommand not in EXEMPT_SUBCOMMANDS[tool]:
            return True
    return False


def tokens(command):
    lexer = shlex.shlex(command, posix=True, punctuation_chars=';&|()<>\n')
    lexer.whitespace = ' \t\r'
    lexer.whitespace_split = True
    return list(lexer)


def cli_arguments(command):
    """Yield the arguments of each non-exempt gh or az invocation."""
    try:
        words = tokens(command)
    except ValueError:
        return
    segment = []
    for word in words + ['\n']:
        if word and set(word) <= OPERATORS:
            arguments = invocation_arguments(segment)
            if arguments is not None:
                yield arguments
            segment = []
        else:
            segment.append(word)


def invocation_arguments(segment):
    for index, word in enumerate(segment):
        program = os.path.basename(word)
        if program in EXEMPT_SUBCOMMANDS:
            arguments = segment[index + 1:]
            subcommand = next((a for a in arguments if not a.startswith('-')), '')
            if subcommand in EXEMPT_SUBCOMMANDS[program]:
                return None
            return arguments
        if word in WRAPPERS or word.startswith('-'):
            continue
        if re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', word):
            continue
        return None
    return None


def file_candidates(argument):
    """Return paths an argument may upload: --flag=PATH, key=@PATH, @PATH, PATH."""
    if '=@' in argument:
        return [argument.split('=@', 1)[1]]
    if argument.startswith('@'):
        return [argument[1:]]
    if argument.startswith('--') and '=' in argument:
        return [argument.split('=', 1)[1]]
    if argument.startswith('-') or '=' in argument:
        return []
    return [argument]


def candidate_paths(arguments):
    """Return paths that the arguments of one gh or az invocation may upload.

    `< FILE` feeds the file in. The target of an output redirection or a
    heredoc delimiter is not a path to scan.
    """
    paths = []
    index = 0
    while index < len(arguments):
        argument = arguments[index]
        if argument and set(argument) <= set('<>&'):
            if argument == '<' and index + 1 < len(arguments):
                paths.append(arguments[index + 1])
            index += 2
            continue
        paths.extend(file_candidates(argument))
        index += 1
    return paths


def named_files(command, cwd):
    files = {}
    for arguments in cli_arguments(command):
        for candidate in candidate_paths(arguments):
            if not candidate or candidate == '-':
                continue
            path = Path(os.path.expanduser(candidate))
            if not path.is_absolute():
                path = Path(cwd) / path
            try:
                if path.is_file() and path.stat().st_size <= MAX_FILE_BYTES:
                    files[str(path)] = path.read_bytes()
            except OSError:
                continue
    return files


def strings_in(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for item in value.values():
            yield from strings_in(item)
    elif isinstance(value, list):
        for item in value:
            yield from strings_in(item)


class ScanError(Exception):
    pass


def scan(betterleaks, data):
    """Return (rule, line) pairs that betterleaks reports for the data."""
    try:
        result = subprocess.run(
            [betterleaks, 'stdin', '--no-banner', '--log-level', 'error',
             '--redact', '--ignore-gitleaks-allow',
             '--exit-code', str(LEAK_EXIT),
             '--report-format', 'json', '--report-path', '-'],
            input=data, capture_output=True, timeout=SCAN_TIMEOUT_SECONDS)
    except subprocess.TimeoutExpired as error:
        raise ScanError(f'betterleaks ran longer than {SCAN_TIMEOUT_SECONDS}s') from error
    except OSError as error:
        raise ScanError(f'betterleaks could not start: {error}') from error
    if result.returncode == 0:
        return []
    if result.returncode != LEAK_EXIT:
        detail = result.stderr.decode(errors='replace').strip().splitlines()
        raise ScanError(f'betterleaks exited {result.returncode}: '
                        f'{detail[-1] if detail else "no output"}')
    try:
        findings = json.loads(result.stdout or b'[]')
    except ValueError as error:
        raise ScanError('betterleaks returned a report that is not JSON') from error
    return [(f.get('RuleID', 'unknown-rule'), f.get('StartLine')) for f in findings]


def main():
    parser = argparse.ArgumentParser(
        description='Deny tool calls whose outgoing text contains a secret. '
                    'Reads a PreToolUse hook JSON payload on stdin.',
        epilog='Example: scan-outgoing-text.py < hook-event.json')
    parser.parse_args()

    try:
        payload = json.load(sys.stdin)
        tool_name = payload.get('tool_name') or ''
        tool_input = payload.get('tool_input') or {}
        cwd = payload.get('cwd') or os.getcwd()
    except (ValueError, AttributeError):
        deny('The outgoing-text secret scan could not read the tool call, so '
             'the call is blocked. Report this to the user.')
        return

    sources = []
    if tool_name.startswith('mcp__'):
        sources.append(('the tool input', '\n'.join(strings_in(tool_input)).encode()))
    else:
        command = tool_input.get('command') if isinstance(tool_input, dict) else None
        if not isinstance(command, str) or not sends_text_out(command):
            return
        sources.append(('the command', command.encode()))
        for path, data in named_files(command, cwd).items():
            sources.append((f'the file {path}', data))

    betterleaks = find_betterleaks()
    if betterleaks is None:
        deny('betterleaks is not installed, so the text this call would send '
             'out cannot be scanned for secrets. Ask the user to install it '
             'with `brew install betterleaks`.')
        return

    hits = []
    try:
        for label, data in sources:
            for rule, line in scan(betterleaks, data):
                where = f' (line {line})' if line else ''
                hits.append(f'{rule} in {label}{where}')
    except ScanError as error:
        deny(f'The secret scan of this call failed ({error}), so the call is '
             'blocked. Report this to the user.')
        return

    if hits:
        deny('Blocked because betterleaks found what looks like a secret in '
             f'the text this call would send out: {"; ".join(hits)}. Remove '
             'the secret and send the text without it. If this is a false '
             'positive, stop and ask the user how to proceed.')


if __name__ == '__main__':
    main()
