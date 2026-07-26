# HTML Report Mode for review-loop.sh

## Context

The review-loop script currently has two modes:
- **Single-phase**: each reviewer reads the file, finds issues, and edits the file in one pass
- **Two-phase** (`REVIEW_MODEL` + `FIX_MODEL`): review phase finds issues → fix phase applies edits

The user wants a **third mode**: run all reviewer personas, collect their findings, and write a single HTML file they can read to fix issues manually. No auto-edits. No commits.

## Approach

Add a `--report-html <path>` flag. When set, the script runs in **report-only mode**: each reviewer gets a "find issues, do NOT edit" prompt (same as the existing two-phase review prompt), and all findings are aggregated into a single self-contained HTML file at the given path. Voice Guardian still runs first. Git is bypassed (no commits).

### What this mode inherits from existing code

- **Reviewer iteration**: Same `REVIEWERS` array, same `--from`, `--only`, `--max-iterations` logic.
- **Voice Guardian**: Runs as pre-flight, results injected into each reviewer's prompt (just like single-phase mode injects the tone profile).
- **Review prompt**: Reuses `build_review_prompt()` as-is — it already produces a structured "find issues, don't edit" report.
- **Model selection**: Uses `REVIEW_MODEL` if set, otherwise falls back to default `PI_CMD` behavior (same as `--review-model` flag).
- **`run_pi()` helper**: Used as-is.

### Design decisions

| Decision | Choice | Rationale |
|---|---|---|
| Independent or cumulative review? | **Independent** — each reviewer sees the original file | Cumulative would compound and have reviewers "fix" issues already noted; independent gives the user all perspectives raw |
| Single HTML or one per reviewer? | **Single HTML** with sections per reviewer | One file to open, scan, print |
| CSS strategy | **Self-contained** with inline `<style>` | Portable, no external dependencies |
| Replace or append on re-run? | **Overwrite** the output path | Predictable; user controls versioning if they want history |
| Summary section | **Yes** — issue counts per reviewer at the top, with anchor links | Quick scan of what's most problematic |
| Per-finding structure | **Location · Problem · Suggested fix** | Mirrors `build_review_prompt()` output format |
| Severity tagging | **Optional** — reviewers can tag `[blocker]`, `[major]`, `[minor]`, `[nit]` in their report | The prompt already asks for structured entries; severity is a natural extension |
| Interactive checkboxes | **Yes** — each finding gets a `<input type="checkbox">` | User checks off fixes as they complete them |
| Voice Guardian | **Runs** — tone profile injected so reviewers flag voice-breaking issues too | But they won't fix them; they'll just note "this would break voice" |
| Two-phase interaction | **N/A** — report mode is review-only. If `REVIEW_MODEL` is set, it's used for the review calls; `FIX_MODEL` is ignored | Document this in help text |

## Things you might not have thought of

1. **Reviewers checking each other**: In auto-repair mode, reviewer B sees reviewer A's edits. In report mode they all see the original. This means you'll get redundant findings (two reviewers flag the same sentence for different reasons). The HTML should group/note duplicates? Or leave that to the human? **Recommendation**: leave it — deduplication is lossy and a human can scan past repeats.

2. **The report HTML should carry metadata**: When it was generated, which file, which reviewers ran, model used, Voice Guardian profile. Put it in a `<header>` at the top — it's invaluable when you revisit a report from last week.

3. **Git integration is off by default — but you might want to commit the report**: Add `--commit-report` that commits the HTML file after generation. Useful for audit trails.

4. **The report file path should default smartly**: If not given, generate something like `review-report-<filename>-<timestamp>.html` next to the source file.

5. **Voice Guardian output should be included in the report**: The extracted tone profile is interesting context for the human. Embed it in a collapsible section.

6. **Line number accuracy**: The AI's "line number" estimates are unreliable. The HTML should warn the reader: "Line numbers are AI estimates — search for the quoted text."

7. **Diff previews**: You could include a rendered diff snippet per finding (old text / new text). But this requires the AI to output exact old→new text, which `build_review_prompt` already asks for ("old text -> new text"). The HTML can style these as side-by-side diffs.

