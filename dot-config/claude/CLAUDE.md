# Global Preferences

## Text and Encoding

- **Never use em dashes** (U+2014) anywhere - in code, comments, markdown, commit messages, PR descriptions, or any other output. Use a single `-` instead.
- **Do not use double dashes (`--`) as prose punctuation either.** Use a single `-` with spaces around it (like this). Double dashes are still fine where they have syntactic meaning (CLI flags like `--draft`, SQL comments, etc.), just not as a stand-in for em dashes in writing.
- **No non-ASCII characters in PowerShell scripts** (`.ps1`, `.psm1`). Use only ASCII in code, comments, and string literals. This avoids BOM/encoding warnings from PSScriptAnalyzer.

## Privacy in Public Artifacts

- **Be paranoid about leaking private information into publicly traceable artifacts.** This applies to commit messages, PR titles and descriptions, PR/issue comments, code review threads, work item text, wiki pages, changelogs, public repo code and comments, and anything else that ends up in a place other humans (teammates, auditors, the internet) can read now or later.
- Treat as private by default, and do **not** include in public artifacts without explicit permission:
  - Personal identifiers: real names, usernames, emails, phone numbers, employee IDs, physical addresses, photos.
  - Internal-only identifiers and URLs: internal hostnames, private repo paths, internal wiki links, incident IDs, customer/tenant IDs, account numbers, ticket IDs from private trackers.
  - Infra and config details: IP addresses, subscription/project IDs, resource group names, connection strings, bucket names, DB names, file paths on internal machines, environment names that reveal topology.
  - Secrets-adjacent data: tokens, keys, hashes, partial credentials, fingerprints - even "redacted" or truncated versions.
  - Business context: customer names, deal sizes, roadmap details, unreleased product names, pricing, internal org structure, vendor relationships, legal/compliance context, incident post-mortem details.
  - Local environment context: contents of the user's home directory, clipboard, shell history, env vars, machine name, OS user, timestamps that reveal working hours.
- **When in doubt, leave it out or ask.** If a piece of information _seems_ necessary for a public artifact but might be private, stop and ask the user explicitly whether to include it. Do not assume prior consent from earlier in the session or from other artifacts - permission for one artifact is not permission for another.
- Prefer generic phrasing over specifics: "an internal service", "a downstream consumer", "a customer-reported issue" instead of naming them. Link to internal trackers by ID only if the tracker itself is not public; never paste internal ticket bodies into public PRs.
- This rule **overrides** any instinct to be thorough or to "provide full context" in a commit/PR/comment. A terse, vague public artifact is strictly better than one that leaks information.

## Voice in public artifacts drafted on my behalf

Applies to any public artifact you draft in my voice - PR descriptions, PR/issue comments, code review replies, work item updates, Slack/email drafts, release notes - anywhere the text will appear as something _I_ said to another human.

- **First-person as me, second-person to the reader.** The audience reading the PR _is_ the maintainer / reviewer / teammate. Don't refer to them as "a maintainer", "the reviewers", "the team" as if they were a distant third party. Address them directly.
- **Bad** (distancing, sounds like narrating about the reader to someone else):
  - "Happy to follow up on either if a maintainer would like them."
  - "A reviewer might prefer the alternative approach."
  - "If the team wants X, I can do Y."
- **Good** (direct, addresses the actual reader):
  - "Happy to follow up on either in a separate PR if you'd like."
  - "You might prefer the alternative approach."
  - "If you want X, I can do Y."
- The failure mode is AI-drafting tendency to reach for formal/hedged phrasings that each sound fine in isolation but collectively read as if someone else is writing _about_ me to _about_ the maintainers. The fix is almost always: replace "a/the \<role>" with "you", or drop the article entirely.
- This does not mean stripping all hedging. "Happy to", "I can", "let me know if" are all fine - they're first-person and reader-directed. The thing to cut is the third-person reference to the audience.

## Don't duplicate tool-supplied metadata in prose

Applies to commit messages, code comments, docstrings, PR descriptions, and any other prose artifact that sits next to content some tool already tracks. The rule is the same across all of them: prose captures the _why_ and the non-obvious context; it does not restate facts the surrounding tooling already supplies.

- **Commit messages** should not restate what the commit metadata or diff already shows:
  - No dates, timestamps, author names, or branch names (git already stores these).
  - No version numbers or release tags in the message body when a CHANGELOG entry is part of the same commit (the CHANGELOG diff is the source of truth; repeating `CHANGELOG: vX.Y.Z` in the message is noise).
  - No file lists or line counts (the diff shows this).
  - No "bumped from X to Y" restatements when the version bump is visible in a manifest file in the same commit.
