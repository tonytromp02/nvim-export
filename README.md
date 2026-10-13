# nvim-export

Package a Neovim config and its plugins into a portable tarball with an installer, so the same setup can be moved to another machine (macOS or Ubuntu Linux).

## Usage

On the source machine:

```bash
./nvim-export.sh [output-dir]   # default: current directory
```

This creates `nvim-bundle-<timestamp>.tar.gz`. Copy it to the target machine, then:

```bash
tar xzf nvim-bundle-*.tar.gz && ./nvim-bundle/install.sh
```

Set `NO_ANIM=1` to turn off the animated progress bar. The bar is already off when output isn't a terminal.

## What gets exported

| Source | Bundle path |
|---|---|
| `~/.config/nvim` | `config/` |
| `~/.local/share/nvim/site/pack` | `pack/` |
| `~/nvim.readme.md` (cheatsheet, optional) | `nvim.readme.md` |
| — | `PLUGINS.txt`: each plugin's repo URL and commit |
| — | `install.sh` |

`XDG_CONFIG_HOME` / `XDG_DATA_HOME` are respected. markdown-preview's `node_modules` and `bin/` are left out because they're platform-specific. The installer downloads a matching binary instead.

## Privacy and secrets

The export keeps personal data and secrets out of the bundle:

- **Excluded files:** `.env*`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, SSH keys, `.netrc`, `.npmrc`, `.pypirc`, `.git-credentials`, `credentials*`, `*.kdbx`, `.ssh/`, `.aws/`, `.gnupg/`. Each exclusion is printed.
- **Plugin git metadata:**
  - Reflogs are removed, because they contain your name and email.
  - `[user]`, `[credential]` and `http.*.extraheader` settings are removed.
  - `user:token@` is stripped from remote URLs.
- **No hostname:** `PLUGINS.txt` records only the OS and Neovim version.
- **Secret scan:** text files in the finished bundle are checked for common secrets: AWS, Anthropic, OpenAI, GitHub, GitLab, Slack and Google keys, private keys, credentials in URLs, and `password = "…"`-style lines. If anything matches, the files are listed and no tarball is written.

The scan matches common patterns only, and skips git's compressed object files. Keep API keys in environment variables, not in your config.

## What install.sh does

1. **Ubuntu only:** asks for sudo once, then runs `apt-get install git curl fzf ripgrep`.
2. **Ubuntu only:** if Neovim is older than 0.12, installs the official release to `/opt/nvim-linux-<arch>` and links it to `/usr/local/bin/nvim`.
3. Backs up the existing `~/.config/nvim` and plugin dir to `*.bak-<timestamp>`. Nothing is deleted.
4. Installs the config, plugins and cheatsheet.
5. Downloads markdown-preview's prebuilt binary (no Node.js needed). Available for Linux x86_64 and macOS (Intel and Apple Silicon).
6. Adds `vim`/`vi` → `nvim` aliases to `~/.zshrc` / `~/.bashrc`.
7. Warns if `git`, `fzf`, `rg` or the `claude` CLI (used by claudecode.nvim) is missing.

On macOS, install Neovim 0.12+ and the tools yourself, e.g. `brew install neovim fzf ripgrep`.

Icons need a [Nerd Font](https://www.nerdfonts.com/) in your terminal. The key cheatsheet is installed to `~/nvim.readme.md`.

## Files

- `nvim-export.sh`: the exporter. It also generates `install.sh`.
- `nvim.readme.md`: the Neovim key cheatsheet that ships with the bundle.
- Generated `*.tar.gz` bundles are git-ignored.
