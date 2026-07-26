#!/usr/bin/env bash
# ============================================================
# review-loop.sh - Multi-persona article review orchestrator
# ============================================================
# Runs a sequence of AI reviewer personas against a single file.
# Each persona reads the file, finds issues from its perspective,
# edits the file to fix them, and the script commits.
#
# TWO-PHASE MODE: Set REVIEW_MODEL and FIX_MODEL to split each
# reviewer into review (find issues, no edits) + fix (apply edits).
# Use a cheap/fast model for review and a stronger model for fixes.
#
# REPORT MODE: Use --report-html to generate an HTML report of all
# findings instead of applying edits. Each reviewer runs independently
# against the original file and their findings are aggregated.
#
# Usage (run from project root):
#   ./scripts/review-loop.sh <file> [--max-iterations N] [--reviewers-dir <dir>]
#   ./scripts/review-loop.sh <file> --dry-run
#   ./scripts/review-loop.sh <file> --from <persona>
#   ./scripts/review-loop.sh <file> --only <persona>
#   ./scripts/review-loop.sh <file> --report-html [path]
#
# Environment:
#   PI_CMD         Pi CLI command (default: "pi")
#   REVIEW_MODEL   Model for review phase (e.g. "deepseek-v4-flash")
#   FIX_MODEL      Model for fix phase (e.g. "deepseek-v4-pro")
# ============================================================

set -euo pipefail

# ---- Colors -------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ---- Config (override with env vars) -----------------------
PI_CMD="${PI_CMD:-pi}"
MAX_ITERATIONS="${MAX_ITERATIONS:-10}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REVIEWERS_DIR="${REVIEWERS_DIR:-${SCRIPT_DIR}/reviewers}"
REVIEW_MODEL="${REVIEW_MODEL:-}"
FIX_MODEL="${FIX_MODEL:-}"
DRY_RUN=false
START_FROM=""
ONLY=""
TONE_PROFILE=""  # populated by Voice Guardian pre-flight
REPORT_HTML=""   # path for HTML report output (enables report mode)
COMMIT_REPORT=false  # git add + commit the HTML report after generation

# ---- Help --------------------------------------------------
usage() {
  cat <<EOF
${BOLD}review-loop.sh${NC} - Multi-persona article review orchestrator

${BOLD}Usage:${NC}
  $0 <file> [options]

${BOLD}Options:${NC}
  --max-iterations N    Stop after N review passes (default: 10)
  --reviewers-dir DIR   Path to reviewer prompt files (default: scripts/reviewers/)
  --review-model MODEL  Model for review phase (e.g. deepseek-v4-flash)
  --fix-model MODEL     Model for fix phase (e.g. deepseek-v4-pro)
  --dry-run             Print what would run without executing
  --from PERSONA        Start from a specific reviewer (skip earlier ones)
  --only PERSONA        Run only one specific reviewer
  --report-html [PATH]  Generate HTML report instead of editing
  --commit-report       Commit the HTML report after generation
  --help                Show this message

${BOLD}Environment:${NC}
  PI_CMD                Pi CLI command (default: "pi")
  REVIEW_MODEL          Model for review phase
  FIX_MODEL             Model for fix phase (defaults to REVIEW_MODEL)

${BOLD}Two-phase example:${NC}
  REVIEW_MODEL=deepseek-v4-flash FIX_MODEL=deepseek-v4-pro $0 README.org

${BOLD}Report-mode examples:${NC}
  $0 README.org --report-html
  $0 README.org --report-html /tmp/report.html --only beginner
  $0 README.org --report-html --commit-report

${BOLD}Single-phase examples:${NC}
  $0 README.org
  $0 docs/spec.md --only beginner
EOF
  exit 0
}

# ---- Parse args --------------------------------------------
FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-iterations)  MAX_ITERATIONS="$2"; shift 2 ;;
    --reviewers-dir)   REVIEWERS_DIR="$2";   shift 2 ;;
    --review-model)    REVIEW_MODEL="$2";    shift 2 ;;
    --fix-model)       FIX_MODEL="$2";       shift 2 ;;
    --report-html)
      if [[ -n "${2:-}" && "$2" != -* ]]; then
        REPORT_HTML="$2"; shift 2
      else
        REPORT_HTML="__default__"; shift
      fi ;;
    --commit-report)   COMMIT_REPORT=true;    shift ;;
    --dry-run)         DRY_RUN=true;         shift ;;
    --from)            START_FROM="$2";      shift 2 ;;
    --only)            ONLY="$2";            shift 2 ;;
    --help|-h)         usage ;;
    -*) echo -e "${RED}Unknown flag: $1${NC}"; usage ;;
    *)  FILE="$1"; shift ;;
  esac
