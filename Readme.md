# Dotfiles

## Installation

### Stow

```bash
stow . --target ~ --dotfiles --restow
```

`--dotfiles` - takes filename prefix `dot-` and replace it in a target with `.`
`--restow` - remove from target unexsiting links
