# README.org Workshop Review Loop — Findings Log

Started: 2026-07-25
Constraint: report-only; no material edits; no repetition across iterations
Prior art avoided: review-report-README-20260722 (jargon, citations, grok-4.5[], beforeShellCommand typo, moment.js demo clarity, chmod, privacy mode, rule size claims)
Updated: per-item suggestions added

## Iteration 1 — Live meetup facilitation / room dynamics

1. **No timing budget** — 5 major topics + hands-on will overrun a 60–90m slot.
  - **Suggestion:** Publish a timing table in a facilitator note: e.g. Pembuka 8m → Rules 20m → Skills 15m → Subagent 10m → Hooks 15m → Marketplace 7m → Penutup 5m. Mark Marketplace + Subagent as “cut first if late.”
2. **No demo-fail script** — agent demos are non-deterministic; no Plan B.
  - **Suggestion:** For each live prompt, store a screenshot + short “expected good / acceptable weird / skip” note. If `refactor` goes sideways, paste a pre-written follow-up: “Stop. Only change X. Don’t touch Y.” If hook doesn’t fire, switch to showing `hooks.png` and explain what should have happened.
3. **No shared workspace state** — Trusted Workspace / Privacy Mode / version drift not mentioned.
  - **Suggestion:** Add a 30-second preflight checklist before Hooks: Cursor ≥ 3.2, repo Trusted, terminal works, `jq` installed (or WSL note). Put “Trusted workspace required for project hooks” next to the hooks.json steps.
4. **No facilitator checklist** — QR, clone URL, wifi/GitHub blockers.
  - **Suggestion:** Separate `FACILITATOR.md` checklist: open feedback QR at start; paste clone URL in chat/slide; have a USB/zip mirror; remind “GitHub login before session”; test projector on Cursor Agent UI (not IDE).



## Iteration 2 — Curriculum scaffolding / learning science

1. **Thinking-framework is** `COMMENT`**-ed out** — conceptual spine missing in export.
  - **Suggestion:** Uncomment a trimmed 5-bullet pyramid (Logical→Analytical→Computational→Procedural) before Rules, or move the full section to a facilitator appendix and leave the 5 bullets for attendees.
2. **Outcomes never checked in Penutup** — list of 5 skills, no “can you now…?”
  - **Suggestion:** End with a 5-box self-check: “Saya bisa: buat rule / sebut skill / panggil subagent / pasang hook / install dari Marketplace.” Ask for thumbs or chat emoji.
3. **No formative check after Rules** — jump to Skills without verifying Rules worked.
  - **Suggestion:** After the `refactor` demo, add one question: “Apakah agent menolak backend / tetap pakai Astro + lime green?” If no → fix rules before continuing.
4. **Full TDD skill dumped without MVP skill** — contradicts “start small.”
  - **Suggestion:** Insert a 8–12 line “mini skill” (e.g. “always run tests after edits”) first; then show full Tidy TDD as “versi lengkap untuk dibawa pulang.”



## Iteration 3 — Repo fidelity vs follow-along

1. `npm install` **but no** `package.json` — immediate prereq failure.
  - **Suggestion:** Either commit a minimal `package.json` + Astro scaffold, or change prereq to: “Jangan `npm install` dulu — kita bootstrap proyek di sesi dengan prompt X.”
2. **No starter app / “aplikasi yang sudah kita buat” assumes prior work** — disk doesn’t match narrative.
  - **Suggestion:** Ship `examples/clock-starter/` with one working page, or add an early agent prompt that creates the app and a commit tag `starter` attendees can reset to.
3. `setting-2.png` **unused** — dead asset / unfinished path.
  - **Suggestion:** Wire it into the Rules UI steps (e.g. Apply Intelligently screen) or delete/rename so facilitators aren’t hunting a missing figure.
4. **Clone URL / access unclear** (`hacktiv8/cursor-from-scratch`).
  - **Suggestion:** State clearly: public read-only clone is enough; no push required. If fork is needed, say so. Pin branch (`main`) and commit/tag for the meetup date.



