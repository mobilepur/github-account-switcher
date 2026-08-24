# GitHub Account Switcher

A small wrapper for switching between accounts authenticated with the GitHub CLI.

> Work in progress.

Requires the [GitHub CLI](https://cli.github.com/) with at least one authenticated
account.

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
```

Accounts and the active login are read from `gh`. SSH key mapping will be added
separately.

## License

[MIT](LICENSE)
