#!/usr/bin/env bash
#
# loop.sh — iterate `agy --prompt @LOOP-*.md` over a document.
#
# Two phases, each with its own prompt (they are deliberately separate — see
# LOOP-FIX-PROMPT.md "Why separate"):
#
#   --phase review  (default)  rotate ONE review lens per iteration against
#                              LOOP-REVIEW-PROMPT.md, appending findings to
#                              REVIEW-FINDINGS.md.
#   --phase fix                consume the findings log with LOOP-FIX-PROMPT.md,
#                              applying surgical edits to the document, one
#                              severity-tier batch per iteration.
#
# agy does NOT substitute the {DOC}/{LENS}/{BATCH}/... placeholders, so this
# script renders a per-iteration copy and feeds it via @include (or inline).
#
# Usage:
#   ./loop.sh                                    # review: README.org, lenses 1-12
#   ./loop.sh README.org -n 5                    # cap at 5 lenses
#   ./loop.sh --lens "Verifier"                  # run a single review lens
#   ./loop.sh --start 5                          # resume review from lens #5
#   ./loop.sh --type plan                        # review lenses 1-16
#   ./loop.sh --models "sonnet opus" --effort high
#
#   ./loop.sh --phase fix                        # fix next open severity tier
#   ./loop.sh --phase fix --batch majors         # fix a specific tier
#   ./loop.sh --phase fix --batch "ids:5,12"     # fix specific findings
#   ./loop.sh --phase fix --batch "lens:Verifier"
#   ./loop.sh --phase fix --no-commit-batches    # don't git-commit after each batch
#
#   ./loop.sh --dry-run                          # print commands, run nothing
#   ./loop.sh --list                             # show the lens roster, exit
#   ./loop.sh --reset                            # wipe REVIEW-FINDINGS.md + state
#
# Options:
#   DOC              (positional) target document. Default: README.org
#   --phase review|fix   which prompt to iterate. Default: review
#   -n, --max-iterations N   hard cap on iterations run (0 = no cap). Default 0
#   --start N         (review) resume from lens index N (1-based). Default 1
#   --lenses SPEC     (review) e.g. 1-12 (default), 1-16, or 1-4,9,11
#   --lens NAME       (review) run exactly one lens by name, then exit
#   --batch SPEC      (fix) blockers|majors|minors|nits|all|next|ids:..|lens:..
#                     Default: next (highest open severity tier)
#   --models "a b"    space-separated models to rotate (biggest free win)
#   --effort LVL      low|medium|high reasoning effort for every run
#   --type article|plan   article -> lenses 1-12 (default); plan -> 1-16
#   --commit-batches  (fix) git-commit doc+findings after each batch. Default ON
#   --no-commit-batches    disable per-batch commits (reversibility lost!)
#   --reset           delete REVIEW-FINDINGS.md and .loop-review-state
#   --dry-run         print the exact agy commands without executing
#   -w, --wait        pause for <enter> between iterations (q to quit)
#   --list            print the lens roster and exit
#   --no-danger       do NOT pass --dangerously-skip-permissions (see SAFETY)
#   --sandbox         also pass --sandbox (restrict terminal; fs write may still work)
#
# Env overrides:
#   PROMPT_MODE=file|inline   how the rendered prompt is passed. `file` uses
#                            `agy --prompt @build/...md`. `inline` passes the
#                            rendered text directly — use this if @ includes
#                            are NOT expanded in agy print mode. Default: file
#   FINDINGS_FILE=...        default REVIEW-FINDINGS.md
#
# SAFETY: by default this passes --dangerously-skip-permissions so the agent
# can write unattended (the accumulation/fix protocols need it). That flag
# auto-approves ALL tool calls, not just the findings file. Guard rails:
#   * review phase refuses to run unless the git tree is clean OR
#     LOOP_ALLOW_DIRTY=1 (review only mutates the findings log, but the agent
#     has full tool access, so a dirty tree is a footgun).
#   * fix phase MUTATES the document. It requires the DOC itself to be
#     committed (so every batch is revertible) and auto-commits per batch by
#     default. Use --no-commit-batches only if you are committing manually.
#   * after each iteration it prints `git status --short` so you can spot
#     surprises. Run on a branch / worktree.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ----------------------------- config -----------------------------
REVIEW_TEMPLATE="LOOP-REVIEW-PROMPT.md"
FIX_TEMPLATE="LOOP-FIX-PROMPT.md"
DOC="${DOC:-README.org}"
FINDINGS_FILE="${FINDINGS_FILE:-REVIEW-FINDINGS.md}"
STATE_FILE=".loop-review-state"
BUILD_DIR="build"
LOG_DIR="logs"
PHASE="review"
MAX_ITERATIONS=0
START_INDEX=1
LENS_RANGE="1-12"
SINGLE_LENS=""
BATCH="next"
MODELS=()
EFFORT=""
RESET=0
DRY_RUN=0
WAIT=0
LIST=0
DANGER=1
SANDBOX=0
COMMIT_BATCHES=1
PROMPT_MODE="${PROMPT_MODE:-file}"