## Iteration 4 — Promise vs delivery mismatch

1. **Monetization Officer is largest example but off-story** — breaks the clock-app thread.
  - **Suggestion:** Replace with a workshop-native subagent (e.g. `timezone-a11y-officer` that reviews WIB/WITA/WIT UI for readability). Keep monetization as optional appendix.
2. **Marketplace is outcome but only browse** — no install→verify→use.
  - **Suggestion:** One drill: install Continual Learning (or a tiny pack) → ask agent a question that should trigger it → show where it appeared in context / behavior.
3. **AGENTS.md in heading, no worked contrast with** `.mdc`.
  - **Suggestion:** Add a 4-row table: portable across agents → AGENTS.md; Cursor-only modes/globs → `.mdc`; team using multiple tools → both with shared content.
4. **Hooks paths** `./cursor/...` **vs real** `.cursor/...` — copy/paste footgun.
  - **Suggestion:** Rename headings/blocks to `.cursor/hooks.json` and `.cursor/hooks/guard-npm.sh`; add one line: “Titik di depan = folder tersembunyi di root proyek.”
5. **Stray markdown fence after** `chmod` (~line 487) — can break Org export.
  - **Suggestion:** Remove the orphan `````; re-export HTML once to confirm hooks section renders.



## Iteration 5 — Failure modes & environment matrix

1. **Windows attendees unsupported for bash/**`jq` **hooks**.
  - **Suggestion:** Add OS note: macOS/Linux follow bash; Windows use WSL2 or skip hands-on hooks and watch demo. Optional: tiny PowerShell deny stub as “advanced.”
2. **Hook fail-open / vague “tergantung versi”** — safety-critical ambiguity.
  - **Suggestion:** Ritual: run a known-blocked command (`npm install moment`), confirm deny message + screenshot. Add: “Kalau command tetap jalan, hook gagal (JSON/path/Trusted) — jangan anggap aman.”
3. **Bypass via** `npx` **/ edit package.json + bare** `npm install` — removed from material, still #1 embarrassment.
  - **Suggestion:** Optional advanced callout (3 sentences): pattern matching ≠ complete policy; agent can edit `package.json` then `npm install`; combine with `afterFileEdit` or git pre-commit if you need teeth.
4. `Apply Intelligently` **hard to prove live**.
  - **Suggestion:** A/B pair: Prompt A clearly about CSS theme (rule should apply) vs Prompt B about unrelated git history (rule may skip). Ask attendees which run mentioned lime green / Astro.



## Iteration 6 — Security / trust / supply chain

1. **Marketplace = third-party code in agent context — no threat model**.
  - **Suggestion:** One slide/paragraph: “Install = trust. Skill/hook bisa mengarahkan agent.” Rule of thumb: read SKILL.md / hooks before enable; prefer packs you can open in the repo.
2. **Deny-npm taught as if it were “security”** — narrow guardrail oversold.
  - **Suggestion:** Explicit framing: “Ini demo guardrail dependensi, bukan security suite.” List 2 things it does *not* stop (`curl|bash`, reading `.env`).
3. **Monetization subagent includes Data/API access** — odd ethics signal without framing.
  - **Suggestion:** If kept, add: “Opsi ini untuk evaluasi; jangan implement tanpa legal/ethics review.” Or remove Data/API row from beginner workshop example.
4. **No “review before enable” guidance for skills**.
  - **Suggestion:** 3-step habit: open SKILL.md → scan for shell/network assumptions → enable with least scope; disable if unused.



## Iteration 7 — Indonesian meetup audience & inclusion

1. **Longest cognitive load in English** (TDD skill / YAML) while teaching voice is Indonesian.
  - **Suggestion:** Keep code in English if needed, but add Indonesian section titles + 1-line gloss under each major heading of the skill (“Red = test gagal dulu”).
2. **Assumes GitHub + clone fluency** — corporate SSO/device blocks.
  - **Suggestion:** Offer `curl`/zip download of the tag; or USB/local mirror; say “kalau clone gagal, ikut demo layar saja sampai Skills.”
3. **a11y constraints stated, never verified**.
  - **Suggestion:** After first UI exists: “Zoom browser 200% — apakah teks masih kebaca? Contrast lime green vs background cukup?” Ties rule → measurable outcome.
4. **Popular cities exercise re-centers Western metros without why**.
  - **Suggestion:** One sentence why: “Bandingkan dengan zona yang sering muncul di dokumentasi/library internasional” — or mix in Asian cities (Tokyo, Singapore, Dubai) beside NY/London.



## Iteration 8 — Assessment, transfer, and day-2

1. **No take-home for their real job repo**.
  - **Suggestion:** Last 10 minutes: “Buka repo kerja (atau fork kosong) → tulis 1 rule: stack + 2 constraints → commit.” Provide a pasteable template.
2. **No anti-patterns section**.
  - **Suggestion:** Short list: mega Always Apply rules; 20 Marketplace packs at once; hooks that fail open; English-only rules nobody on the team can maintain.
3. **No migration path meetup toy → work (monorepo, existing AGENTS.md, team buy-in)**.
  - **Suggestion:** 5-bullet “Bawa pulang ke kantor”: start with AGENTS.md if multi-tool; one Always Apply + rest globbed; propose hooks in PR; don’t rewrite team process in one day.
4. **Feedback QR with no prompt structure**.
  - **Suggestion:** On the QR slide, 3 questions: (1) tempo terlalu cepat/lambat? (2) bagian mana paling berguna? (3) apa yang masih bingung?



## Iteration 9 — Information architecture / Org-mode hazards

1. **TOC under Agenda while conceptual section is COMMENT** — sparse/misleading TOC.
  - **Suggestion:** Either restore a visible short kerangka section so TOC has a spine, or replace `#+TOC` with a hand-written agenda list that matches what attendees actually see.
