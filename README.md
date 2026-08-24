# GitHub Account Switcher

A small CLI for switching GitHub accounts using your existing SSH configuration.

> Work in progress.

## Development

```sh
swift run gh-switcher
swift test
```

## Account commands

```sh
gh-switcher accounts
gh-switcher account link ~/.ssh/id_ed25519 [--alias personal]
gh-switcher account unlink personal
```

Linked accounts are stored locally. The CLI records the SSH key path, but does
not read or copy the private key.

## License

[MIT](LICENSE)