# ----------------------------- lens roster -----------------------------
# 1-indexed; mirrors LOOP-REVIEW-PROMPT.md "Lens Roster".
# 13-16 are plan-only lenses; the default range 1-12 skips them for articles.
LENSES=(
  "Contradiction hunter"          # 1  correctness
  "Expert reader / fact-checker" # 2  correctness
  "Verifier"                     # 3  correctness
  "Pre-mortem"                   # 4  correctness
  "Beginner reader"              # 5  clarity
  "Cold indexer"                 # 6  clarity
  "Missing-content auditor"      # 7  completeness
  "Assumptions pass"             # 8  completeness
  "Editor / arc"                 # 9  flow
  "Engagement critic"            # 10 flow
  "Audience simulator"           # 11 flow
  "Consistency / formatting"     # 12 consistency
  "Dependency / ordering pass"   # 13 plan-only
  "Reversibility pass"           # 14 plan-only
  "Failure-at-step-N pass"       # 15 plan-only
  "Scope/effort sanity"          # 16 plan-only
)
# After review convergence the prompt mandates two final passes regardless:
FINAL_PASSES=(3 4)   # Verifier, Pre-mortem

# ----------------------------- helpers -----------------------------
usage() {
  cat <<'EOF'
Usage: loop.sh [DOC] [--phase review|fix] [options]

  ./loop.sh                          # review README.org, lenses 1-12
  ./loop.sh --phase fix              # fix next open severity tier
  ./loop.sh --phase fix --batch majors
  ./loop.sh --dry-run | --list | --reset

See the header comment (loop.sh lines 1-90) for the full option reference.
EOF
}

slugify() { echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'; }

expand_range() {        # "1-4,9,11" -> "1 2 3 4 9 11"
  local spec="$1" out=""
  local IFS=','
  local -a parts=($spec)
  local p
  for p in "${parts[@]}"; do
    if [[ "$p" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      local a="${BASH_REMATCH[1]}" b="${BASH_REMATCH[2]}"
      [[ "$a" -gt "$b" ]] && { local t="$a"; a="$b"; b="$t"; }
      local i; for ((i=a; i<=b; i++)); do out="$out $i"; done
    elif [[ "$p" =~ ^[0-9]+$ ]]; then
      out="$out $p"
    else
      echo "bad lens spec fragment: '$p'" >&2; exit 2
    fi
  done
  echo "$out"
}

list_roster() {
  echo "Lens roster (see LOOP-REVIEW-PROMPT.md):"
  local i; for i in "${!LENSES[@]}"; do
    printf '  %2d. %s\n' "$((i+1))" "${LENSES[$i]}"
  done
}

# detect a short format label from the doc extension, for the fix prompt's
# "preserve format syntax" guardrail.
detect_format() {
  case "${DOC##*.}" in
    org) echo "org-mode (preserve #+BEGIN_SRC, [[link][label]], #+CAPTION, * headings, emphasis)" ;;
    md|markdown) echo "markdown (preserve fenced code blocks, [link](url), ATX headings)" ;;
    adoc) echo "asciidoc" ;;
    *) echo "plain text" ;;
  esac
}