8. **Print stylesheet**: If someone wants to print the report and work from paper, include a `@media print` block.

9. **Dark/light mode**: Use `color-scheme: light dark` and system colors so the report looks good in both.

10. **--dry-run should describe report mode**: Show which reviewers, output path, etc.

11. **The report could also embed the full original text** in a `<details>` section at the bottom, so the report is fully self-contained even if the file changes later.

## Files to modify

- **`scripts/review-loop.sh`** — main changes: new flag parsing, new `REPORT_MODE` codepath in the main loop, new `generate_html_report()` function
- **`review-loop.README.md`** — document the new flag and mode

## Reuse

| Existing thing | File | How it's reused |
|---|---|---|
| `build_review_prompt()` | `scripts/review-loop.sh` | Used as-is for each reviewer's prompt |
| `run_pi()` | `scripts/review-loop.sh` | Used as-is to invoke Pi |
| Voice Guardian pre-flight | `scripts/review-loop.sh` | Runs identically before reviewers |
| Reviewer collection & filtering | `scripts/review-loop.sh` | `--from`, `--only`, `--max-iterations` all work the same |
| `$REVIEW_MODEL` | `scripts/review-loop.sh` | Used for review calls; `$FIX_MODEL` is ignored (with a warning) |
| Reviewer `.md` files | `scripts/reviewers/` | Same prompts, different instruction wrapper |

## Steps

- [ ] 1. Add `--report-html` and `--commit-report` flag parsing to the argument loop
- [ ] 2. Add a `REPORT_MODE` detection block (similar to `TWO_PHASE` detection)
- [ ] 3. Add validation: if `REPORT_MODE` + `FIX_MODEL` is set, print a note that `FIX_MODEL` is ignored in report mode
- [ ] 4. Add default output path logic: if `--report-html` is given without a path, default to `review-report-<basename>-<ISO timestamp>.html`
- [ ] 5. Build the main report-mode loop in the reviewer iteration:
  - Run each reviewer with `build_review_prompt`, collect output to a temp file
  - Store each reviewer's output in an associative array keyed by `DISPLAY_NAME`
  - Track pass/fail per reviewer
- [ ] 6. Write `generate_html_report()` function that:
  - Opens with `<!DOCTYPE html>`, `<meta charset>`, `<meta viewport>`, `<title>`
  - Inline `<style>` with: system font stack, responsive layout, dark mode support, print styles, diff styling, severity badges, checkbox styling
  - Header metadata section (file, timestamp, reviewers, model, Voice Guardian profile in `<details>`)
  - Summary table with issue counts per reviewer (anchor-linked)
  - Each reviewer section: `<h2>` with reviewer name, each finding as a styled block with checkbox, severity badge, location, problem, suggested fix
  - Collapsible appendix with full original file text
- [ ] 7. Wire Voice Guardian tone profile into `build_review_prompt` for report mode (reviewers should know the voice even though they're not editing)
- [ ] 8. Add `--commit-report` support: `git add` + `git commit` the HTML file after generation
- [ ] 9. Update `--dry-run` to describe report mode
- [ ] 10. Update `review-loop.README.md` with new mode documentation

## Verification

1. **Smoke test**: `./scripts/review-loop.sh README.org --report-html /tmp/report.html --only beginner`
   - Verify HTML opens in browser
   - Verify it contains reviewer name, findings, checkboxes
   - Verify Voice Guardian profile is embedded (collapsible)
   - Verify original file text is in appendix

2. **Full run**: `./scripts/review-loop.sh README.org --report-html /tmp/report.html --max-iterations 2`
   - All reviewers run, HTML aggregates all sections
   - Summary table at top has correct counts per reviewer

3. **Edge cases**:
   - Reviewer that finds zero issues → section says "No issues found" with green styling
   - Reviewer that fails/crashes → section says "Review failed" with error styling
   - Default path: run without explicit path → file appears next to source
   - `--dry-run` shows report mode info
   - `--from` and `--only` work in report mode

4. **HTML quality**:
   - Valid HTML5
   - Renders correctly in Chrome, Firefox, Safari
   - Dark mode follows system preference
   - Print layout is clean (hide checkboxes, expand all collapsed sections)
