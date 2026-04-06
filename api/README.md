# API Development

## Local startup

This app expects Ruby `3.3.x`. The repository already declares `ruby-3.3.0` in
[.ruby-version](/Users/e0195/重要/uketori-pj/uketori/api/.ruby-version), and the
current local setup works with `mise`.

Recommended commands:

```bash
cd api
bin/dev
```

`bin/dev` prefers `mise exec` automatically when `mise` is installed, so it can
start with the project Ruby even if your shell is still pointing at the system
Ruby.

If you want to fix your shell itself, add `mise` activation to `~/.zshrc`:

```bash
eval "$(mise activate zsh)"
```

Then restart the shell and verify:

```bash
ruby -v
bundle -v
```

Expected versions:

```text
ruby 3.3.x
Bundler version 2.5.22
```
