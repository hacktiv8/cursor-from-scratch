# Plan: Apply Beginner Reviewer Fixes to README.org

## Summary
Apply 16 accepted changes from the beginner review of README.org. Changes focus on defining jargon, removing ML-specific terms, and clarifying concepts for beginners.

## Applied Changes (16)

### 1. Define LLM on first use (Pembuka, paragraph 1)
- Change: `menggunakan LLM, yang sifat dasarnya` → `menggunakan Large Language Model (LLM), yang sifat dasarnya`

### 2. Define "non deterministic" inline (Mode Interaksi Cursor, paragraph 2)
- Add gloss: `/non deterministic/, artinya input yang sama bisa menghasilkan output yang berbeda setiap kali`

### 3. Add concrete Marketplace description (Yang Akan Kita Pelajari)
- Change: `Customization Marketplace → Memanfaatkan pengetahuan komunitas` → `Customization Marketplace → Menginstal rules, skills, subagent, atau hooks buatan komunitas langsung dari dalam Cursor`

### 4. Define "harness" inline (Mode Interaksi Cursor, paragraph 2)
- Add definition after `sebagai /harness/` using regular dashes (no em dashes)

### 5. Define "system prompt" inline (Mode Interaksi Cursor, paragraph 2)
- Change: `Tanpa /system prompt/ yang jelas` → `Tanpa /system prompt/ - instruksi default yang dikirim Cursor ke LLM setiap kali kita ngirim perintah - yang jelas`

### 6. Replace "bias training data" with simpler concept (Mode Interaksi Cursor, paragraph 2)
- Replace ML-specific phrasing with simpler explanation (no ML jargon)

### 7. Simplify "/cloud/" reference (Mode Interaksi Cursor, ⚠️ paragraph)
- Change: `dikirim ke LLM yang ada di /cloud/` → `dikirim ke LLM`

### 8. Define "glob pattern" (Memberi Instruksi dengan RULES, paragraph 2)
- Add: `metadata untuk mencocokkan pola nama file sehingga aturan akan ditetapkan`

### 9. Define "open standard" (Menambahkan Skill, paragraph 1)
- Add brief definition of what open standard means

### 10. Replace "dependensi" (Menambahkan Skill, paragraph 1)
- Change: `membutuhkan dependensi tertentu` → `membutuhkan library atau tools tambahan yang harus di-install terlebih dahulu`

### 11. Trim Kent Beck reference (Contoh Skill: Tidy TDD)
- Trim the name-drop to be less dependent on assumed recognition

### 12. Remove alternative hooks paragraph
- Remove the paragraph about `onFileChange` hooks and pre-commit hook git alternatives

### 13. Add expected outcome for hooks demo
- Before "Coba dengan mengeksekusi perintah berikut", add expected outcome: agent will try npm install, hook will block it

### 14. Add missing glossary entries
- Add entries for: harness, system prompt, non deterministic, agentic loop, context window, token, cloud, glob pattern, open standard, codebase, VS Code, npm, backend/frontend, refactor

### 15. Change "harness agent" to "harness coding tools" (Penutup)
- Change: `/harness agent/` → `/harness coding tools/`

### 16. Remove duplicate "bisa" (Mode Interaksi Cursor, paragraph 2)
- Change: `bisa bisa` → `bisa`

## Skipped (16 findings)
3 (density bomb), 5 (Node.js), 6 (git commands), 10 (agentic loop), 12 (COMMENT section), 14 (token), 15 (sidebar), 16 (project setup note), 19 (English skill note), 21 (context window), 22 (slash command), 23 (jq), 24 (bash script), 27 (marketplace sidebar), 31 (Glosarium pointer), 32 (OS guidance)

## Voice Constraints
- No em dashes — use regular dashes, commas, or periods
- Preserve `/word/` slash-emphasis pattern
- Preserve colloquial Indonesian register
- Preserve "kita" learning-journey perspective

## Files to Modify
- `README.org`
