---
name: no-slop
description: Remove AI-generated code slop and clean up code style. Use when the user explicitly asks to clean AI slop, remove generated-code smell, tidy verbose AI output, or normalize style after an AI edit.
disable-model-invocation: true
---

# Remove AI-Generated Code Slop

Clean AI-written code so it reads like deliberate human work: match the repo, delete theater, keep behavior.

## Workflow

1. Identify the target files or diff (ask if unclear).
2. Read surrounding code and mirror its naming, structure, and abstraction level.
3. Remove slop using the checklist below — prefer deletion over rewriting.
4. Keep behavior identical unless the user asked for a behavior change.
5. Run relevant tests/linters if the project has them.
6. Summarize what you removed or simplified (short bullet list).

## Slop Checklist

### Comments and "AI voice"

- Delete narration comments that restate the code (`// increment counter`, `// return the result`).
- Delete boilerplate file/section banners and obvious TODO theater.
- Keep comments only for non-obvious intent, constraints, or invariants.
- Remove apologetic, chatty, or tutorial-style wording in code and docs touched by the change.



### Over-abstraction and dead weight

- Inline single-use helpers that add indirection without clarity.
- Remove unused imports, variables, parameters, and dead branches.
- Collapse premature abstractions (generic "utils", config objects, factories) built for one call site.
- Prefer the project's existing patterns over new layers.



### Defensive and speculative code

- Remove try/catch, null checks, and fallbacks that guard against impossible cases in this codebase.
- Delete feature flags, options, and "just in case" parameters nobody asked for.
- Don't add error handling the surrounding code doesn't use.



### Control flow and cleverness

- Prefer straightforward `if`/`return` over nested ternaries and dense one-liners.
- Prefer early returns over deep nesting.
- Replace clever tricks with the boring form used elsewhere in the repo.
- Keep functions small and purposeful; split only when it matches local style.



### Style match

- Match existing naming, file layout, imports, and formatting.
- Prefer functional style where the project already does (per project TypeScript rules).
- Do not introduce new libraries; do not "improve" unrelated code.
- Leave intentional quirks alone if they are consistent and tested.



### Types and APIs (when applicable)

- Delete redundant type aliases and overly wide `any`/`unknown` casts added for convenience.
- Don't export symbols that are only used once internally.
- Avoid wrapper types that exist only to look enterprise-ready.



## Guardrails

- No drive-by refactors outside the requested scope.
- No behavior changes disguised as cleanup — call them out and get approval first.
- No new comments explaining the cleanup.
- If unsure whether something is slop or intentional, keep it and note it in the summary.



## Example summary

```text
Cleaned AI slop in src/clock.ts:
- Removed 4 narration comments
- Inlined unused formatHelper
- Flattened nested ternary into early returns
- Matched existing naming (getTime → formatTime)
```

