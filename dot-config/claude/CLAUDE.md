# Global Preferences

## Text and Encoding

- **Never use em dashes** (U+2014) anywhere - in code, comments, markdown, commit messages, PR descriptions, or any other output. Use a single `-` instead.
- **Do not use double dashes (`--`) as prose punctuation either.** Use a single `-` with spaces around it (like this). Double dashes are still fine where they have syntactic meaning (CLI flags like `--draft`, SQL comments, etc.), just not as a stand-in for em dashes in writing.
- **No non-ASCII characters in PowerShell scripts** (`.ps1`, `.psm1`). Use only ASCII in code, comments, and string literals. This avoids BOM/encoding warnings from PSScriptAnalyzer.

## Security

- Never use `$()` subshells or `op` CLI to retrieve secrets from within Claude. Auth credentials must be pre-resolved in the shell environment before starting a session.

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
- **Durable cross-references are fine** because they don't rot: issue numbers (`#27`), "before/after #N" markers on regression tests, named behaviors of pinned dependencies ("go-cty-yaml quotes object keys"), and links to external trackers a reviewer would need that aren't in the diff.
- **What _does_ belong in prose**: the problem being solved, the reasoning behind the chosen approach, trade-offs considered, hidden invariants, and constraints a reader couldn't derive from the code or diff.

Rule of thumb: if a comment would still be accurate a year from now without anyone updating it, it's durable. If it depends on current test counts, current coverage, current file layout, or current session context, it isn't - and it will become a lie faster than you'd expect.

## Private overlay

Machine-specific rules live in a single private file stowed from whichever `dotfiles-private-*` overlay is active for this host.

@~/.config/claude/CLAUDE.private.md
