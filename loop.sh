#!/usr/bin/env bash
#
# loop.sh — iterate `agy --prompt @LOOP-REVIEW-PROMPT.md`, rotating ONE review
# lens per iteration. The prompt file (LOOP-REVIEW-PROMPT.md) is a template
# with {DOC} and {LENS} placeholders; agy does NOT substitute them, so this
# script renders a per-lens copy and feeds it via @include (or inline).
#
# Why rotation: re-running the exact same prompt N times plateaus — the agent
# re-finds the same few issues. Rotating the lens each run is the whole point
# of LOOP-REVIEW-PROMPT.md. So "iteration" here = the LENS, not a bare counter.
#
# Usage:
#   ./loop.sh [DOC] [options]
#
#   ./loop.sh                                    # README.org, lenses 1-12, hands-off
#   ./loop.sh README.org -n 5                    # cap at 5 lenses
#   ./loop.sh --lens "Verifier"                  # run a single lens once
#   ./loop.sh --start 5                          # resume from lens #5
#   ./loop.sh --type plan                        # use plan lenses 1-16
#   ./loop.sh --models "sonnet opus" --effort high   # rotate models for diversity
#   ./loop.sh --dry-run                          # print commands, run nothing
#   ./loop.sh --list                             # show the lens roster, exit
#   ./loop.sh --reset                            # wipe REVIEW-FINDINGS.md + state
#
# Options:
#   DOC              (positional) target document. Default: README.org
#   -n, --max-iterations N   hard cap on lenses run (0 = whole roster). Default 0
#   --start N         resume from lens index N (1-based). Default 1
#   --lenses SPEC     which lenses, e.g. 1-12 (default), 1-16, or 1-4,9,11
#   --lens NAME       run exactly one lens by name, then exit
#   --models "a b"    space-separated models to rotate (biggest free win — see prompt)
#   --effort LVL      low|medium|high reasoning effort for every run
#   --type article|plan   article -> lenses 1-12 (default); plan -> 1-16
#   --reset           delete REVIEW-FINDINGS.md and .loop-review-state
#   --dry-run         print the exact agy commands without executing
#   -w, --wait        pause for <enter> between lenses (q to quit)
#   --list            print the lens roster and exit
#   --no-danger       do NOT pass --dangerously-skip-permissions (see SAFETY)
#   --sandbox         also pass --sandbox (restrict terminal; fs write may still work)
#
# Env overrides:
#   PROMPT_MODE=file|inline   how the rendered prompt is passed. `file` uses
#                            `agy --prompt @build/prompt-lens-NN.md` (matches
#                            the idiom you already use). `inline` passes the
#                            rendered text directly — use this if @ includes
#                            are NOT expanded in agy print mode. Default: file
#   FINDINGS_FILE=...        default REVIEW-FINDINGS.md
#
# SAFETY: by default this passes --dangerously-skip-permissions so the agent
# can write REVIEW-FINDINGS.md unattended (the accumulation protocol needs it).
# That auto-approves ALL tool calls, not just the findings file. Guard rails:
#   * it refuses to run unless the git tree is clean OR you set LOOP_ALLOW_DIRTY=1
#   * after each lens it prints `git status --short` so you can spot surprises
#   * run on a branch / worktree, or set --no-danger (but then writes may stall)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ----------------------------- config -----------------------------
TEMPLATE="LOOP-REVIEW-PROMPT.md"
DOC="${DOC:-README.org}"
FINDINGS_FILE="${FINDINGS_FILE:-REVIEW-FINDINGS.md}"
STATE_FILE=".loop-review-state"
BUILD_DIR="build"
LOG_DIR="logs"
MAX_ITERATIONS=0
START_INDEX=1
LENS_RANGE="1-12"
SINGLE_LENS=""
MODELS=()
EFFORT=""
RESET=0
DRY_RUN=0
WAIT=0
LIST=0
DANGER=1
SANDBOX=0
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
# After convergence the prompt mandates two final passes regardless:
FINAL_PASSES=(3 4)   # Verifier, Pre-mortem

# ----------------------------- helpers -----------------------------
usage() { sed -n '3,52p' "$0"; }

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

