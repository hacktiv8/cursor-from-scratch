# Iterative Document Review — Lens-Rotation Prompt

A reusable prompt for reviewing an article, learning material, spec, or
design/implementation plan **in a loop**, where each run uses a *different
lens* instead of repeating the same generic pass.

## Why this design (read once)

Naive "review this again" loops plateau fast: the agent re-finds the same few
issues and relies on stochastic luck for new ones. The fix is to **rotate the
lens each run** so you probe a different dimension every time, and to
**accumulate findings in a persistent, de-duplicated log** so progress is
monotonic and you know when to stop.

Each invocation runs **one lens, deeply**. Re-invoke with the next lens. Stop
when two consecutive lenses find no new blocker/major issues.

---

## How to use

1. Put the target document path in `README.org`.
2. Pick a lens from the **Lens Roster** below and put it in `Audience simulator`.
3. Run the prompt. It appends to `LOOP-npm:pi-subagentsREVIEW-FINDINGS.md`.
4. Read the end-of-run report, pick the next lens, repeat.
5. Declare done when the convergence rule fires.

For hands-off operation: hand the whole file to an agent (or a Ralph loop / a
subagent chain) and tell it to iterate through the roster itself, one lens per
turn, following the accumulation + stopping rules.

---

## The prompt

```
You are a senior reviewer performing ONE focused review pass on a document.

TARGET DOCUMENT: README.org
THIS RUN'S LENS: Audience simulator   (see REVIEW-PROMPT.md "Lens Roster" for the exact
                            mandate of this lens. Do ONLY this lens. Go deep,
                            not broad. A deep single-lens pass beats a shallow
                            "find anything" pass every time.)

CONTEXT MODE: fresh. Read the document cold. Do not assume anything about it.
If a prior review's findings exist in REVIEW-FINDINGS.md, read them ONLY to
avoid re-reporting duplicates — do not let them anchor your judgment.

ACCUMULATION PROTOCOL (critical):
- Findings live in REVIEW-FINDINGS.md. If the file does not exist, create it
  with the header below.
- Before writing, scan existing entries. If a new finding duplicates an
  existing one (same location + same issue), do NOT re-add it; optionally
  refine the existing entry instead.
- Append each NEW finding as a row with these fields:
    ID | severity(blocker/major/minor/nit) | lens | location(section+line or
    quote) | issue | suggested fix | status(open)
- Keep entries terse and actionable. No prose essays in the log.

END-OF-RUN REPORT (always print this after updating the log):
- Lens run: Audience simulator
- New findings this run: N  (breakdown by severity)
- Duplicates skipped: M
- Convergence status: count of consecutive lenses (including this one) that
  produced 0 new blocker/major findings. "CONVERGED" when that count reaches 2.
- Recommended next lens from the roster, or "STOP — converged" if applicable.

DISCIPLINE:
- Quote exact text / line numbers so findings are locatable.
- Distinguish "wrong" from "missing" from "unclear" from "boring" — and only
  report the categories your lens owns. Other lenses will cover the rest.
- For code/commands/links/API names: if your lens is verification, actually
  check them; otherwise just flag "verify this" as a finding for that lens.
- Never invent issues to seem thorough. If this lens finds nothing new, say so
  honestly — that is a valid, useful result.

HEADER for a fresh REVIEW-FINDINGS.md:
# Review Findings — README.org
# Format: ID | severity | lens | location | issue | fix | status
```

---

## Lens Roster

Rotate through these. Each is a *different probe*, not a synonym for "review."

### Correctness family (what's wrong)
1. **Contradiction hunter** — internal contradictions; same fact stated
   differently in two places; claims that conflict with referenced docs/links.
2. **Expert reader / fact-checker** — technical errors, wrong API/feature
   names, code that won't run, outdated info, hallucinated capabilities.
3. **Verifier** — every link, command, file path, config key, version number,
   and code block. Does it actually work as written? (Agents routinely
   "read" their own output as correct — this lens exists to defeat that.)
4. **Pre-mortem** — "A reader followed this exactly and it went badly wrong.
   What broke, and at which step?" Surfaces edge cases & loopholes better than
   direct review.

### Clarity family (what's unclear)
5. **Beginner reader** — read as someone who knows ~30% of the jargon. Where
   do you stall? What term is used before it's defined? What prerequisite is
   silently assumed?
6. **Cold indexer** — assume zero context. List, in reading order, every place
   a reader would have to re-read, guess, or open another doc.

### Completeness family (what's missing)
7. **Missing-content auditor** — what SHOULD be here but isn't? Warnings,
   caveats, prerequisites, the "why" behind a choice, alternatives
   considered, edge cases, failure modes, "what not to do."
8. **Assumptions pass** (especially for plans/specs) — list every implicit
   assumption the doc depends on. Which are load-bearing? Which are fragile?

### Flow & engagement family (what's boring / poorly structured)
9. **Editor / arc** — is there a through-line? Does each section earn its
   place? Is there a hook in the first paragraph? Are transitions real or just
   headers? Is anything out of order?
10. **Engagement critic** — where is it flat, predictable, or lecture-y? Where
    would a reader put it down? Where's the tension, stakes, surprise, or
    before/after? Suggest concrete rewrites, not just "make it engaging."
11. **Audience simulator** — simulate the actual target reader (e.g. "meetup
    attendee, intermediate dev, skeptical"). Report the exact moment they'd
    get confused, bored, or doubt the author.

### Consistency family (what's sloppy)
12. **Consistency / formatting** — terminology drift, path/naming
    inconsistencies, inconsistent capitalization, image-reference hygiene,
    dead/orphaned sections, leftover scaffolding (e.g. COMMENT blocks, TODOs),
    format-specific issues (org-mode, markdown, etc.).

### Plan-specific lenses (for design/implementation plans)
13. **Dependency / ordering pass** — are step dependencies explicit? Is there
    a valid execution order? Any circular or hidden dependencies?
14. **Reversibility pass** — which steps are irreversible (migrations, schema,
    data, public API)? Are they called out and sequenced safely?
15. **Failure-at-step-N pass** — for each step: if it fails halfway, what's the
    state? Is it recoverable? Is there a rollback?
16. **Scope/effort sanity** — are slices actually independent and
    review-sized? Any "and then a miracle happens" steps?

---

## Stopping rule

**CONVERGED** when 2 consecutive lenses each produce 0 new blocker/major
findings. Then do one final **Verifier** pass and one final **Pre-mortem**
pass regardless — those two catch the expensive-to-miss stuff. Then stop.

## Tuning knobs
- **Model diversity:** rotate the model (or thinking level) between lenses.
  Same model = same blind spots; this is the single biggest free win most
  people miss.
- **Fresh context each lens:** don't carry the prior lens's reasoning forward
  — only the findings log. Anchoring bias is real.
- **Severity calibration:** blocker = reader can't succeed / factually wrong /
  broken code; major = confusing or missing something important; minor =
  polish; nit = style.
