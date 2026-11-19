#!/usr/bin/env python3
"""Deny shell commands that skip or switch off git hooks.

Reads a PreToolUse hook payload on stdin. A command that skips git hooks gets
a deny decision, and every other command passes without output.

These count as skipping hooks:
  - --no-verify on any git subcommand, and -n on git commit
  - git -c core.hooksPath=... or git -c hook.*=... for a single command
  - git config writes to core.hooksPath or hook.* keys

The check reads the shell text. Aliases, scripts, and environment overrides
such as GIT_CONFIG_GLOBAL are not covered.
"""

import argparse
import json
import os
import re
import shlex
import sys

WRAPPERS = {'sudo', 'command', 'env', 'exec', 'time', 'nice', 'nohup'}
OPERATORS = set(';&|()\n')

# Global git options whose value is the next word.
GIT_VALUE_OPTIONS = {'-C', '--git-dir', '--work-tree', '--namespace',
                     '--exec-path', '--super-prefix', '--list-cmds'}

# git commit short options whose value is the rest of the word or the next
# word, and short options that take an optional value in the rest of the word.
COMMIT_VALUE_SHORT = set('mFCct')
COMMIT_OPTIONAL_SHORT = set('uS')
COMMIT_VALUE_LONG = {'--message', '--file', '--author', '--date',
                     '--reuse-message', '--reedit-message', '--fixup',
                     '--squash', '--template', '--cleanup', '--trailer',
                     '--pathspec-from-file'}

CONFIG_READ_WORDS = {'--get', '--get-all', '--get-regexp', '--get-urlmatch',
                     '--get-color', '--get-colorbool', '-l', '--list',
                     'get', 'list'}
CONFIG_VALUE_OPTIONS = {'-f', '--file', '--blob', '--type', '--default',
                        '--comment', '--value'}


def hook_key(key):
    key = key.lower()
    return key == 'core.hookspath' or key.startswith('hook.')


def tokens(command):
    lexer = shlex.shlex(command, posix=True, punctuation_chars=';&|()\n')
    lexer.whitespace = ' \t\r'
    lexer.whitespace_split = True
    return list(lexer)


def segments(words):
    current = []
    for word in words:
        if word and set(word) <= OPERATORS:
            if current:
                yield current
            current = []
        else:
            current.append(word)
    if current:
        yield current


def git_arguments(segment):
    """Return the words after `git` when the segment runs git, else None."""
    for index, word in enumerate(segment):
        if os.path.basename(word) == 'git':
            return segment[index + 1:]
        if word in WRAPPERS or word.startswith('-'):
            continue
        if '=' in word and re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', word):
            continue
        return None
    return None


def commit_skips_hooks(arguments):
    skip_next = False
    for word in arguments:
        if skip_next:
            skip_next = False
            continue
        if word == '--':
            return False
        if word.startswith('--'):
            if word in COMMIT_VALUE_LONG:
                skip_next = True
            continue
        if not word.startswith('-') or word == '-':
            continue
        cluster = word[1:]
        for position, letter in enumerate(cluster):
            if letter == 'n':
                return True
            if letter in COMMIT_VALUE_SHORT:
                skip_next = position == len(cluster) - 1
                break
            if letter in COMMIT_OPTIONAL_SHORT:
                break
    return False


def config_writes_hook_key(arguments):
    if any(word in CONFIG_READ_WORDS for word in arguments):
        return False
    if not any(hook_key(word) for word in arguments):
        return False
    positional = []
    skip_next = False
    for word in arguments:
        if skip_next:
            skip_next = False
            continue
        if word in CONFIG_VALUE_OPTIONS:
            skip_next = True
            continue
        if word.startswith('-'):
            if word.startswith(('--unset', '--add', '--replace-all',
                                '--rename-section', '--remove-section')):
                return True
            continue
        positional.append(word)
    # `git config KEY` reads a value. Anything longer sets or removes one.
    return len(positional) != 1


def bypass_reason(arguments):
    index = 0
    while index < len(arguments):
        word = arguments[index]
        if word in ('-c', '--config-env'):
            value = arguments[index + 1] if index + 1 < len(arguments) else ''
            if hook_key(value.split('=', 1)[0]):
                return f'it overrides `{value.split("=", 1)[0]}` for one command'
            index += 2
            continue
        if word.startswith(('-c', '--config-env=')):
            value = word[2:] if word.startswith('-c') else word.split('=', 1)[1]
            if hook_key(value.split('=', 1)[0]):
                return f'it overrides `{value.split("=", 1)[0]}` for one command'
            index += 1
            continue
        if word in GIT_VALUE_OPTIONS:
            index += 2
            continue
        if word.startswith('-'):
            index += 1
            continue
        break
    if index >= len(arguments):
        return None

    subcommand, rest = arguments[index], arguments[index + 1:]
    if '--no-verify' in rest:
        return f'`git {subcommand} --no-verify` skips the hooks'
    if subcommand == 'commit' and commit_skips_hooks(rest):
        return '`git commit -n` skips the hooks'
    if subcommand == 'config' and config_writes_hook_key(rest):
        return 'it changes the hook configuration with `git config`'
    return None


def find_bypass(command):
    try:
        words = tokens(command)
    except ValueError:
        if re.search(r'\bgit\b', command) and '--no-verify' in command:
            return '`--no-verify` skips the hooks'
        return None
    for segment in segments(words):
        arguments = git_arguments(segment)
        if arguments is None:
            continue
        reason = bypass_reason(arguments)
        if reason:
            return reason
    return None


def deny(reason):
    print(json.dumps({
        'hookSpecificOutput': {
            'hookEventName': 'PreToolUse',
            'permissionDecision': 'deny',
            'permissionDecisionReason': reason,
        }
    }))


def main():
    parser = argparse.ArgumentParser(
        description='Deny shell commands that skip git hooks. Reads a '
                    'PreToolUse hook JSON payload on stdin.',
        epilog='Example: block-hook-bypass.py < hook-event.json')
    parser.parse_args()

    try:
        payload = json.load(sys.stdin)
        command = (payload.get('tool_input') or {}).get('command')
    except (ValueError, AttributeError):
        deny('The hook-bypass check could not read the tool call, so the '
             'call is blocked. Report this to the user.')
        return
    if not isinstance(command, str) or 'git' not in command:
        return

    reason = find_bypass(command)
    if reason:
        deny(f'Blocked because {reason}. The git hooks scan commits and '
             'pushes for secrets and run the repository checks. Fix what the '
             'hook reports and run the command again without the bypass. If '
             'the user explicitly asked to skip the hooks for this command, '
             'ask them to run it themselves with `! <command>`.')


if __name__ == '__main__':
    main()
