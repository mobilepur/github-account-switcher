# Development guidelines

## Test-driven development

- Work test-first: add or change a failing behavioral test before production code.
- Implement only enough code to make the test pass, then refactor if needed.
- Run the focused test during development and the complete test suite before handing off.
- Prefer testing observable behavior over implementation details.

## Keep it small

- Avoid over-engineering under all circumstances.
- Build only what the current requirement needs; do not add speculative abstractions or features.
- Prefer the standard library and platform APIs over new dependencies.
- Introduce an abstraction only when current code or tests demonstrate a concrete need for it.
- Keep changes focused, readable, and easy to remove or revise.

## Project documentation

- Keep `Docs/RELEASE_NOTES.md` current whenever a change affects users, installation, compatibility, or release behavior.
- Record every commit made by an agent in `Docs/LOGS.md` as part of the same commit.
- Add commit-log entries newest first and include the date, commit subject, summary, and verification performed.
- Do not add release-note entries for internal-only changes that have no user-visible or release impact.
- Follow `Docs/RELEASING.md` when preparing or publishing a release.
