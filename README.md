# GitHub Account Switcher

<p align="center">
  <img src="App/AppIcon.png" alt="GitHub Account Switcher app icon" width="192">
</p>

GitHub Account Switcher keeps the active [GitHub CLI](https://cli.github.com/)
account and its SSH key in sync. It includes a command-line tool and a native
macOS menu bar app.

## Features

- Switch the active `gh` account and matching SSH key together.
- Keep existing SSH hosts and configuration untouched.
- Access configured accounts from the macOS menu bar.
- Display GitHub avatars in the account menu.
- Optionally start the menu bar app at login.
- Restore the previous SSH configuration if account switching fails.

## Requirements

- macOS 14 Sonoma or newer
- [Homebrew](https://brew.sh/)
- At least one account authenticated with the GitHub CLI

## Install with Homebrew

The project does not have a tagged release yet. Install the current version
from `main` with:

```sh
brew tap mobilepur/gh-switcher https://github.com/mobilepur/github-account-switcher
brew install --HEAD mobilepur/gh-switcher/gh-switcher
```

Start the menu bar app:

```sh
open "$(brew --prefix gh-switcher)/GitHub Account Switcher.app"
```

The formula also installs the `gh-switcher` command-line tool. Upgrade to the
latest commit with:

```sh
brew update
brew upgrade --fetch-HEAD gh-switcher
```

Uninstall the app and CLI with:

```sh
brew uninstall gh-switcher
brew untap mobilepur/gh-switcher
```

Once the first version is tagged, installation will no longer need `--HEAD`.

## Set up accounts

Authenticate every GitHub account first:

```sh
gh auth login
```

Then link each account to its existing private SSH key. The optional alias is
used as the short label in the menu bar.

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

## Command-line usage

```sh
gh-switcher accounts
gh-switcher use mobilepur
gh-switcher current
gh-switcher ssh mappings
```

Run `gh-switcher` without arguments to see all available commands.

## App icon

The custom macOS icon uses the split black-and-white GitHub mark from the final
design iteration. The 1024 × 1024 source image is stored at `App/AppIcon.png`;
the bundled macOS representation is `App/AppIcon.icns`.

## Development

```sh
swift run gh-switcher
swift run gh-switcher-menubar
swift test
```

The Homebrew formula builds both release executables, assembles the `.app`
bundle, and applies an ad-hoc code signature.

## License

[MIT](LICENSE)
