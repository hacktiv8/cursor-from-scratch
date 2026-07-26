# Review Loop - Multi-Persona Article Review

A shell-script orchestrator that runs an AI agent (Pi) through multiple reviewer personas against a single article file. Each persona finds and fixes issues from its unique perspective, commits, and hands off to the next.

## Why This Exists

AI agents tend to find only a few issues per run. Running the same review prompt multiple times surfaces different problems each time. This tool makes it systematic: **six distinct reviewer personas, each focused on one dimension of quality, run in sequence until your article is solid.**

```
start -> beginner -> skeptic -> expert -> edge-case -> editor -> copy-editor -> done
  |         |         |         |          |          |          |
  +-commit  +-commit  +-commit  +-commit   +-commit   +-commit   +-commit
```

## Quick Start

```bash
# Full run with Voice Guardian + two-phase (recommended)
REVIEW_MODEL=deepseek-v4-flash FIX_MODEL=deepseek-v4-pro ./scripts/review-loop.sh README.org

# Generate an HTML report instead of auto-repairing
./scripts/review-loop.sh README.org --report-html

# Single-phase: review and fix in one call per persona
./scripts/review-loop.sh README.org

# Dry-run to see what would run
./scripts/review-loop.sh README.org --dry-run

# Run only one reviewer
./scripts/review-loop.sh README.org --only beginner

# Resume from a specific reviewer
./scripts/review-loop.sh README.org --from expert --max-iterations 3
```

## Voice Guardian (Pre-flight)

If `reviewers/00-voice-guardian.md` exists, the script runs it once before all reviewers. It reads the article and extracts a **voice and tone profile** — analyzing formality, person, code-switching patterns, sentence rhythm, emotional register, and distinctive quirks.

This profile is injected into every subsequent reviewer's prompt so they:
- Preserve the author's authentic voice (not homogenize it toward generic writing)
- Respect code-switching patterns (e.g., Indonesian + English mix)
- Keep idiosyncratic formatting and rhetorical devices
- Skip fixes that would make the text "correct" but soulless

The Voice Guardian uses the fix model (stronger reasoning for nuanced analysis). If it fails, the loop continues without a profile — graceful degradation.

## Two-Phase Mode (Recommended)

Set `REVIEW_MODEL` and `FIX_MODEL` to split each reviewer into two phases:

```
Phase 1: REVIEW (cheap/fast model, NO edits)
  -> Reads the file, finds issues, outputs a structured report

Phase 2: FIX (strong/smart model, applies edits)
  -> Reads the report, applies each fix surgically
```

This gives you:
- **Cost efficiency**: flash is cheap for spotting issues; pro is only used for careful edits
- **Better fixes**: pro reasons better about whether a fix makes sense in context
- **Audit trail**: the review report shows what was found vs what was actually fixed

Example: 30 issues found by flash, 27 fixed by pro, 3 intelligently skipped because they required editorial judgment.

```bash
REVIEW_MODEL=deepseek-v4-flash FIX_MODEL=deepseek-v4-pro ./scripts/review-loop.sh README.org
```

Without `REVIEW_MODEL`, the script runs in single-phase mode (one call per persona).

## Report Mode (HTML Output)

Use `--report-html` to generate a self-contained HTML report of all findings instead of applying edits. Each reviewer produces a "find issues, don't edit" report, and all results are aggregated into a single dark-themed HTML file with:

- **Summary table** with issue counts per reviewer (anchor-linked)
- **Per-reviewer sections** with each finding in a styled block
- **Interactive checkboxes** to track which fixes you've completed
- **Voice & Tone Profile** in a collapsible section (if Voice Guardian runs)
- **Full original file** in a collapsible appendix

Report mode is for when you want to read the findings and fix things yourself, rather than trusting the AI to edit your file.

```bash
# Generate a report (path is auto-generated if omitted)
./scripts/review-loop.sh README.org --report-html

# Specify an output path
./scripts/review-loop.sh README.org --report-html /tmp/review.html

# Run only one reviewer for quick feedback
./scripts/review-loop.sh README.org --report-html --only expert

# Generate and commit the report to git
./scripts/review-loop.sh README.org --report-html --commit-report

# Use a specific model for reviews
./scripts/review-loop.sh README.org --report-html --review-model deepseek-v4-flash
```

