# Account switching smoke test

This file exists only on the unmerged smoke-test pull request.

## Commit sequence

1. Initial commit created with the currently active GitHub account.
2. A second dummy commit will be added after switching accounts in GitHub Account Switcher.
3. The Git identity switching implementation is committed with the identity
   currently selected before this test commit.
4. A follow-up commit records the author identity used after another account
   switching attempt.
5. A second post-implementation commit verifies switching the commit identity
   back to the other configured account.

Do not merge this pull request.
