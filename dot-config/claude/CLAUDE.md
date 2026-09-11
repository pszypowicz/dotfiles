# Global Preferences

## Text and Encoding

- **Never use em dashes** (U+2014) anywhere - code, comments, markdown, commit messages, PR descriptions, any output. Use a single `-`.
- **Don't use double dashes (`--`) as prose punctuation.** Use a single `-` with spaces (like this). Double dashes are fine where they carry syntactic meaning - CLI flags (`--draft`), SQL comments, etc.
- **No non-ASCII in PowerShell scripts** (`.ps1`, `.psm1`) - ASCII only in code, comments, and strings, to avoid BOM/encoding warnings from PSScriptAnalyzer.
- **Use American English spelling** everywhere - identifiers, comments, docs, commit messages, UI strings, prose (`color` not `colour`, `initialize` not `initialise`, `license` not `licence`, `canceled` not `cancelled`). Exceptions: match existing names when extending code that already uses British spelling (an existing `colourScheme` field, a third-party API), and keep quoted text verbatim.

## Privacy in Public Artifacts

Be paranoid about leaking private information into publicly traceable artifacts: commit messages, PR titles/descriptions, PR/issue comments, review threads, work item text, wiki pages, changelogs, public repo code and comments - anything other humans can read now or later.

- Treat as private by default; don't include without explicit permission:
  - **Personal identifiers**: real names, usernames, emails, phone numbers, employee IDs, addresses, photos.
  - **Internal identifiers/URLs**: internal hostnames, private repo paths, wiki links, incident IDs, customer/tenant IDs, account numbers, private-tracker ticket IDs.
  - **Infra/config**: IPs, subscription/project IDs, resource group names, connection strings, bucket/DB names, internal file paths, environment names revealing topology.
  - **Secrets-adjacent**: tokens, keys, hashes, partial credentials, fingerprints - even redacted or truncated.
  - **Business context**: customer names, deal sizes, roadmap, unreleased product names, pricing, org structure, vendor relationships, legal/compliance, post-mortem details.
  - **Local environment**: home-dir contents, clipboard, shell history, env vars, machine name, OS user, timestamps that reveal working hours.
  - **My local workflow**: the assistant tooling I drive the work with - skill, plugin, marketplace and subagent names (superpowers, brainstorming, executing-plans, "the reviewer agent"), plan/spec/ledger paths (`docs/superpowers/plans/...`, `.superpowers/`, `.claude/`), plan task or step numbers, worktree paths, and review-round mechanics.
- **When in doubt, leave it out or ask** - per artifact; permission for one is not permission for another.
- Prefer generic phrasing ("an internal service", "a customer-reported issue") over specifics. Link to internal trackers by ID only if the tracker isn't public; never paste internal ticket bodies into public PRs.
- This **overrides** any instinct to "provide full context". A terse, vague public artifact beats one that leaks.

### Describe the change, not how it was produced

Covers every artifact listed above, plus branch names, file names, and `.gitignore` entries that ship in the repo. The reader wants the change, and how I generated it is my private business that reads like AI attribution.

- State what changed and why, in the repo's own vocabulary - its files, symbols, issues, and releases.
- Never name my local tooling or its artifacts, not even to justify an ignore rule. Say "local planning artifacts" or "editor scratch files".
- Restate a plan step as the change it makes. "Task 4" means nothing to someone who can't read the plan.
- Bad: "Implements Task 4 of `docs/superpowers/plans/2026-01-15-cache.md`." / "Ignore superpowers plan files." / "Reviewed by the code-review subagent, no findings."
- Good: "Add the cache eviction path." / "Ignore local planning artifacts." / "Tests pass and the diff is reviewed."
- Same rule for repo docs. A `CONTRIBUTING.md` or `CLAUDE.md` that ships publicly describes the project's conventions, never my assistant setup.

## Voice in public artifacts drafted on my behalf