done

# ---- Determine mode ----------------------------------------
TWO_PHASE=false
if [[ -n "$REVIEW_MODEL" ]]; then
  TWO_PHASE=true
  FIX_MODEL="${FIX_MODEL:-$REVIEW_MODEL}"
fi

REPORT_MODE=false
if [[ -n "$REPORT_HTML" ]]; then
  REPORT_MODE=true
  if $TWO_PHASE && [[ -n "$FIX_MODEL" ]]; then
    echo -e "${YELLOW}Note: FIX_MODEL is ignored in report mode (no edits are applied).${NC}"
  fi
fi

# ---- Validation --------------------------------------------
if [[ -z "$FILE" ]]; then
  echo -e "${RED}Error: No file specified.${NC}"
  usage
fi
if [[ ! -f "$FILE" ]]; then
  echo -e "${RED}Error: File not found: $FILE${NC}"
  exit 1
fi
if [[ ! -d "$REVIEWERS_DIR" ]]; then
  echo -e "${RED}Error: Reviewers directory not found: $REVIEWERS_DIR${NC}"
  exit 1
fi

# ---- Default report path -----------------------------------
if $REPORT_MODE && [[ "$REPORT_HTML" == "__default__" ]]; then
  BASENAME="$(basename "$FILE" | sed 's/\.[^.]*$//')"
  TIMESTAMP=$(date -u +"%Y%m%dT%H%M%S")
  REPORT_HTML="review-report-${BASENAME}-${TIMESTAMP}.html"
fi

# ---- Git check ---------------------------------------------
if $REPORT_MODE; then
  if $COMMIT_REPORT; then
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
      echo -e "${RED}Error: --commit-report requires a git repository.${NC}"
      exit 1
    fi
  else
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
      echo -e "${YELLOW}Warning: Not in a git repository — report won't be committed.${NC}"
    fi
  fi
  echo ""  # no stash prompt in report mode (source file is not edited)
else
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}Error: Not in a git repository.${NC}"
    echo "  The review loop commits after each pass - a git repo is required."
    exit 1
  fi
  if ! git diff --quiet -- "$FILE" 2>/dev/null; then
    echo -e "${YELLOW}Warning: $FILE has uncommitted changes.${NC}"
    echo -e "  ${BOLD}Stash them before running? [y/N]${NC}"
    read -r answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      git stash push -- "$FILE"
      echo -e "  ${GREEN}Stashed.${NC}"
    else
      echo -e "  ${YELLOW}Continuing with uncommitted changes...${NC}"
    fi
  fi
fi

# ---- Collect reviewer files ---------------------------------
ALL_REVIEWERS=()
while IFS= read -r line; do
  ALL_REVIEWERS+=("$line")
