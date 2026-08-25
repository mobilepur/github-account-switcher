# Commit Log

This file records every commit created by an agent. Add new entries at the top
using this format:

```markdown
## YYYY-MM-DD — Commit subject

- Summary: What changed and why.
- Verification: Tests and checks performed.
```

## 2026-08-25 — Refine README tone and SSH key wording

- Summary: Make the README introduction and behavior description more neutral,
  and clarify that the app stores SSH key paths without reading or modifying
  the key files.
- Verification: 26 Swift tests and `git diff --check` passed.

## 2026-08-25 — Prepare Homebrew Cask distribution

- Summary: Add Cask release packaging, signing and notarization automation,
  refresh the README, and introduce maintained release and commit documentation.
- Verification: 26 Swift tests, release packaging test, Homebrew style, shell and
  workflow syntax, and `git diff --check` passed.