# pick the highest-severity tier that still has OPEN findings, for --batch next.
# reads FINDINGS_FILE best-effort: counts lines whose status field looks open.
# pipe-delimited entry: ID | severity | lens | location | issue | fix | status
next_batch() {
  [ -f "$FINDINGS_FILE" ] || { echo "none"; return; }
  local tier
  for tier in blocker major minor nit; do
    # match the severity token on a line whose last field is not a closed state
    if awk -F'|' -v t="$tier" '
      { s=tolower($2); st=tolower($7) }
      s ~ t && st !~ /fixed|wontfix|obsolete|resolved/ { found=1; exit }
      END { exit !found }
    ' "$FINDINGS_FILE"; then
      case "$tier" in
        blocker) echo "blockers" ;;
        major)   echo "majors" ;;
        minor)   echo "minors" ;;
        nit)     echo "nits" ;;
      esac
      return
    fi
  done
  echo "none"
}

# render the REVIEW template with {DOC}/{LENS} filled; echoes the output path.
render_review_prompt() {
  local lens="$1" idx="$2"
  local out="$BUILD_DIR/prompt-lens-$(printf '%02d' "$idx").md"
  mkdir -p "$BUILD_DIR"
  awk -v doc="$DOC" -v lens="$lens" '
    { gsub(/\{DOC\}/, doc); gsub(/\{LENS\}/, lens); print }
  ' "$REVIEW_TEMPLATE" > "$out"
  echo "$out"
}

# render the FIX template with {DOC}/{FINDINGS_FILE}/{FORMAT}/{BATCH} filled.
render_fix_prompt() {
  local batch="$1"
  local out="$BUILD_DIR/prompt-fix-$(slugify "$batch").md"
  mkdir -p "$BUILD_DIR"
  local fmt; fmt="$(detect_format)"
  awk -v doc="$DOC" -v findings="$FINDINGS_FILE" -v fmt="$fmt" -v batch="$batch" '
    { gsub(/\{DOC\}/, doc); gsub(/\{FINDINGS_FILE\}/, findings);
      gsub(/\{FORMAT\}/, fmt); gsub(/\{BATCH\}/, batch); print }
  ' "$FIX_TEMPLATE" > "$out"
  echo "$out"
}