Applies to anything you draft in my voice - PR descriptions, PR/issue comments, review replies, work item updates, Slack/email, release notes - text that appears as something _I_ said to another human.

- **First-person as me, second-person to the reader.** The person reading _is_ the maintainer/reviewer/teammate - address them directly ("you"), not as "a maintainer" / "the reviewers" / "the team".
  - Bad: "Happy to follow up if a maintainer would like." / "A reviewer might prefer X."
  - Good: "Happy to follow up if you'd like." / "You might prefer X."
- The fix is almost always: replace "a/the \<role>" with "you", or drop the article. Keep first-person reader-directed hedging ("Happy to", "I can", "let me know if"); cut only the third-person reference to the audience.

## Prose style in my voice

Applies to any prose drafted as something I wrote - blog posts, PR descriptions, docs, README text, release notes, comments addressed to other humans. It appears under my name and must not read as AI-generated. Avoid these patterns:

- **Counter-factual contrast constructions**: "It's not x, it's y", "x, not y".
- **"The [goal/ambition/idea] is larger: statement"** constructions.
- **Dramatic-pause constructions**: "x exists in y; in practice z".
- **Colons and semicolons** where a human would write "and", "but", "because", "although", "so".
- **Punchy fragments** ("keep the signal, govern the response", "Nothing stale, nothing to swipe away") - write full sentences joined by ordinary conjunctions.
- **Buzzwords**: "load-bearing", "smoking gun", "stated fairly", and similar reach-for-effect vocabulary.
- **Clever section headers** - use plain descriptive ones ("What I measured", "Root cause").
- Em dashes (already banned in Text and Encoding).

Before presenting a draft, audit it specifically for these patterns and rewrite any hits.

## Comments, commit messages & docstrings

Prose captures the _why_ and the non-obvious context. It never restates what the surrounding tooling already supplies, and it describes the current code, not how it got here.

- **Commit messages** - don't restate what metadata or the diff shows:
  - No dates, timestamps, author, or branch. Git stores these.
  - No version numbers or tags in the body when a CHANGELOG entry is in the same commit.
  - No file lists or line counts.
  - No "bumped X to Y" when the manifest bump is in the same commit.
