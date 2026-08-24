# GitHub Account Switcher

A small CLI for switching GitHub accounts using your existing SSH configuration.

> Work in progress.

## Development

```sh
swift run gas
swift test
```

## Account commands

```sh
gas accounts
gas account link ~/.ssh/id_ed25519 [--alias personal]
gas account unlink personal
```

Linked accounts are stored locally. The CLI records the SSH key path, but does
not read or copy the private key.

## License

[MIT](LICENSE)