2. `COMMENT` **exercises = secret curriculum** — HTML/GitHub ≠ author view.
  - **Suggestion:** Split: attendee `README.org` (no COMMENT lessons) + `facilitator-notes.org` for optional exercises. Or label COMMENT blocks “opsional fasilitator.”
3. **QR caption still says “Tampilan Cursor 3”** — wrong figure semantics.
  - **Suggestion:** Caption/name → “QR Code umpan balik sesi” / `fig:feedback-qr`.
4. **Glossary missing workshop UI nouns** (`@Rules`, Trusted workspace).
  - **Suggestion:** Add entries: Trusted Workspace, @-mention / @Rules, Command Palette — each with “di mana diklik” in one line.



## Iteration 10 — Strategic blind spots

1. **Fragile single narrative (clock app)** — early failure kills later demos.
  - **Suggestion:** “Latecomer packet”: pasteable product brief + tech stack + 3 constraints. Anyone joining at Hooks can paste it and continue.
2. **Product churn — Cursor 3.2 UI may move by August**.
  - **Suggestion:** Footer stamp: “Last verified: YYYY-MM-DD on Cursor x.y.” Add: “UI bisa pindah — pakai Command Palette: ‘New Rule’ / ‘Marketplace’.”
3. **Marketplace name-drops without selection criteria** — teaches consumption.
  - **Suggestion:** 3 questions before install: Does it match our stack? Can we read the source? What’s the blast radius (always-on vs on-demand)?
4. **Missing “when NOT to customize”**.
  - **Suggestion:** One box: “Kalau tugas 1 file / 1 perintah, jangan pasang 5 rules. Minimal viable: 1 project rule pendek. Tambah skill/hook hanya setelah sakit yang sama muncul 2–3×.”
5. **No before/after measurement** — thesis stays rhetorical.
  - **Suggestion:** Ritual: same prompt `Buat aplikasi web yang menampilkan tanggal dan jam…` once before rules (screenshot) and once after (screenshot). Attendees keep both as proof.
6. **Facilitator knowledge debt** — monetization + full TDD hard for co-facilitators.
  - **Suggestion:** Prefer simpler demos for the main path; park deep examples in appendix with “fasilitator harus dry-run seminggu sebelumnya” checklist.