- **Code comments** should not cite snapshot-in-time state that tooling can produce on demand:
  - No coverage percentages ("was 0% covered", "sits at 45%") - these rot every test run and the coverage tool is authoritative.
  - No line-number references into other files (`parse.go:125`) - reference the function or symbol by name so grep stays useful when the file moves.
  - No session-relative phrasing ("earlier this session", "after the fix we just landed", "recently") - a future reader has no session context.
  - No "currently" claims about your own code's behavior - if the code changes, the comment drifts silently. State the invariant the code is supposed to hold, not the observation of what it does today.
  - **No references to local filesystem paths** like `~/Downloads/...`, `/Users/...`, `C:\Users\...`, `$HOME/...`, `/tmp/...`, or other paths that only exist on the author's machine. These are neither durable nor shareable; a teammate reading the PR on another host has no such file, and the reference looks like a private leak anyway. If a piece of investigation evidence lives in a personal notes file, either paraphrase the relevant finding inline or omit it - never link to a path only you can open.
  - **No references to specific pipeline build IDs, run numbers, or other ephemeral identifiers** inside code comments. Build `2548655` in a comment is noise to every future reader. Cite the durable artefact (commit, tag, issue #, PR #) or just state the invariant.
- **Durable cross-references are fine** because they don't rot: issue numbers (`#27`), "before/after #N" markers on regression tests, named behaviors of pinned dependencies ("go-cty-yaml quotes object keys"), and links to external trackers a reviewer would need that aren't in the diff.
- **What _does_ belong in prose**: the problem being solved, the reasoning behind the chosen approach, trade-offs considered, hidden invariants, and constraints a reader couldn't derive from the code or diff.

Rule of thumb: if a comment would still be accurate a year from now without anyone updating it, it's durable. If it depends on current test counts, current coverage, current file layout, or current session context, it isn't - and it will become a lie faster than you'd expect.

## Scripts meant to be reused

Applies to any script written to a file that is intended to be invoked more than once or maintained over time (bash, zsh, fish, pwsh, python, node, etc.) - including work-in-progress under `_scratch/` that has not yet been routed to a public or private repo. Treat scratch scripts as proper projects whose destination is undecided, not as throwaways. Does **not** apply to one-off commands pasted directly into a terminal.

- **Prefer named parameters over positional.** Flags like `--input-file foo --dry-run` self-document at the call site and survive argument reordering; `./script.sh foo bar 1 2` does not. Positional args are only acceptable when there is exactly one obvious argument (e.g. a single required path) and its meaning is unambiguous from the script's name.
- **Expose `--help` (and `-h`) whenever the script takes any input.** The help text should cover: one-line purpose, usage synopsis, every flag with its default, and at least one example invocation. A reader should not need to open the source to learn how to call it.
- **Use the language's standard argument parser** rather than hand-rolling flag handling: `argparse` (Python), `getopts` or a case-based parser (bash/zsh), `argparse` (fish), `param(...)` with `CmdletBinding` (PowerShell), `commander`/`yargs` (node), `cobra`/`flag` (Go). Standard parsers give you `--help`, type validation, and consistent error messages for free.
- **Fail loudly on unknown or missing required flags.** Do not silently fall back to defaults for required inputs.

Rule of thumb: if the script is saved to a file with the expectation that someone (including future-you) might run it again, it needs named flags and `--help`, regardless of whether its final home is decided yet.

## Pipeline scripts: extract once they outgrow trivial

Applies to CI/CD pipelines that embed shell (or Python / PowerShell) via `run:`, `script:`, or equivalent inline blocks - GitHub Actions, Azure DevOps YAML, GitLab CI, Jenkinsfile. The default is to keep the inline block tiny and push real logic into a file.

- **Inline is fine** for a single command, or two or three commands with no branching, no loops, no heredocs, no argument parsing. Examples: `run: hugo --minify --gc`, `run: python -m pytest -q`, `script: npm run build`.
- **Extract to a file** the moment any of these enter the picture:
  - an `if`, `case`, or loop,
  - a heredoc, `<<'EOF'` block, or multi-line string,
  - parsing environment variables or arguments past a single `${{ inputs.x }}` pass-through,
  - more than roughly 10 lines of logic.

  Put it alongside the pipeline config (`.github/scripts/`, `ci/scripts/`, `pipelines/scripts/`), give it a shebang, name it after the verb (`backfill-releases.sh`, not `release-step-3.sh`), and invoke it from the pipeline step. Extracted scripts inherit the "Scripts meant to be reused" rules above (named flags, `--help`).

- **Prefer the platform's native script-path task** when one exists - Azure DevOps `Bash@3` / `PowerShell@2` with `filePath:`, `PythonScript@0` with `scriptPath:`, `AzureCLI@2` with `scriptPath:`, `AzurePowerShell@5` with `ScriptPath:`; similar on Azure Pipelines and Jenkins declarative. These beat a generic inline step that shells out to the file because the native task handles env setup, error surfacing, and platform idioms (auth context, Python / PowerShell version pinning, tool-installer prereqs) that a generic shell step does not. GitHub Actions and GitLab CI mostly do not have equivalents; on those platforms, just run the extracted file directly.
- **Let native-task availability nudge language choice.** When picking a language for a nontrivial pipeline task, weigh which languages the target platform has a first-class script-path task for. Azure DevOps has native file-path tasks for Bash, PowerShell, Python, and Azure CLI; GitHub Actions and GitLab CI run everything through a generic shell step. If the work will live in ADO, that is a gentle nudge toward Bash / PowerShell / Python over, say, Node or Go - the native task removes boilerplate and makes the step self-contained. The nudge is not a veto: pick the right tool for the actual job first, then tiebreak on native-task availability.
- **Why the default matters** (so you can judge edge cases): `shellcheck` and friends lint files, not YAML-embedded blocks - extraction is how the code becomes reviewable. A real file can be run locally with the same flags the pipeline uses, so debugging doesn't require push-and-watch. YAML block-scalar indentation interacts subtly with heredocs, backticks, and `$` expansions; a `.sh` file is authoritative, a YAML embed is not.

Rule of thumb: if you're adding a second `if` or a loop inside an inline pipeline block, stop and extract. A file buys shellcheck, local execution, and an authoritative shebang for free; an inline block buys none of those.

## Private overlay

Machine-specific rules live in a single private file stowed from whichever `dotfiles-private-*` overlay is active for this host.

@~/.config/claude/CLAUDE.private.md
