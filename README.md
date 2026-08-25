# GitHub Account Switcher

Switch between your GitHub accounts directly from the macOS menu bar. With one
click, GitHub Account Switcher updates both the active
[GitHub CLI](https://cli.github.com/) account and the local SSH identity used
for GitHub.

## Installation

Install the app with Homebrew:

```sh
brew tap mobilepur/gh-switcher https://github.com/mobilepur/github-account-switcher
brew install --cask mobilepur/gh-switcher/github-account-switcher
```

Open **GitHub Account Switcher** from Applications, Spotlight, or Launchpad. The
app then stays available in the menu bar. The Cask also installs the
`gh-switcher` command-line tool.

### Update

Upgrade to the latest commit with:

```sh
brew update
brew upgrade --cask --greedy github-account-switcher
```

### Uninstall

Uninstall the app and CLI with:

```sh
brew uninstall --cask github-account-switcher
brew untap mobilepur/gh-switcher
```

If you installed an earlier version with the `--HEAD` Formula, migrate once
with:

```sh
brew uninstall gh-switcher
brew install --cask mobilepur/gh-switcher/github-account-switcher
```

## Features

- Switch the active `gh` account and matching local SSH identity together.
- Keep existing SSH hosts and configuration untouched.
- Access configured accounts from the macOS menu bar.
- Display GitHub avatars in the account menu.
- Optionally start the menu bar app at login.
- Restore the previous SSH configuration if account switching fails.

## Set up accounts

Authenticate each GitHub account first:

```sh
gh auth login
```

Then open the menu bar app, choose **Configure Accounts**, and link each account
to its existing private SSH key. Once configured, select an account in the menu
bar to switch both GitHub CLI and SSH.

You can also configure accounts with the command-line tool. The optional alias
is used as the short label in the menu bar.

```sh
gh-switcher ssh link mobilepur ~/.ssh/id_ed25519_mobilepur --alias work
gh-switcher ssh link nayooti ~/.ssh/id_ed25519
gh-switcher setup
```

`gh-switcher setup` creates a one-time backup at
`~/.ssh/config.gh-switcher.backup` and adds an include for the SSH configuration
managed by the app. Existing SSH hosts remain untouched.

Open GitHub Account Switcher from the menu bar to switch accounts. Enable
**Start at Login** in its settings if the app should launch automatically.

## Privacy and SSH keys

GitHub Account Switcher does not copy, upload, or store your private SSH keys.
It stores only the local path to the key selected for each account, plus an
optional display alias. The key itself stays in its existing location on your
Mac.

The app also does not store GitHub passwords, tokens, or other credentials.
Authentication remains managed by GitHub CLI; the app uses `gh auth status` and
`gh auth switch` to read and change the active account.

## Command-line usage

```sh
gh-switcher accounts
gh-switcher use mobilepur
gh-switcher current
gh-switcher ssh mappings
```

Run `gh-switcher` without arguments to see all available commands.

## Development

```sh
swift run gh-switcher
swift run gh-switcher-menubar
swift test
```

`Scripts/build-release.sh` builds both release executables, assembles and signs
the `.app` bundle, and creates the archive consumed by the Homebrew Cask.

## License

[MIT](LICENSE)
