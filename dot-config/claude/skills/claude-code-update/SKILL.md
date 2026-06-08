---
name: claude-code-update
description: >-
  Check whether the Claude Code CLI is out of date, read the changelog between
  the installed and latest versions through the lens of this user's dotfiles,
  and (on approval) apply beneficial config changes then update the CLI. Use
  when the user says "update Claude Code", "check for a new Claude Code version",
  "is there a newer claude-code", "what changed in Claude Code", "review the
  Claude Code changelog", "should I update claude", or mentions
  "npm install @anthropic-ai/claude-code". This is about the Claude Code CLI
  tool itself - NOT the Claude API, the Anthropic SDK, or model selection.
---

# Claude Code update review

Turn "is there a new Claude Code, and does it change anything I care about?" into
one pass: detect versions, diff the changelog, map each entry onto this user's
dotfiles, summarize, apply approved config changes, then update the CLI.

The user keeps Claude Code pinned-by-habit (`DISABLE_UPDATES=1`), so updates go
through `npm install -g @anthropic-ai/claude-code@latest` - the same channel
`bootstrap` uses - never `claude update`.

## Repos this skill reasons about

- Main (public): `~/Developer/github.com/pszypowicz/dotfiles`
- Overlays (private): anything matching `~/Developer/github.com/pszypowicz/dotfiles-*`

Discover overlays with a glob each run rather than hardcoding names, so a new
overlay is picked up automatically:

```bash
ls -d ~/Developer/github.com/pszypowicz/dotfiles ~/Developer/github.com/pszypowicz/dotfiles-* 2>/dev/null
```

Respect the privacy boundary: public content never moves into the public repo
from an overlay, and overlay-specific changes land in the overlay, not the main
repo.

## Workflow

### 1. Detect and diff

Run the bundled script (it resolves installed + latest versions on its own):

```bash
SKILL_DIR="$(dirname "$0")"  # the skill's own directory
"$SKILL_DIR/scripts/claude-changelog-diff.sh"
```

Resolve the script path relative to this SKILL.md (it lives at
`scripts/claude-changelog-diff.sh` beside this file). Run `--help` if you need
the interface.

Branch on the output:

- **"Already up to date (X)."** - say so and stop. Nothing else to do.
- **Network failure** (non-zero exit, "failed to fetch changelog") - report it,
  then ask whether to retry or skip the analysis and go straight to the update
  proposal (step 5). Do not silently proceed as if there were no changes.
- **A slice of `## X.Y.Z` sections** - capture it and continue. If every section
  is only "Bug fixes and reliability improvements", say that plainly: there's
  nothing to map, so skip steps 2-4 and go to the update proposal.

### 2. Load dotfiles context

Read only the touchpoints a CLI changelog can actually affect, across the main
repo and every overlay found in step 1. Under each repo's `dot-config/`:

- `claude/settings.json` - the `env` block, `hooks`, `statusLine`,
  `enabledPlugins`, `extraKnownMarketplaces`, permissions/sandbox.
- `claude/hooks/bell.sh` and `claude/statusline.sh` - these parse hook and
  status-line JSON payloads, so payload-schema changes can break them.
- `fish/functions/claude.fish` and `fish/completions/claude.fish` - CLI flags,
  subcommands, and session-file schema.
- `fish/conf.d/env.fish` - `CLAUDE_CONFIG_DIR` and related exports.
- the repo's `bootstrap` - the `npm install -g @anthropic-ai/claude-code` line.
- an overlay's `claude/CLAUDE.private.md` or `claude/commands/` only when a
  changelog entry plausibly touches them.

### 3. Map each entry to this setup

For every non-trivial changelog bullet, classify it and decide if it matters here:

| Kind                                   | What to check in the dotfiles                                                                                                                      |
| -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| New/renamed **env var**                | Is it in the `settings.json` `env` block already? Would setting it help (or does the user's stance - e.g. telemetry off, updates off - mean skip)? |
| New/changed **settings key**           | Belongs in `settings.json`. Does the user have an equivalent? Is the default fine?                                                                 |
| New/changed **hook event or payload**  | Does `bell.sh` / `statusline.sh` rely on the old shape? Could a new event improve them?                                                            |
| New/changed **CLI flag or subcommand** | Does `claude.fish` (wrapper) or `completions/claude.fish` need to learn it?                                                                        |
| New **feature**                        | Could a hook, the statusline, or a completion now exploit it?                                                                                      |
| Bugfix / internal                      | Informational - no action.                                                                                                                         |

For each entry that matters, note: the exact file it touches, whether it is
already configured, and whether adopting it is a **clear win**, **optional**, or
**N/A for this setup** (with the reason - e.g. "user runs telemetry off").

### 4. Summarize

Present two buckets, relevant first:

- **Relevant to your setup** - one line per item: what changed, which file,
  current state, and a concrete proposed edit.
- **Informational / no action** - terse; collapse pure bugfixes into a count.

Be honest when the answer is "nothing here affects you" - that's the common case
and worth saying clearly rather than padding.

### 5. Apply approved config changes

For each proposed edit, confirm with the user first, then make it in the correct
repo (main vs the right overlay). Edits follow the user's house rules: ASCII only,
no em dashes or `--` as prose punctuation, no attribution/AI mentions, and new
env keys go inside the existing `settings.json` `env` block matching its style.

After edits, note whether a re-stow is needed (step 7).

### 6. Update the CLI (last, on approval)

Do this last so any new env var or setting the new version expects is already in
place. Propose and, on confirmation, run:

```bash
npm install -g @anthropic-ai/claude-code@latest
claude --version
```

Mention that `@latest` is typically ahead of the `stable` dist-tag (the script's
header shows the gap), so the user can pin a specific version instead if they
prefer the slower channel. The running Claude Code session keeps the old binary
until it restarts - say so.

### 7. Re-stow reminder

Edits to files already symlinked into `~/.config/claude` take effect
immediately. Brand-new tracked files (including this skill on first install) need
a re-stow to create their symlinks:

```bash
stow -d ~/Developer/github.com/pszypowicz -t ~ dotfiles --dotfiles --restow --no-folding
```

Remind the user to commit the dotfiles changes when they're ready (normal branch

- PR flow; this skill does not commit on its own).

## Boundaries

Read-only except for two things, each gated on explicit confirmation: the
approved `settings.json`/dotfiles edits, and the `npm install` update. Version
checks, the changelog fetch, and all file reads never mutate anything.