**How it differs from two-phase mode:**
- Each reviewer sees the **original file** (not previous reviewers' fixes) — gives you independent perspectives
- No files are edited — your working tree stays untouched
- `FIX_MODEL` is ignored (no edits happen anyway)
- Git is optional — only needed with `--commit-report`
- The default output path is `review-report-<filename>-<timestamp>.html` in the current directory

## Reviewer Personas

| # | Persona | Focus |
|---|---|---|
| 0 | **Voice Guardian** | Pre-flight: extracts voice/tone profile for all other reviewers |
| 1 | **Beginner** | Jargon, prerequisites, unclear steps, assumed tooling |
| 2 | **Skeptic** | Unsupported claims, hand-waving, missing "why" |
| 3 | **Expert** | Technical accuracy, deprecated APIs, security, idiomatic code |
| 4 | **Edge Case Hunter** | Failure modes, platform gaps, boundary conditions |
| 5 | **Editor** | Structure, flow, heading hierarchy, voice/tone consistency |
| 6 | **Copy Editor** | Typos, grammar, consistent terminology, formatting |

Each persona has its own prompt file in `scripts/reviewers/`. Edit them to tune the reviewer's focus.

Optional reviewers in `scripts/reviewers/_optional/`:
- `dei-reviewer.md` - Inclusive language and diverse examples
- `code-reviewer.md` - Code-snippet-focused review
- `product-thinker.md` - Goal clarity and reader outcomes

Rename them to a numbered prefix (e.g., `07-dei-reviewer.md`) to activate.

## Requirements

- **Git repo** - the script commits after each review pass
- **Pi CLI** (`pi`) - or set `PI_CMD` to your agent command
- **Bash 3.2+** - works on macOS out of the box

## Configuration

| Env var | Default | Description |
|---|---|---|
| `PI_CMD` | `pi` | The CLI command for your AI agent |
| `REVIEW_MODEL` | (unset) | Model for review phase; enables two-phase mode |
| `FIX_MODEL` | `$REVIEW_MODEL` | Model for fix phase |
| `MAX_ITERATIONS` | `10` | Safety limit on number of passes |
| `REVIEWERS_DIR` | `scripts/reviewers/` | Path to reviewer prompt files |

| Flag | Description |
|---|---|
| `--report-html [PATH]` | Generate HTML report instead of editing |
| `--commit-report` | Git commit the HTML report after generation |
| `--review-model MODEL` | Model for review phase |
| `--fix-model MODEL` | Model for fix phase |
| `--dry-run` | Print what would run without executing |
| `--from PERSONA` | Start from a specific reviewer |
| `--only PERSONA` | Run only one specific reviewer |
| `--max-iterations N` | Stop after N passes (default: 10) |

## Git History

After a full run, `git log --oneline` looks like:

```
abc1234 review(copy-editor): 1 file changed, 45 insertions(+), 45 deletions(-)
def5678 review(editor): 1 file changed, 12 insertions(+), 8 deletions(-)
ghi9012 review(edge-case): 1 file changed, 23 insertions(+), 5 deletions(-)
jkl3456 review(expert): 1 file changed, 8 insertions(+), 6 deletions(-)
mno7890 review(skeptic): 1 file changed, 15 insertions(+), 10 deletions(-)
pqr1234 review(beginner): 1 file changed, 20 insertions(+), 12 deletions(-)
```

## Tuning Reviewers

Each `scripts/reviewers/*.md` file is a standalone prompt. To adjust a reviewer:

1. Edit the persona's `.md` file
2. The "What to look for" section defines the issues it hunts
3. The "How to fix" section defines its editing behavior
4. Be specific - these prompts are the only instructions the agent gets

## Adding Custom Reviewers

Create a new file in `scripts/reviewers/` with a numbered prefix:

```bash
# scripts/reviewers/07-security-auditor.md
```

The number controls ordering. Follow the format of existing files.

## Limitations and Gotchas

- **Context window**: Each pass is a fresh Pi session. Reviewers don't know what previous reviewers found (by design - keeps them independent).
- **Over-editing**: If a reviewer is too aggressive, it might restructure content another reviewer already fixed. The ordering (beginner -> copy-editor) minimizes this: foundational fixes come first, cosmetic fixes last.
- **Commit noise**: Six commits per run. Use `git rebase -i` to squash if desired.
- **Two-phase is ~2x slower**: Each reviewer runs twice (review + fix). But the review model is cheap/fast, so cost stays low.
- **Report mode is review-only**: No edits are applied to your file. Each reviewer sees the original file (not cumulative fixes). You'll get independent perspectives but may see redundant findings.
- **Pi CLI variance**: The `-p` and `--model` flags may differ by Pi version. Adjust `PI_CMD` as needed.
- **HTML line numbers are AI estimates**: The report includes a disclaimer. Search for quoted text to find exact locations.