# render the prompt template with {DOC}/{LENS} filled; echoes the output path.
# gsub replacement-special chars (& \) are NOT handled; DOC/lens names avoid them.
render_prompt() {
  local lens="$1" idx="$2"
  local out="$BUILD_DIR/prompt-lens-$(printf '%02d' "$idx").md"
  mkdir -p "$BUILD_DIR"
  awk -v doc="$DOC" -v lens="$lens" '
    { gsub(/\{DOC\}/, doc); gsub(/\{LENS\}/, lens); print }
  ' "$TEMPLATE" > "$out"
  echo "$out"
}

LAST_LOG=""
# run one lens. prints the agy command, executes with retry, tees to a log.
run_lens() {
  local idx="$1" lens="$2" iteration="$3"
  local rendered; rendered="$(render_prompt "$lens" "$idx")"
  local log="$LOG_DIR/$(printf 'lens-%02d' "$idx")-$(slugify "$lens").log"
  mkdir -p "$LOG_DIR"
  LAST_LOG="$log"

  local model=""
  if [ ${#MODELS[@]} -gt 0 ]; then
    model="${MODELS[$(( (iteration - 1) % ${#MODELS[@]} ))]}"
  fi

  local -a cmd=(agy)
  case "$PROMPT_MODE" in
    file)   cmd+=(--prompt "@$rendered") ;;
    inline) cmd+=(--prompt "$(cat "$rendered")") ;;
    *) echo "bad PROMPT_MODE='$PROMPT_MODE' (use file|inline)" >&2; exit 2 ;;
  esac
  [ "$DANGER"   -eq 1 ] && cmd+=(--dangerously-skip-permissions)
  [ "$SANDBOX"  -eq 1 ] && cmd+=(--sandbox)
  [ -n "$model" ]       && cmd+=(--model "$model")
  [ -n "$EFFORT" ]      && cmd+=(--effort "$EFFORT")

  printf '\n==> [%d] lens #%d: %s\n' "$iteration" "$idx" "$lens"
  if [ "$DRY_RUN" -eq 1 ]; then
    ( IFS=' '; printf '    $ %s\n' "${cmd[*]}" )
    return 0
  fi

  local attempt rc
  for attempt in 1 2; do
    if "${cmd[@]}" 2>&1 | tee "$log"; then
      [ "$DANGER" -eq 1 ] && { echo "    git changes:"; git status --short | sed 's/^/      /'; }
      return 0
    fi
    rc=${PIPESTATUS[0]}
    echo "    ! agy exited $rc (attempt $attempt); retrying in ${attempt}0s..." >&2
    sleep "${attempt}0"
  done
  echo "    !! giving up on lens #$idx; partial output in $log" >&2
  return 1
}

preflight() {
  command -v agy >/dev/null || { echo "agy not found in PATH" >&2; exit 127; }
  [ -f "$TEMPLATE" ] || { echo "missing $TEMPLATE" >&2; exit 1; }
  [ -f "$DOC" ]      || { echo "missing target doc: $DOC" >&2; exit 1; }

  if [ "$DANGER" -eq 1 ] && [ "$DRY_RUN" -eq 0 ]; then
    if [ -n "$(git status --porcelain 2>/dev/null)" ] && [ "${LOOP_ALLOW_DIRTY:-0}" != 1 ]; then
      echo "SAFETY: --dangerously-skip-permissions is on but the git tree is dirty."
      echo "An agent with full tool access could modify files. Commit/stash first,"
      echo "or set LOOP_ALLOW_DIRTY=1 to proceed anyway:" >&2
      git status --short >&2
      exit 1
    fi
  fi

  echo "config:"
  echo "  doc            = $DOC"
  echo "  findings       = $FINDINGS_FILE"
  echo "  lenses         = $LENS_RANGE (start $START_INDEX, max $MAX_ITERATIONS)"
  echo "  prompt mode    = $PROMPT_MODE"
  echo "  models         = ${MODELS[*]:-(agy default)}"
  echo "  effort         = ${EFFORT:-(default)}"
  echo "  skip-perms     = $([ "$DANGER" = 1 ] && echo yes || echo no)"
  [ -n "$SINGLE_LENS" ] && echo "  single lens    = $SINGLE_LENS"
}

