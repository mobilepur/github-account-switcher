# GitHub Account Switcher

A small wrapper for switching between accounts authenticated with the GitHub CLI.

> Work in progress.

Requires the [GitHub CLI](https://cli.github.com/) with at least one authenticated
account.

## Install from HEAD

Until the first tagged release is available:

```sh
brew tap mobilepur/gh-switcher https://github.com/mobilepur/github-account-switcher
brew install --HEAD mobilepur/gh-switcher/gh-switcher
open "$(brew --prefix gh-switcher)/GitHub Account Switcher.app"
```

The app can register itself in macOS Login Items using the `Start at Login`
toggle. macOS 14 or newer and the GitHub CLI are required.

## Setup

Authenticate each account with `gh`, then link its existing SSH key:

```sh
gh auth login
gh-switcher ssh link mobilepur ~/.ssh/id_ed25519_mobilepur --alias work
gh-switcher ssh link nayooti ~/.ssh/id_ed25519
gh-switcher setup
```

`setup` creates a one-time backup at `~/.ssh/config.gh-switcher.backup` and adds
an include for the SSH configuration managed by `gh-switcher`. Existing SSH
hosts remain untouched.

## Development

```sh
swift run gh-switcher
swift test
```

## Account commands

```sh
gh-switcher accounts
gh-switcher use mobilepur
gh-switcher current
gh-switcher ssh mappings
```

Accounts and the active login are read from `gh`. On `use`, the matching SSH key
is activated for `github.com`; if `gh auth switch` fails, the previous managed
SSH configuration is restored.

## License

[MIT](LICENSE)