# build the agy command into the global AGY_CMD array. Shared by both phases.
# (sets a global rather than printing NUL-separated because macOS' default
# /bin/bash is 3.2, which has no mapfile/readarray builtin.)
build_agy_cmd() {
  local rendered="$1" iteration="$2"
  AGY_CMD=(agy)
  case "$PROMPT_MODE" in
    file)   AGY_CMD+=(--prompt "@$rendered") ;;
    inline) AGY_CMD+=(--prompt "$(cat "$rendered")") ;;
    *) echo "bad PROMPT_MODE='$PROMPT_MODE' (use file|inline)" >&2; exit 2 ;;
  esac
  [ "$DANGER"  -eq 1 ] && AGY_CMD+=(--dangerously-skip-permissions)
  [ "$SANDBOX" -eq 1 ] && AGY_CMD+=(--sandbox)
  if [ ${#MODELS[@]} -gt 0 ]; then
    AGY_CMD+=(--model "${MODELS[$(( (iteration - 1) % ${#MODELS[@]} ))]}")
  fi
  [ -n "$EFFORT" ] && AGY_CMD+=(--effort "$EFFORT")
}

LAST_LOG=""
# execute an agy command ($1.. = argv), tee to $2 log, retry once with backoff.
run_agy() {
  local log="$1"; shift
  mkdir -p "$LOG_DIR"
  LAST_LOG="$log"
  if [ "$DRY_RUN" -eq 1 ]; then
    ( IFS=' '; printf '    $ %s\n' "$*" )
    return 0
  fi
  local attempt rc
  for attempt in 1 2; do
    if "$@" 2>&1 | tee "$log"; then
      [ "$DANGER" -eq 1 ] && { echo "    git changes:"; git status --short | sed 's/^/      /'; }
      return 0
    fi
    rc=${PIPESTATUS[0]}
    echo "    ! agy exited $rc (attempt $attempt); retrying in ${attempt}0s..." >&2
    sleep "${attempt}0"
  done
  echo "    !! giving up; partial output in $log" >&2
  return 1
}

# git-commit the doc + findings after a fix batch, so each batch is revertible.
commit_batch() {
  local batch="$1"
  [ "$COMMIT_BATCHES" -eq 1 ] || return 0
  [ "$DRY_RUN" -eq 1 ] && { echo "    (would commit) fix batch: $batch"; return 0; }
  git add "$DOC" "$FINDINGS_FILE" 2>/dev/null
  if git diff --cached --quiet; then
    echo "    no changes to commit (batch may have been a no-op)"
    return 0
  fi
  git commit -q -m "fix($batch): apply $batch batch to $DOC via loop.sh" \
    && echo "    committed: $(git rev-parse --short HEAD)"
}

# ----------------------------- phase: review -----------------------------
run_lens() {
  local idx="$1" lens="$2" iteration="$3"
  local rendered; rendered="$(render_review_prompt "$lens" "$idx")"
  local log="$LOG_DIR/$(printf 'lens-%02d' "$idx")-$(slugify "$lens").log"
  printf '\n==> [%d] review lens #%d: %s\n' "$iteration" "$idx" "$lens"
  build_agy_cmd "$rendered" "$iteration"
  run_agy "$log" "${AGY_CMD[@]}"
}

review_phase() {
  if [ -n "$SINGLE_LENS" ]; then
    run_lens 0 "$SINGLE_LENS" 1
    return $?
  fi
  all_idx=$(expand_range "$LENS_RANGE")
  [ -z "$all_idx" ] && { echo "no lenses selected" >&2; exit 1; }
  local selected=() i
  for i in $all_idx; do
    [ "$i" -ge 1 ] && [ "$i" -le "${#LENSES[@]}" ] || { echo "lens #$i out of range (1-${#LENSES[@]})" >&2; exit 2; }
    [ "$i" -ge "$START_INDEX" ] && selected+=("$i")
  done
  [ "${#selected[@]}" -eq 0 ] && { echo "nothing to run (check --start / --lenses)" >&2; exit 1; }

  local iteration=0 converged=0 idx
  for idx in "${selected[@]}"; do
    iteration=$((iteration + 1))
    if [ "$MAX_ITERATIONS" -gt 0 ] && [ "$iteration" -gt "$MAX_ITERATIONS" ]; then
      echo "reached --max-iterations $MAX_ITERATIONS; stopping."; break
    fi
    run_lens "$idx" "${LENSES[$((idx-1))]}" "$iteration" || continue
    [ "$WAIT" -eq 1 ] && { read -rp "    [enter=next lens, q=quit] " ans; [[ "$ans" =~ ^q ]] && break; }
    # heuristic: the end-of-run report emits "CONVERGED" after 2 clean lenses.
    if [ "$DRY_RUN" -eq 0 ] && grep -qi "CONVERGED" "$LAST_LOG" 2>/dev/null; then
      converged=1; echo "==> convergence signaled by lens #$idx."; break
    fi
  done

  if [ "$converged" -eq 1 ]; then
    echo "==> mandatory final passes: ${LENSES[$((FINAL_PASSES[0]-1))]}, ${LENSES[$((FINAL_PASSES[1]-1))]}"
    for fi in "${FINAL_PASSES[@]}"; do
      iteration=$((iteration + 1))
      if [ "$MAX_ITERATIONS" -gt 0 ] && [ "$iteration" -gt "$MAX_ITERATIONS" ]; then break; fi
      run_lens "$fi" "${LENSES[$((fi-1))]}" "$iteration" || true
    done
  fi
}

# ----------------------------- phase: fix -----------------------------
run_fix() {
  local batch="$1" iteration="$2"
  local rendered; rendered="$(render_fix_prompt "$batch")"
  local log="$LOG_DIR/fix-$(slugify "$batch")-$(printf '%02d' "$iteration").log"
  printf '\n==> [%d] fix batch: %s\n' "$iteration" "$batch"
  build_agy_cmd "$rendered" "$iteration"
  run_agy "$log" "${AGY_CMD[@]}" || return 1
  commit_batch "$batch"
}

fix_phase() {
  [ -f "$FINDINGS_FILE" ] || { echo "no $FINDINGS_FILE — run --phase review first." >&2; exit 1; }

  local batch="$BATCH"
  if [ "$batch" = "next" ]; then
    batch="$(next_batch)"
    if [ "$batch" = "none" ]; then
      echo "no open findings in $FINDINGS_FILE — nothing to fix."
      echo "if not already done, re-review (--phase review) to confirm convergence."
      exit 0
    fi
  fi

  # one iteration by default (fix is interactive-by-nature: review the diff,
  # then re-review). Loop with -n to walk down the severity tiers unattended.
  local iteration=1
  run_fix "$batch" "$iteration" || exit 1

  if [ "$MAX_ITERATIONS" -gt 1 ]; then
    while [ "$iteration" -lt "$MAX_ITERATIONS" ]; do
      iteration=$((iteration + 1))
      local nxt; nxt="$(next_batch)"
      [ "$nxt" = "none" ] && { echo "==> no more open findings; stop."; break; }
      [ "$WAIT" -eq 1 ] && { read -rp "    [enter=next batch ($nxt), q=quit] " ans; [[ "$ans" =~ ^q ]] && break; }
      run_fix "$nxt" "$iteration" || break
    done
  fi

  echo
  echo "==> next: re-review with a fresh lens (different model) to catch regressions"
  echo "    e.g. ./loop.sh --phase review --lens 'Pre-mortem' --model <other-model>"
}

# ----------------------------- preflight -----------------------------
preflight() {
  command -v agy >/dev/null || { echo "agy not found in PATH" >&2; exit 127; }
  [ -f "$DOC" ] || { echo "missing target doc: $DOC" >&2; exit 1; }

  if [ "$DANGER" -eq 1 ] && [ "$DRY_RUN" -eq 0 ]; then
    if [ "$PHASE" = "fix" ]; then
      # fix mutates the doc — require the DOC itself to be committed so every
      # batch is revertible. Findings file may be dirty (review wrote it).
      if ! git diff --quiet -- "$DOC" 2>/dev/null \
         || ! git diff --cached --quiet -- "$DOC" 2>/dev/null; then
        echo "SAFETY (fix): the target doc '$DOC' has uncommitted changes." >&2
        echo "Fix mutates it; commit first so each batch is revertible:" >&2
        git status --short -- "$DOC" >&2
        exit 1
      fi
    else
      # review only mutates the findings log, but the agent has full tool
      # access, so refuse on a dirty tree unless explicitly overridden.
      if [ -n "$(git status --porcelain 2>/dev/null)" ] && [ "${LOOP_ALLOW_DIRTY:-0}" != 1 ]; then
        echo "SAFETY (review): --dangerously-skip-permissions is on but the git tree is dirty." >&2
        echo "Commit/stash first, or set LOOP_ALLOW_DIRTY=1:" >&2
        git status --short >&2
        exit 1
      fi
    fi
  fi

  echo "config:"
  echo "  phase          = $PHASE"
  echo "  doc            = $DOC"
  echo "  findings       = $FINDINGS_FILE"
  if [ "$PHASE" = "review" ]; then
    echo "  lenses         = $LENS_RANGE (start $START_INDEX, max $MAX_ITERATIONS)"
    [ -n "$SINGLE_LENS" ] && echo "  single lens    = $SINGLE_LENS"
  else
    echo "  batch          = $BATCH"
    echo "  commit batches = $([ "$COMMIT_BATCHES" = 1 ] && echo yes || echo no)"
  fi
  echo "  prompt mode    = $PROMPT_MODE"
  echo "  models         = ${MODELS[*]:-(agy default)}"
  echo "  effort         = ${EFFORT:-(default)}"
  echo "  skip-perms     = $([ "$DANGER" = 1 ] && echo yes || echo no)"
}

reset_state() {
  rm -f "$FINDINGS_FILE" "$STATE_FILE"
  echo "reset: removed $FINDINGS_FILE and $STATE_FILE"
}

# ----------------------------- arg parsing -----------------------------
DOC_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --phase)             PHASE="$2"; shift 2 ;;
    -n|--max-iterations) MAX_ITERATIONS="$2"; shift 2 ;;
    --start)             START_INDEX="$2"; shift 2 ;;
    --lenses)            LENS_RANGE="$2"; shift 2 ;;
    --lens)              SINGLE_LENS="$2"; shift 2 ;;
    --batch)             BATCH="$2"; shift 2 ;;
    --models)            read -ra MODELS <<< "$2"; shift 2 ;;
    --effort)            EFFORT="$2"; shift 2 ;;
    --type)              [ "$2" = "plan" ] && LENS_RANGE="1-16"; shift 2 ;;
    --commit-batches)    COMMIT_BATCHES=1; shift ;;
    --no-commit-batches) COMMIT_BATCHES=0; shift ;;
    --reset)             RESET=1; shift ;;
    --dry-run)           DRY_RUN=1; shift ;;
    -w|--wait)           WAIT=1; shift ;;
    --list)              LIST=1; shift ;;
    --no-danger)         DANGER=0; shift ;;
    --danger)            DANGER=1; shift ;;
    --sandbox)           SANDBOX=1; shift ;;
    -h|--help)           usage; exit 0 ;;
    -*)                  echo "unknown flag: $1" >&2; exit 2 ;;
    *)                   if [ -z "$DOC_ARG" ]; then DOC_ARG="$1"; else
                          echo "unexpected arg: $1" >&2; exit 2; fi; shift ;;
  esac