done < <(ls -1 "$REVIEWERS_DIR"/*.md 2>/dev/null | sort)

if [[ ${#ALL_REVIEWERS[@]} -eq 0 ]]; then
  echo -e "${RED}Error: No .md reviewer files found in $REVIEWERS_DIR${NC}"
  exit 1
fi

# Filter based on --from / --only (also exclude 00- voice guardian)
REVIEWERS=()
SKIPPING=true
for rf in "${ALL_REVIEWERS[@]}"; do
  base=$(basename "$rf" .md)
  short=$(echo "$base" | sed 's/^[0-9]*-//')

  # 00-voice-guardian runs as pre-flight, not as a regular reviewer
  if [[ "$short" == "voice-guardian" || "$base" == "00-voice-guardian" ]]; then
    continue
  fi

  if [[ -n "$ONLY" ]]; then
    if [[ "$short" == "$ONLY" || "$base" == "$ONLY" ]]; then
      REVIEWERS+=("$rf"); break
    fi
    continue
  fi
  if [[ -n "$START_FROM" ]] && $SKIPPING; then
    if [[ "$short" == "$START_FROM" || "$base" == "$START_FROM" ]]; then
      SKIPPING=false
    else
      continue
    fi
  fi
  REVIEWERS+=("$rf")
done

if [[ ${#REVIEWERS[@]} -eq 0 ]]; then
  echo -e "${RED}Error: No matching reviewers found.${NC}"
  echo "  Available:"
  for rf in "${ALL_REVIEWERS[@]}"; do
    echo "    - $(basename "$rf" .md | sed 's/^[0-9]*-//')"
  done
  exit 1
fi

# ---- Dry-run mode ------------------------------------------
if $DRY_RUN; then
  echo -e "${CYAN}${BOLD}=== Dry Run: $(basename "$FILE") ===${NC}"
  echo ""
  echo "  Reviewers to run (${#REVIEWERS[@]}):"
  for rf in "${REVIEWERS[@]}"; do
    base=$(basename "$rf" .md)
    short=$(echo "$base" | sed 's/^[0-9]*-//')
    echo -e "    ${GREEN}>${NC} $short  ($base)"
  done
  echo ""
  echo "  Max iterations: $MAX_ITERATIONS"
  echo "  PI_CMD: $PI_CMD"
  if $REPORT_MODE; then
    echo "  Mode: report (output: ${REPORT_HTML})"
    if [[ -n "$REVIEW_MODEL" ]]; then
      echo "  Review model: ${REVIEW_MODEL}"
    fi
    if $COMMIT_REPORT; then
      echo "  Commit report: yes"
    fi
  elif $TWO_PHASE; then
    echo "  Mode: two-phase (review: ${REVIEW_MODEL} -> fix: ${FIX_MODEL})"
  else
    echo "  Mode: single-phase"
  fi
  if [[ -f "${REVIEWERS_DIR}/00-voice-guardian.md" ]]; then
    echo "  Voice Guardian: will run as pre-flight"
  fi
  exit 0
fi

# ---- Pre-flight: Voice Guardian (if present) --------------
VOICE_GUARDIAN="${REVIEWERS_DIR}/00-voice-guardian.md"
if [[ -f "$VOICE_GUARDIAN" ]]; then
  echo -e "${CYAN}${BOLD}=== Pre-flight: Voice Guardian ===${NC}"
  echo "  Extracting tone profile from $(basename "$FILE")..."

  VG_CONTENT=$(cat "$VOICE_GUARDIAN")
  VG_PROMPT=$(cat <<PROMPT
${VG_CONTENT}

---

**File to analyze:** @${FILE}

**Instructions:**
1. Read the entire file.
2. Analyze the author voice and tone across ALL dimensions.
3. Output ONLY the structured voice profile (see format in your instructions).
4. Do NOT edit the file. Do NOT suggest changes. Just profile the voice.
PROMPT
)

  VG_START=$(date +%s)
  VG_OUTPUT=$(mktemp /tmp/voice-guardian.XXXXXX)
  VG_MODEL="${FIX_MODEL:-${REVIEW_MODEL:-}}"

  if echo "$VG_PROMPT" | $PI_CMD ${VG_MODEL:+--model "$VG_MODEL"} -p > "$VG_OUTPUT" 2>&1; then
    TONE_PROFILE=$(cat "$VG_OUTPUT")
    VG_END=$(date +%s)
    VG_DUR=$((VG_END - VG_START))
    echo -e "  ${GREEN}Voice profile captured${NC} (${VG_DUR}s)"
  else
    VG_END=$(date +%s)
    VG_DUR=$((VG_END - VG_START))
    echo -e "  ${YELLOW}Voice Guardian failed - continuing without tone profile${NC} (${VG_DUR}s)"
    TONE_PROFILE=""
  fi
  rm -f "$VG_OUTPUT"
  echo ""
fi

# ---- Helper: run pi ----------------------------------------
# Usage: run_pi "prompt" [--model MODEL]
# Echoes the prompt to pi -p, returns pi exit code.
run_pi() {
  local prompt="$1"
  local model_arg=""
  if [[ "${2:-}" == "--model" && -n "${3:-}" ]]; then
    model_arg="--model $3"
  fi
  echo "$prompt" | $PI_CMD $model_arg -p 2>&1
}

# ---- Helper: build single-phase prompt ---------------------
build_single_prompt() {
  local reviewer_prompt="$1"
  local tone_profile="${2:-}"

  local tone_section=""
  if [[ -n "$tone_profile" ]]; then
    tone_section=$(cat <<TONE

## Voice & Tone Profile (AUTHORITATIVE — preserve this voice in all edits)

${tone_profile}

## Tone Rule
Every edit must sound like the same person wrote it. Preserve quirks, code-switching, and rhythm.
TONE
)
  fi

  cat <<PROMPT
${reviewer_prompt}

---

**File to review:** @${FILE}
${tone_section}

**Instructions:**
1. Read the entire file first.
2. Apply your reviewer perspective exhaustively. Find EVERY issue.
3. Edit the file directly to fix each issue you find. Use the edit tool.
4. If sections are fine as-is, do not touch them.
5. Every edit must respect the voice and tone profile above.

**Important:** Be thorough. This is your only job. Find everything.
Do not commit - the script handles that.
PROMPT
}

# ---- Helper: build review-phase prompt ---------------------
# Usage: build_review_prompt <reviewer_prompt> [tone_profile]
build_review_prompt() {
  local reviewer_prompt="$1"
  local tone_profile="${2:-}"

  local tone_section=""
  if [[ -n "$tone_profile" ]]; then
    tone_section="
## Voice & Tone Profile (REFERENCE — flag issues that would break this voice)

${tone_profile}

## Tone Awareness
When you find an issue, note in your report if the suggested fix could clash with the author\'s voice."
  fi

  cat <<PROMPT
${reviewer_prompt}

---

**File to review:** @${FILE}
${tone_section}

**Instructions:**
1. Read the entire file.
2. Find EVERY issue from your reviewer perspective. Be exhaustive.
3. For each issue, output a structured entry with:
   - **Location**: section heading or line number
   - **Problem**: what is wrong and why
   - **Suggested fix**: the exact change to make (old text -> new text)
4. **DO NOT edit the file.** Only produce a review report.
5. Number your findings so the fix phase can track them.
PROMPT
}

# ---- Helper: build fix-phase prompt ------------------------
build_fix_prompt() {
  local review_content="$1"
  local tone_profile="${2:-}"

  local tone_section=""
  if [[ -n "$tone_profile" ]]; then
    tone_section="
## Voice & Tone Profile (AUTHORITATIVE)

This is the author\'s authentic voice. Every edit you make MUST preserve it.

${tone_profile}

## Tone-Preservation Rules

- Before applying any fix, ask: \"Does the corrected text still sound like the same person?\"
- If a fix makes the text more \"correct\" but less authentic, adapt it until both hold.
- Preserve the author\'s quirks: code-switching, rhythm, rhetorical devices, punctuation habits.
- Do NOT homogenize the voice toward generic formal writing.
- The mix of languages, registers, and styles IS intentional — do not \"fix\" it.
- If the review report suggests a change that would damage the voice, skip it and explain why."
  fi

  cat <<PROMPT
You are fixing issues in @${FILE} based on a review report.
${tone_section}
## Review Report
${review_content}

## Instructions
1. Read the file.
2. Internalize the voice and tone. Every edit must respect it.
3. For each issue in the review report above, apply the suggested fix.
4. If a fix conflicts with the voice or would cause problems, skip it and note why.
5. Edit the file directly using the edit tool. Be surgical — only change what needs changing.
6. Do NOT re-review or look for new issues. Only fix what is reported.
PROMPT
}

# ---- Helper: commit if changed -----------------------------
commit_if_changed() {
  local pre_hash="$1"
  local display_name="$2"
  local post_hash
  post_hash=$(git hash-object "$FILE" 2>/dev/null || true)
  if [[ "$pre_hash" != "$post_hash" ]]; then
    local diff_stats
    diff_stats=$(git diff --stat "$FILE" | tail -1)
    git add "$FILE"
    git commit -m "review(${display_name}): ${diff_stats}" -- "$FILE"
    return 0  # changes committed
  fi
  return 1  # no changes
}

# ---- Helper: generate HTML report --------------------------
generate_html_report() {
  local output_path="$1"
  local source_file="$2"
  local tone_profile="${3:-}"
  local now_iso
  now_iso=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local now_human
  now_human=$(date +"%Y-%m-%d %H:%M:%S %Z")

  # Compute issue counts per reviewer
  local summary_rows=""
  local reviewer_sections=""
  local total_reviewers=${#REVIEWER_NAMES[@]}

  local idx
  for (( idx=0; idx<total_reviewers; idx++ )); do
    local rname="${REVIEWER_NAMES[$idx]}"
    local raw="${REVIEWER_OUTPUTS[$idx]}"
    local escaped
    escaped=$(printf '%s' "$raw" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')

    # Count issues - look for numbered items or issue markers
    local count
    count=$(printf '%s' "$raw" | grep -cE '^[0-9]+\.?[[:space:]]+\*\*' 2>/dev/null | tr -d '\n' || echo "0")
    if [[ "$count" == "0" ]]; then
      count=$(printf '%s' "$raw" | grep -cE '^#{1,3}[[:space:]]+[0-9]+\.' 2>/dev/null | tr -d '\n' || echo "0")
    fi
    if [[ "$count" == "0" ]]; then
      count=$(printf '%s' "$raw" | grep -cE '\*\*Location\*\*' 2>/dev/null | tr -d '\n' || echo "0")
    fi

    local status_class="issues"
    if [[ "$count" == "0" ]]; then
      status_class="clean"
    fi

    # Anchor-friendly ID
    local anchor
    anchor=$(echo "$rname" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')

    summary_rows+=$(cat <<SUMROW
        <tr class="${status_class}">
          <td><a href="#${anchor}">${rname}</a></td>
          <td>${count}</td>
        </tr>
SUMROW
)

    # Build reviewer section HTML
    local section_html
    if [[ "$count" == "0" ]]; then
      section_html=$(cat <<SECTION
    <section id="${anchor}" class="reviewer-section clean">
      <h2>${rname} <span class="badge clean">No issues found</span></h2>
      <p class="no-issues">This reviewer found no issues to report. The section is clean!</p>
    </section>
SECTION
)
    else
      # Convert raw report text to HTML with basic formatting
      local html_body
      html_body=$(printf '%s' "$raw" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
      # Preserve newlines as <br> for readability
      html_body=$(printf '%s' "$html_body" | awk '{print $0"<br>"}')
      # Wrap findings in styled blocks - look for numbered items
      html_body=$(printf '%s' "$html_body" | sed 's|\(<br>\|^\)\([0-9]\+\)\.\?[[:space:]]\+\*\*|\1<div class="finding"><input type="checkbox" id="'"$anchor"'-\2"><label for="'"$anchor"'-\2"><strong>\2.</strong> |g')

      section_html=$(cat <<SECTION
    <section id="${anchor}" class="reviewer-section">
      <h2>${rname} <span class="badge">${count} issue$( [[ "$count" != "1" ]] && echo "s")</span></h2>
      <div class="findings">
${html_body}
      </div>
    </section>
SECTION
)
    fi

    reviewer_sections+="${section_html}"
  done

  # Voice Guardian section
  local vg_section=""
  if [[ -n "$tone_profile" ]]; then
    local vg_html
    vg_html=$(printf '%s' "$tone_profile" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
    vg_html=$(printf '%s' "$vg_html" | awk '{print $0"<br>"}')
    vg_section=$(cat <<VG
    <section class="voice-guardian">
      <details>
        <summary><h2>Voice &amp; Tone Profile</h2></summary>
        <div class="voice-profile">
${vg_html}
        </div>
      </details>
    </section>
VG
)
  fi

  # Original file appendix
  local original_html
  original_html=$(cat "$source_file" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
  original_html=$(printf '%s' "$original_html" | awk '{print $0"<br>"}')

  cat > "$output_path" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Review Report: $(basename "$source_file") — ${now_human}</title>
<style>
  :root {
    --bg: #0d1117;
    --bg-secondary: #161b22;
    --border: #30363d;
    --text: #c9d1d9;
    --text-muted: #8b949e;
    --accent: #58a6ff;
    --success: #3fb950;
    --warning: #d2991d;
    --danger: #f85149;
    --badge-bg: #1f2937;
    --finding-bg: #161b22;
    --finding-border: #21262d;
    --code-bg: #1c2128;
  }

  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
    background: var(--bg);
    color: var(--text);
    line-height: 1.6;
    max-width: 960px;
    margin: 0 auto;
    padding: 2rem 1.5rem;
  }

  header {
    border-bottom: 1px solid var(--border);
    padding-bottom: 1.5rem;
    margin-bottom: 2rem;
  }

  header h1 {
    font-size: 1.75rem;
    color: var(--accent);
    margin-bottom: 0.5rem;
  }

  .meta {
    display: grid;
    grid-template-columns: max-content 1fr;
    gap: 0.25rem 1rem;
    font-size: 0.875rem;
    color: var(--text-muted);
  }

  .meta dt { font-weight: 600; }

  .summary {
    background: var(--bg-secondary);
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 1.25rem;
    margin-bottom: 2rem;
  }

  .summary h2 {
    font-size: 1.1rem;
    margin-bottom: 0.75rem;
  }

  .summary table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.9rem;
  }

  .summary th {
    text-align: left;
    color: var(--text-muted);
    font-weight: 500;
    padding: 0.4rem 0.5rem;
    border-bottom: 1px solid var(--border);
  }

  .summary td {
    padding: 0.4rem 0.5rem;
    border-bottom: 1px solid var(--border);
  }

  .summary td:last-child {
    text-align: center;
    font-weight: 700;
  }

  .summary tr:last-child td { border-bottom: none; }

  .summary a { color: var(--accent); text-decoration: none; }
  .summary a:hover { text-decoration: underline; }

  .reviewer-section {
    margin-bottom: 2rem;
    padding: 1.25rem;
    background: var(--bg-secondary);
    border: 1px solid var(--border);
    border-radius: 8px;
  }

  .reviewer-section.clean {
    border-left: 3px solid var(--success);
  }

  .reviewer-section h2 {
    font-size: 1.15rem;
    margin-bottom: 0.75rem;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .badge {
    font-size: 0.75rem;
    font-weight: 600;
    padding: 0.15rem 0.5rem;
    border-radius: 999px;
    background: var(--badge-bg);
    color: var(--text-muted);
  }

  .badge.clean {
    background: rgba(63, 185, 80, 0.15);
    color: var(--success);
  }

  .finding {
    background: var(--finding-bg);
    border: 1px solid var(--finding-border);
    border-radius: 6px;
    padding: 0.75rem 1rem;
    margin-bottom: 0.75rem;
    display: flex;
    gap: 0.5rem;
    align-items: flex-start;
  }

  .finding input[type="checkbox"] {
    margin-top: 0.25rem;
    flex-shrink: 0;
    accent-color: var(--success);
    width: 1rem;
    height: 1rem;
  }

  .finding label {
    flex: 1;
    cursor: pointer;
  }

  .finding:has(input:checked) {
    opacity: 0.5;
    text-decoration: line-through;
  }

  .finding:has(input:checked):hover {
    opacity: 0.75;
  }

  .no-issues {
    color: var(--success);
    font-style: italic;
  }

  .voice-guardian {
    margin-bottom: 2rem;
  }

  .voice-guardian details {
    background: var(--bg-secondary);
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 1rem;
  }

  .voice-guardian summary {
    cursor: pointer;
    color: var(--accent);
    font-weight: 600;
  }

  .voice-guardian summary h2 {
    display: inline;
    font-size: 1rem;
  }

  .voice-profile {
    margin-top: 0.75rem;
    padding-top: 0.75rem;
    border-top: 1px solid var(--border);
    font-size: 0.85rem;
    color: var(--text-muted);
    white-space: pre-wrap;
  }

  .appendix {
    margin-top: 2rem;
    border-top: 1px solid var(--border);
    padding-top: 1.5rem;
  }

  .appendix details {
    font-size: 0.85rem;
  }

  .appendix summary {
    cursor: pointer;
    color: var(--text-muted);
    font-weight: 600;
    margin-bottom: 0.75rem;
  }

  .appendix .file-content {
    background: var(--code-bg);
    border: 1px solid var(--border);
    border-radius: 6px;
    padding: 1rem;
    font-family: ui-monospace, 'SF Mono', 'Cascadia Code', 'Consolas', monospace;
    font-size: 0.8rem;
    line-height: 1.5;
    white-space: pre-wrap;
    max-height: 70vh;
    overflow-y: auto;
  }

  .disclaimer {
    font-size: 0.8rem;
    color: var(--warning);
    margin-bottom: 1rem;
    padding: 0.5rem 0.75rem;
    background: rgba(210, 153, 29, 0.1);
    border-radius: 6px;
    border-left: 3px solid var(--warning);
  }

  footer {
    margin-top: 2rem;
    padding-top: 1rem;
    border-top: 1px solid var(--border);
    font-size: 0.8rem;
    color: var(--text-muted);
    text-align: center;
  }
</style>
</head>
<body>

<header>
  <h1>Review Report</h1>
  <dl class="meta">
    <dt>Source file:</dt>
    <dd>${source_file}</dd>
    <dt>Generated:</dt>
    <dd>${now_human}</dd>
    <dt>Reviewers:</dt>
    <dd>${total_reviewers}</dd>
    <dt>Model:</dt>
    <dd>${REVIEW_MODEL:-default}</dd>
  </dl>
</header>

<div class="disclaimer">
  <strong>Note:</strong> Line numbers in findings are AI estimates. Search for the quoted text to find the exact location in your source file.
</div>

<div class="summary">
  <h2>Summary</h2>
  <table>
    <thead><tr><th>Reviewer</th><th>Issues</th></tr></thead>
    <tbody>
${summary_rows}
    </tbody>
  </table>
</div>

${vg_section}

${reviewer_sections}

<div class="appendix">
  <details>
    <summary>Original File: $(basename "$source_file")</summary>
    <div class="file-content">
${original_html}
    </div>
  </details>
</div>

<footer>
  Generated by review-loop.sh on ${now_human}
</footer>

</body>
</html>
HTML

  echo -e "${GREEN}HTML report written to: ${output_path}${NC}"
}

# ---- Main loop ---------------------------------------------
echo -e "${CYAN}${BOLD}=== Review Loop: $(basename "$FILE") ===${NC}"
if $REPORT_MODE; then
  echo "  Reviewers: ${#REVIEWERS[@]}  |  Mode: report"
  echo "  Output: ${REPORT_HTML}"
  if [[ -n "$REVIEW_MODEL" ]]; then
    echo "  Review model: ${REVIEW_MODEL}"
  fi
  echo "  Max iterations: $MAX_ITERATIONS"
  echo ""

  START_TIME=$(date +%s)
  ITERATION=0
  PASSES=0
  FAILS=0

  # Parallel arrays to collect reviewer outputs for the report
  REVIEWER_NAMES=()
  REVIEWER_OUTPUTS=()

  for REVIEWER_FILE in "${REVIEWERS[@]}"; do
    ITERATION=$((ITERATION + 1))

    if [[ $ITERATION -gt $MAX_ITERATIONS ]]; then
      echo -e "${YELLOW}Max iterations ($MAX_ITERATIONS) reached. Stopping.${NC}"
      break
    fi

    BASE=$(basename "$REVIEWER_FILE" .md)
    DISPLAY_NAME=$(echo "$BASE" | sed 's/^[0-9]*-//')

    echo -e "${GREEN}${BOLD}> Pass $ITERATION/${#REVIEWERS[@]}: $DISPLAY_NAME${NC}"
    echo "  -----------------------------------------"

    REVIEWER_CONTENT=$(cat "$REVIEWER_FILE")
    REVIEW_PROMPT=$(build_review_prompt "$REVIEWER_CONTENT" "$TONE_PROFILE")

    local_model="${REVIEW_MODEL:-}"
    if [[ -n "$local_model" ]]; then
      echo "  Reviewing with ${local_model}..."
    else
      echo "  Reviewing..."
    fi
    PASS_START=$(date +%s)

    REVIEW_OUTPUT_FILE=$(mktemp /tmp/review-output.XXXXXX)
    if run_pi "$REVIEW_PROMPT" ${local_model:+--model "$local_model"} > "$REVIEW_OUTPUT_FILE"; then
      PASS_END=$(date +%s)
      PASS_DUR=$((PASS_END - PASS_START))
      REVIEWER_NAMES+=("$DISPLAY_NAME")
      REVIEWER_OUTPUTS+=("$(cat "$REVIEW_OUTPUT_FILE")")
      echo -e "  ${GREEN}  Done${NC} (${PASS_DUR}s)"
      PASSES=$((PASSES + 1))
    else
      PASS_END=$(date +%s)
      PASS_DUR=$((PASS_END - PASS_START))
      REVIEWER_NAMES+=("$DISPLAY_NAME")
      REVIEWER_OUTPUTS+=("REVIEW FAILED (exit code $?)")
      echo -e "  ${RED}  Review failed${NC} (${PASS_DUR}s)"
      FAILS=$((FAILS + 1))
    fi
    rm -f "$REVIEW_OUTPUT_FILE"
    echo ""
  done

  # Generate the HTML report
  echo -e "${CYAN}${BOLD}=== Generating HTML Report ===${NC}"
  generate_html_report "$REPORT_HTML" "$FILE" "$TONE_PROFILE"

  # Optionally commit the report
  if $COMMIT_REPORT && git rev-parse --git-dir > /dev/null 2>&1; then
    git add "$REPORT_HTML" 2>/dev/null || true
    git commit -m "report: $(basename "$FILE") — ${#REVIEWERS[@]} reviewers, $PASSES passed" -- "$REPORT_HTML" 2>/dev/null || true
    echo -e "${GREEN}  Report committed.${NC}"
  fi

  # Summary for report mode
  END_TIME=$(date +%s)
  TOTAL_DUR=$((END_TIME - START_TIME))
  echo ""
  echo -e "${CYAN}${BOLD}=== Review Loop Complete ===${NC}"
  echo "  File:      $FILE"
  echo "  Report:    $REPORT_HTML"
  echo "  Duration:  ${TOTAL_DUR}s"
  echo "  Passes:    $PASSES completed, $FAILS failed"
  echo ""
  echo -e "  ${BOLD}Open report:${NC}  open $REPORT_HTML"
  exit 0
fi

# ---- Non-report mode continues below ----

if $TWO_PHASE; then
  echo "  Reviewers: ${#REVIEWERS[@]}  |  Mode: two-phase"
  echo "  Review model: ${REVIEW_MODEL}  |  Fix model: ${FIX_MODEL}"
else
  echo "  Reviewers: ${#REVIEWERS[@]}  |  Mode: single-phase"
fi
echo "  Max iterations: $MAX_ITERATIONS"
echo ""

START_TIME=$(date +%s)
ITERATION=0
PASSES=0
FAILS=0

for REVIEWER_FILE in "${REVIEWERS[@]}"; do
  ITERATION=$((ITERATION + 1))

  if [[ $ITERATION -gt $MAX_ITERATIONS ]]; then
    echo -e "${YELLOW}Max iterations ($MAX_ITERATIONS) reached. Stopping.${NC}"
    break
  fi

  BASE=$(basename "$REVIEWER_FILE" .md)
  DISPLAY_NAME=$(echo "$BASE" | sed 's/^[0-9]*-//')

  echo -e "${GREEN}${BOLD}> Pass $ITERATION/${#REVIEWERS[@]}: $DISPLAY_NAME${NC}"
  echo "  -----------------------------------------"

  REVIEWER_CONTENT=$(cat "$REVIEWER_FILE")

  if $TWO_PHASE; then
    # ==========================================================
    # TWO-PHASE: review (no edits) then fix (apply edits)
    # ==========================================================

    # -- Phase 1: REVIEW ---------------------------------------
    REVIEW_PROMPT=$(build_review_prompt "$REVIEWER_CONTENT")
    echo "  [1/2] Reviewing with ${REVIEW_MODEL}..."
    PHASE1_START=$(date +%s)

    REVIEW_REPORT_FILE=$(mktemp /tmp/review-report.XXXXXX)
    if run_pi "$REVIEW_PROMPT" --model "$REVIEW_MODEL" > "$REVIEW_REPORT_FILE"; then
      PHASE1_END=$(date +%s)
      PHASE1_DUR=$((PHASE1_END - PHASE1_START))
      ISSUE_COUNT=$(grep -cE '^#+[0-9]+\.?[[:space:]]|^\*\*#[0-9]+|^### Issue|^[0-9]+\.' "$REVIEW_REPORT_FILE" 2>/dev/null || echo "?")
      echo -e "  ${GREEN}  Review done${NC} (${PHASE1_DUR}s) - ~${ISSUE_COUNT} issues found"
    else
      PHASE1_END=$(date +%s)
      PHASE1_DUR=$((PHASE1_END - PHASE1_START))
      echo -e "  ${RED}  Review failed${NC} (${PHASE1_DUR}s)"
      rm -f "$REVIEW_REPORT_FILE"
      FAILS=$((FAILS + 1))
      echo ""
      continue
    fi

    # -- Phase 2: FIX ------------------------------------------
    REVIEW_CONTENT=$(cat "$REVIEW_REPORT_FILE")
    rm -f "$REVIEW_REPORT_FILE"

    FIX_PROMPT=$(build_fix_prompt "$REVIEW_CONTENT" "$TONE_PROFILE")
    echo "  [2/2] Fixing with ${FIX_MODEL}..."
    PHASE2_START=$(date +%s)
    PRE_HASH=$(git hash-object "$FILE" 2>/dev/null || true)

    if run_pi "$FIX_PROMPT" --model "$FIX_MODEL"; then
      PHASE2_END=$(date +%s)
      PHASE2_DUR=$((PHASE2_END - PHASE2_START))
      TOTAL_DUR=$((PHASE2_END - PHASE1_START))

      if commit_if_changed "$PRE_HASH" "$DISPLAY_NAME"; then
        echo -e "  ${GREEN}  Fix done${NC} (${PHASE2_DUR}s) - committed (total: ${TOTAL_DUR}s)"
      else
        echo -e "  ${GREEN}  Fix done${NC} (${PHASE2_DUR}s) - no changes (total: ${TOTAL_DUR}s)"
      fi
      PASSES=$((PASSES + 1))
    else
      echo -e "  ${RED}  Fix failed${NC}"
      FAILS=$((FAILS + 1))
    fi

  else
    # ==========================================================
    # SINGLE-PHASE: review and fix in one call
    # ==========================================================
    PI_PROMPT=$(build_single_prompt "$REVIEWER_CONTENT" "$TONE_PROFILE")

    echo "  Running ${PI_CMD}..."
    PASS_START=$(date +%s)
    PRE_HASH=$(git hash-object "$FILE" 2>/dev/null || true)

    if run_pi "$PI_PROMPT"; then
      PASS_END=$(date +%s)
      PASS_DUR=$((PASS_END - PASS_START))

      if commit_if_changed "$PRE_HASH" "$DISPLAY_NAME"; then
        echo -e "  ${GREEN}  Done${NC} (${PASS_DUR}s) - committed"
      else
        echo -e "  ${GREEN}  Done${NC} (${PASS_DUR}s) - no changes"
      fi
      PASSES=$((PASSES + 1))
    else
      FAILS=$((FAILS + 1))
      echo -e "  ${RED}  Pi exited with error (code $?)${NC}"
    fi
  fi

  echo ""
done

# ---- Summary -----------------------------------------------
END_TIME=$(date +%s)
TOTAL_DUR=$((END_TIME - START_TIME))

echo -e "${CYAN}${BOLD}=== Review Loop Complete ===${NC}"
echo "  File:      $FILE"
echo "  Duration:  ${TOTAL_DUR}s"
echo "  Passes:    $PASSES completed, $FAILS failed"
echo ""
echo "  ${BOLD}Recent commits:${NC}"
git log --oneline -"$ITERATION" -- "$FILE" 2>/dev/null || echo "  (no commits)"
echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo "    1. Review the commits:  git log -p -- $FILE"
echo "    2. If satisfied:        git push"
echo "    3. Re-run from a specific reviewer: $0 $FILE --from <name>"
