# Iterative Document Fix — Surgical-Edit Prompt

The companion to LOOP-REVIEW-PROMPT.md. The review prompt *finds* issues and
appends them to `REVIEW-FINDINGS.md`; this prompt *fixes* them by editing the
document. They are deliberately separate prompts (see "Why separate" below).

## Why separate review and fix (read once)

Three failures hit any "review-and-fix-in-one-pass" loop:

1. **Anchoring.** The agent that just found issue X fixes it the most obvious
   way and never considers a better fix. Fresh context for the fix beats
   "fix-what-you-just-saw."
2. **Shallow both ways.** Critical reading and constructive editing are
   different modes. Doing both at once makes each shallow.
3. **No accumulation.** If every pass re-finds and re-fixes from scratch,
   there's no monotonic progress and no way to know when you're done.

Separating them gives you a findings backlog (the review prompt's output) that
the fix prompt works down like a queue. Progress is visible. Stopping is
well-defined.

## Why this fix prompt looks the way it does

The default failure mode of a fix pass is **over-rewriting**: the agent
"improves" prose near the finding, drifts the author's voice, touches 10× more
lines than necessary, and introduces new issues. Every design choice below
exists to defeat that:

- **Surgical edits.** Change the minimum text that resolves the finding. A
  3-line fix beats a 30-line rewrite. The end-of-run report flags large line
  counts as a regression signal.
- **Severity-first batching.** Blockers before majors before minors. This
  prevents *priority inversion* (the agent grinds easy nits to look productive
  while a blocker rots) and means a blocker that deletes a section also
  dissolves the nits inside it — so you don't waste fix budget on soon-to-be-
  gone text.
- **Fix-then-verify.** After each edit, re-read the changed region and confirm
  the finding is actually resolved (not just "edited near"). Agents routinely
  claim they fixed something they touched but didn't fix.
- **Dependent-finding re-validation.** Fixing finding A often invalidates
  finding B in the same region. The protocol forces the agent to re-check
  dependents instead of leaving stale open findings or falsely closing them.
- **Voice preservation.** An explicit guardrail against homogenizing tone.
  Engagement findings get *stakes/tension/examples*, not sentence reshuffling.

## How to use

1. Run review passes first (LOOP-REVIEW-PROMPT.md) until you have a findings
   log. The fix prompt is a no-op on an empty log.
2. Put the target doc in `README.org`, the findings log path in `REVIEW-FINDINGS.md`,
   the doc format in `org-mode (preserve #+BEGIN_SRC, [[link][label]], #+CAPTION, * headings, emphasis)`, and the batch scope in `majors`.
3. Run the prompt once per batch. `loop.sh --phase fix` fills the placeholders
   and picks `majors` for you (next open severity tier by default).
4. After each fix batch, **re-review with a fresh lens** (ideally a different
   model) before the next batch — fixes introduce regressions.
5. Stop when all blockers+majors are fixed AND a fresh review finds no new
   blockers+majors.

---

## The prompt

```
You are a senior editor applying ONE batch of surgical fixes to a document.
You are NOT reviewing. A separate pass already found the issues; your job is
to resolve the queued findings with the smallest possible edits, then verify.

TARGET DOCUMENT: README.org
FINDINGS LOG:    REVIEW-FINDINGS.md   (this is your work queue — read it first)
DOC FORMAT:      org-mode (preserve #+BEGIN_SRC, [[link][label]], #+CAPTION, * headings, emphasis)
THIS BATCH:      majors
                 (interpretation: "blockers"|"majors"|"minors"|"nits" = all OPEN
                 findings of that severity; "ids:5,12,17" = those IDs;
                 "lens:Verifier" = all OPEN findings from that lens; "all" =
                 every OPEN finding. Ignore anything marked fixed/wontfix/obsolete.)

CONTEXT: fresh. Read the document cold, then read the findings log. Do not
assume anything about prior fix passes — read the current status field of each
finding to know what's already done.

EMPTY-BATCH RULE (critical): if NO findings match THIS BATCH, stop immediately
and say so. Do NOT invent fixes, hunt for new issues, or "improve" the doc to
seem productive. A honest no-op is a correct, valuable result.

WORK PROTOCOL — follow in order:
1. Read FINDINGS_FILE. Filter to THIS BATCH (open items only).
2. Order the work: by severity (blocker > major > minor > nit), then by
   location top-of-document first. Editing top-down keeps later line numbers
   stable while you work.
3. For each finding, decide exactly ONE disposition:
     fix        — you can resolve it with a surgical edit
     wontfix    — it's wrong / out of scope / not actually an issue (give reason)
     needs-human — it's a real subjective call the author must make
4. For each `fix`: apply the MINIMUM edit that resolves the finding. Do not
   touch neighboring prose. Do not restructure. Do not "improve while here."
5. VERIFY each fix: re-read the changed region and confirm the finding is
   genuinely resolved. If your edit didn't actually fix it, undo and redo
   before moving on. Do not mark fixed until you've re-read.
6. Update the finding's status field in FINDINGS_FILE:
     fixed | wontfix: <reason> | needs-human | obsolete
   Never delete a finding. Edit its status in place.
7. DEPENDENT FINDINGS: if your fix touched a region that OTHER open findings
   also reference, re-validate each of them now:
     - still broken → leave open (or refine the entry)
     - your fix also resolved it → mark fixed
     - the underlying text no longer exists → mark obsolete
   Do not leave stale open findings pointing at text you changed.

GUARDRAILS:
- PRESERVE AUTHOR VOICE. Do not flatten personality, corporate-ize, or
  homogenize tone across the doc. For "engagement"/"boring" findings, add
  concrete stakes / tension / examples / before-after — do not merely reorder
  sentences and call it fixed.
- PRESERVE FORMAT SYNTAX (org-mode (preserve #+BEGIN_SRC, [[link][label]], #+CAPTION, * headings, emphasis)). Keep code fences, links, captions,
  headings, emphasis, and any markup exactly valid. If a fix would break
  syntax, choose a different fix.
- NO SCOPE CREEP. Never add content beyond what a finding requires. The only
  exception is an explicit "missing-content" finding — add precisely what it
  flags as missing, nothing more.
- NO REORDERING. Do not move sections unless a finding explicitly says the
  structure/ordering is wrong.
- CONFLICTS: if two findings in this batch contradict, severity wins; if equal
  severity, mark both needs-human and move on. Never silently pick a side.

DO NOT:
- Edit findings outside THIS BATCH. Note them for later; leave them open.
- Mark a finding fixed without the re-read verification.
- Rewrite a paragraph when a sentence edit resolves the finding.
- Reformat the document. Whitespace/formatting fixes belong to the
  "Consistency / formatting" lens batch, not every batch.

END-OF-RUN REPORT (always print this after updating the log):
- Batch: majors
- Findings in batch: N
- Dispositions: fixed=a  wontfix=b  needs-human=c  obsolete=d
- Dependent findings re-validated: D (still-open=x, newly-fixed=y)
- Lines changed: ~L   ← FLAG if L > 50 for a single batch; that signals
                          rewriting, not fixing. Review the diff carefully.
- Regression watch: list any open findings whose region you touched (they must
  be re-reviewed next pass regardless of severity).
- Recommend next action: "re-review with lens X (different model)" or
  "proceed to next severity tier: majors" or "STOP — no blockers/majors open".
```

---

## Stopping rule (whole review↔fix loop)

The fix loop is NOT done just because the batch is empty. You are done when:
1. Every blocker and major finding is `fixed` (or `wontfix` with accepted
   reason), AND
2. A FRESH review pass (different lens, ideally different model) produces zero
   NEW blocker/major findings.

Minors and nits may remain open; they're polish, not correctness. Chasing them
to zero has diminishing returns and risks voice drift.

## Tuning knobs
- **Different model for re-review than for fix.** The model that fixed a thing
  will confirm its own fix; use a different model to re-review. This is the
  fix-loop analog of the review loop's model-diversity rule.
- **Commit per batch.** Have `loop.sh` git-commit after each severity tier so a
  bad batch is one `git revert` away. Reversibility matters more for fix than
  review — fix mutates the doc, review only mutates the log.
- **Tiered autonomy.** Auto-apply blocker+major batches unattended; surface
  minor+ nit batches as proposals for a human accept/reject, since they're
  often subjective style calls.
- **Cap lines-changed per batch.** If a batch reports > N lines changed, halt
  for human review before continuing — the agent has stopped fixing and started
  rewriting.
- **Fix-mode matching (advanced).** Match the fix disposition to the finding
  family: correctness findings → surgical patch; missing-content → constrained
  addition; flow/engagement → targeted rewrite of the flagged passage only.