done
[ -n "$DOC_ARG" ] && DOC="$DOC_ARG"

case "$PHASE" in
  review|fix) ;;
  *) echo "bad --phase '$PHASE' (use review|fix)" >&2; exit 2 ;;
esac

# ----------------------------- main -----------------------------
[ "$LIST" -eq 1 ] && { list_roster; exit 0; }
[ "$PHASE" = "review" ] && { [ -f "$REVIEW_TEMPLATE" ] || { echo "missing $REVIEW_TEMPLATE" >&2; exit 1; }; }
[ "$PHASE" = "fix" ]    && { [ -f "$FIX_TEMPLATE" ]    || { echo "missing $FIX_TEMPLATE" >&2; exit 1; }; }

preflight
[ "$RESET" -eq 1 ] && reset_state

if [ "$PHASE" = "fix" ]; then
  fix_phase
else
  review_phase
fi

# summary: best-effort extraction of per-run report lines.
echo
echo "=== summary ==="
if compgen -G "$LOG_DIR"/*.log >/dev/null; then
  grep -h -E "New findings this run|Lens run|Convergence status|Lines changed|Dispositions:|Findings in batch" \
    "$LOG_DIR"/*.log 2>/dev/null | sed 's/^/  /' || true
else
  echo "  (no logs in $LOG_DIR)"
fi
echo "findings file: $FINDINGS_FILE"
echo "logs:          $LOG_DIR/*.log"