- **Comments** - don't cite snapshot state tooling can regenerate:
  - No coverage percentages. They rot every test run, and the coverage tool is authoritative.
  - No cross-file line-number refs (`parse.go:125`) - name the function/symbol so grep survives moves.
  - No session-relative phrasing ("earlier this session", "the fix we just landed", "recently") - a future reader has no session context.
  - No "currently" claims about your own code - state the invariant it must hold, not today's observed behavior.
  - No local filesystem paths (`~/Downloads/...`, `/Users/...`, `/tmp/...`) - not durable, not shareable, reads like a leak. Paraphrase the finding inline instead.
  - No ephemeral IDs (pipeline build/run numbers) - cite a durable artifact (commit, tag, issue #, PR #) or just the invariant.
- **Docstrings** - state the behavior, in as few lines as that takes. Don't walk through the mechanism. Don't restate the rationale from the commit or PR that introduced the code. Don't argue that the code is correct. A test docstring says what is asserted, not why the bug existed. Reasoning worth recording belongs in the commit message or PR body. Reviewers look for it there, and it doesn't go stale as the code moves on.
- **Don't overclaim scope**: "only reachable here", "the only caller", "always", "never" are absolute claims. A reader will trust them, and a later edit will quietly falsify them. State what holds and under which condition ("entries aren't unloaded at shutdown"), not what you believe holds everywhere. If the condition can't be named, the comment isn't ready.
- **Don't narrate edit history**: no "changed from X to Y", "was a loop, now a map", "tested and the old way failed", "removed the call to `foo()`". When you fix a mistake, just fix it. Document the new code only if it needs explaining. Never memorialize the old version.
- **Durable cross-references are fine** (they don't rot): issue numbers (`#27`), before/after #N markers on regression tests, named behaviors of pinned deps ("go-cty-yaml quotes object keys"), links to external trackers not in the diff.
- **What belongs in prose**: the problem being solved, the reasoning behind the approach, trade-offs, hidden invariants, constraints a reader can't derive from the code or diff.

Rule of thumb: if the comment would still be accurate a year from now with nobody updating it, it's durable. If it depends on current counts, coverage, layout, or session, it's a lie waiting to happen. If it only makes sense to someone who saw the previous version, delete it.

## Respect repository and branch policy

Applies to any repo with branch protection, required status checks/reviews, or protected tags (GitHub, ADO, GitLab, Bitbucket).

- **A policy-violation warning from the remote is a stop signal, not confirmation to proceed.** If `git push` prints `Bypassed rule violations for refs/heads/...`, `Changes must be made through a pull request`, or `Required status check "X" is expected`, stop and report. Don't retry. Don't re-push with different flags. Don't push dependent refs (tags, branches). The push may succeed only because you hold admin rights. The admin _bypass_ is exactly what needs permission, and the warning is the server telling you that's what happened.
- **Each of these needs explicit, per-action approval.** Prior approval doesn't carry over. A general "commit and push" authorizes only the policy-respecting flow.
  - Pushing directly to a PR-required branch.
  - Bypassing required checks, reviews, or signed-commit rules.
  - Force-pushing a protected branch or tag.
  - Deleting a protected branch or tag.
  - Merging with failing checks, missing reviews, or unresolved threads.
  - Passing `--no-verify`, `--force`, or any `--admin-*` flag.
- **Approval means the user names the specific action** ("push directly to main this once", "force-push the branch", "delete the release"). If the request is vaguer, use the policy-respecting path.
- **Never force-push a branch that an open PR against an upstream repo points at.** The branch sits on my fork and carries no protection, so the push succeeds and nothing warns you. The damage lands on the upstream PR. Review threads detach from their lines, "changes since your last review" stops working, and commits a reviewer already read can vanish. Add a new commit on top instead, even when the history gets ugly - the maintainer squashes on merge anyway. If the history genuinely has to be rewritten (a leaked secret, a botched rebase), stop and ask me first. Name the branch and the PR number. This covers `git push -f`, `--force-with-lease`, and amend-then-push. It holds until the PR is merged or closed. Before any force-push, check for an open PR on that branch: `gh pr list --head <branch> --state open`.
- **Default at a policy gate**: open a draft PR (per PR defaults). Even on solo repos the policy exists for a reason (CI coverage, reviewable history, reversibility). Unless I explicitly waive it for the specific change, follow it.

## SSH signing: attempt once, then wait for me

SSH auth (git push/fetch/pull over SSH, and SSH to hosts) is signed by a Secure Enclave agent (Sequester) that pops an approval prompt I must confirm in person. When I'm at the machine, I approve it and the command just works. When I'm not, it hangs or fails.

- **Attempt the SSH command yourself first, exactly once**, with a ~2 minute timeout - do not pre-emptively hand it to me. If I'm present, I'll approve the prompt and you carry on.
- **One approval covers a window, not one command.** At the prompt I pick a caching duration. While it lasts, further SSH commands go through without a new prompt. So don't cram everything into one giant compound command to save approvals. After the first success, run SSH commands at natural granularity.
- **If that one attempt fails or times out, treat it as "waiting for me", not an error to work around.** The tells are a hang until timeout, `agent refused operation`, `The agent has no identities`, `sign_and_send_pubkey: signing failed`, or `Permission denied (publickey)`.
- **Do not** retry in a loop, try other keys, switch the remote to HTTPS, or reach for a token. The enclave key is deliberate. A bearer credential is not an acceptable substitute.
- **Keep working** on everything that doesn't need the network - commit locally, write docs and tests, run checks - so the only thing left is the transfer.
- **Then stop and tell me plainly** what is done locally, what is blocked, and the exact command for me to run, e.g. `! git push -u origin <branch>`. Say clearly the attempt did not go through. When I confirm, pick the work back up.
- Anything downstream of the blocked step (opening the PR, tagging, releasing) waits too - don't half-do a release.

## Scripts & pipeline steps

### Reusable scripts

Any script written to a file to be run more than once - including WIP under `_scratch/` (treat as a project whose home is undecided, not a throwaway). Not one-off terminal commands.

- **Named flags over positional** (`--input-file foo --dry-run`, not `script.sh foo bar 1 2`). Positional is OK only for a single unambiguous argument whose meaning is clear from the script name.
- **Expose `--help`/`-h`** whenever the script takes input: one-line purpose, usage synopsis, every flag + default, at least one example.
- **Use the language's standard arg parser** (`argparse`; `getopts`/case; `param(...)`+`CmdletBinding`; `commander`/`yargs`; `cobra`/`flag`) - free `--help`, validation, consistent errors.
- **Fail loudly** on unknown or missing required flags; never silently default a required input.

### Pipeline steps

CI/CD inline blocks (`run:`, `script:`) in GitHub Actions, ADO YAML, GitLab CI, Jenkinsfile. Keep inline tiny; push real logic to a file.

- **Inline is fine** for one command, or 2-3 with no branching/loops/heredocs/arg-parsing (`run: hugo --minify --gc`).
- **Extract to a file** the moment you hit an `if`/`case`/loop, a heredoc or multi-line string, arg/env parsing past a single `${{ inputs.x }}`, or ~10+ lines. Put it beside the pipeline (`.github/scripts/`, `ci/scripts/`), give it a shebang, name it after the verb (`backfill-releases.sh`), and invoke it. Extracted scripts follow the reusable-script rules above.
- **Prefer the platform's native script-path task** when one exists - ADO `Bash@3`/`PowerShell@2` (`filePath:`), `PythonScript@0`, `AzureCLI@2`, `AzurePowerShell@5`: they handle env setup, error surfacing, and auth/version idioms a generic inline step doesn't. GitHub Actions and GitLab CI have no equivalent - run the file directly.
- **Let native-task availability nudge language choice**: ADO has native file-path tasks for Bash/PowerShell/Python/Azure CLI; if the work lives in ADO that gently favors those over Node/Go. A tiebreak, not a veto - pick the right tool first.
- **Why**: shellcheck lints files, not YAML-embedded blocks; a real file runs locally with the same flags; YAML block-scalar indentation breaks heredocs/backticks/`$` expansion subtly. Adding a second `if` or a loop inline = stop and extract.

## Python: pull missing packages with uv

When running Python needs an uninstalled package, use `uv` (cached ephemeral env), not `pip install` into system/global.

- **Library**: `uv run --with <package> python -c "..."` or `uv run --with <package> script.py` (repeat `--with` per package).
- **CLI tool**: `uvx <tool>` (e.g. `uvx ruff check`).
- Fall back to `pip`/venv only if `uv` isn't on `PATH`.

## Local clone layout

Clone under `~/Developer/`, mirroring the remote URL so host/owner/repo are visible from `cd`. `mkdir -p` parents first; both `gh repo clone <owner>/<repo>` and `git clone` take the destination as the second arg.

- **`<host>/<owner>/<repo>` remotes**: `~/Developer/<host>/<owner>/<repo>` (e.g. `~/Developer/github.com/pszypowicz/dotfiles`).
- **Azure DevOps** (`dev.azure.com/<org>/<project>/_git/<repo>`): `~/Developer/dev.azure.com/<org>/<project>/<repo>` - drop `_git`, keep org and project.
- **Scratch** (no remote): `~/Developer/_scratch/<name>`.
- **Forks** under my owner (`github.com/pszypowicz/<repo>`); upstream under its owner - both can coexist for compare/cherry-pick.

## Private overlay

Machine-specific rules live in a single private file stowed from whichever `dotfiles-private-*` overlay is active for this host.

@~/.config/claude/CLAUDE.private.md