reset_state() {
  rm -f "$FINDINGS_FILE" "$STATE_FILE"
  echo "reset: removed $FINDINGS_FILE and $STATE_FILE"
}

# ----------------------------- arg parsing -----------------------------
DOC_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    -n|--max-iterations) MAX_ITERATIONS="$2"; shift 2 ;;
    --start)             START_INDEX="$2"; shift 2 ;;
    --lenses)            LENS_RANGE="$2"; shift 2 ;;
    --lens)              SINGLE_LENS="$2"; shift 2 ;;
    --models)            read -ra MODELS <<< "$2"; shift 2 ;;
    --effort)            EFFORT="$2"; shift 2 ;;
    --type)              [ "$2" = "plan" ] && LENS_RANGE="1-16"; shift 2 ;;
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

# ----------------------------- main -----------------------------
[ "$LIST" -eq 1 ] && { list_roster; exit 0; }
preflight
[ "$RESET" -eq 1 ] && reset_state

# single-lens mode: run once and stop
if [ -n "$SINGLE_LENS" ]; then
  run_lens 0 "$SINGLE_LENS" 1
  exit $?
fi

# build the ordered list of lens indices from the range, honoring --start
all_idx=$(expand_range "$LENS_RANGE")
[ -z "$all_idx" ] && { echo "no lenses selected" >&2; exit 1; }
selected=()
for i in $all_idx; do
  [ "$i" -ge 1 ] && [ "$i" -le "${#LENSES[@]}" ] || { echo "lens #$i out of range (1-${#LENSES[@]})" >&2; exit 2; }
  [ "$i" -ge "$START_INDEX" ] && selected+=("$i")
done
[ "${#selected[@]}" -eq 0 ] && { echo "nothing to run (check --start / --lenses)" >&2; exit 1; }

iteration=0
converged=0
for idx in "${selected[@]}"; do
  iteration=$((iteration + 1))
  if [ "$MAX_ITERATIONS" -gt 0 ] && [ "$iteration" -gt "$MAX_ITERATIONS" ]; then
    echo "reached --max-iterations $MAX_ITERATIONS; stopping."
    break
  fi
  run_lens "$idx" "${LENSES[$((idx-1))]}" "$iteration" || continue

  [ "$WAIT" -eq 1 ] && { read -rp "    [enter=next lens, q=quit] " ans; [[ "$ans" =~ ^q ]] && break; }

  # heuristic convergence: the end-of-run report emits "CONVERGED" when 2
  # consecutive lenses found 0 new blocker/major issues. Fragile by design —
  # treat as a hint, not ground truth.
  if [ "$DRY_RUN" -eq 0 ] && grep -qi "CONVERGED" "$LAST_LOG" 2>/dev/null; then
    converged=1
    echo "==> convergence signaled by lens #$idx."
    break
  fi
done

# the prompt mandates two final passes after convergence, regardless of order.
if [ "$converged" -eq 1 ]; then
  echo "==> running mandatory final passes: ${LENSES[$((FINAL_PASSES[0]-1))]}, ${LENSES[$((FINAL_PASSES[1]-1))]}"
  for fi in "${FINAL_PASSES[@]}"; do
    iteration=$((iteration + 1))
    if [ "$MAX_ITERATIONS" -gt 0 ] && [ "$iteration" -gt "$MAX_ITERATIONS" ]; then break; fi
    run_lens "$fi" "${LENSES[$((fi-1))]}" "$iteration" || true
  done
fi

# summary: best-effort extraction of per-lens "New findings this run" lines.
echo
echo "=== summary ==="
if compgen -G "$LOG_DIR/lens-*.log" >/dev/null; then
  grep -h -E "New findings this run|Lens run|Convergence status" "$LOG_DIR"/lens-*.log 2>/dev/null | sed 's/^/  /' || true
else
  echo "  (no logs in $LOG_DIR)"
fi
echo "findings file: $FINDINGS_FILE"
echo "logs:          $LOG_DIR/lens-*.log"
