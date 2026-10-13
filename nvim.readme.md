# Neovim Cheatsheet

Config: `~/.config/nvim/init.lua` · Plugins: `~/.local/share/nvim/site/pack/plugins/start/` · Leader = `Space`
Update all plugins: `for d in ~/.local/share/nvim/site/pack/plugins/start/*; do git -C "$d" pull; done`

## Snacks explorer — file explorer (default)
| Key | Action |
|---|---|
| `Ctrl+b` / `Space e` | Toggle explorer (`nvim .` also opens it) |
| `Enter` / `l` | Open file / expand folder |
| `h` / `Z` | Collapse folder / collapse all |
| `Backspace` / `.` | Parent folder / set folder as root |
| `Ctrl+v` / `Ctrl+s` | Open in vsplit / split |
| `a` | New file (end with `/` for folder) |
| `r` / `d` | Rename / delete |
| `c` / `m` | Copy / move |
| `y` / `p` | Yank / paste file |
| `o` | Open with macOS app |
| `P` | Toggle preview |
| `H` / `I` | Toggle hidden / gitignored files |
| `/` or `i` | Type to filter (`Esc` back to list) |
| `Space /` | Grep inside folder |
| `]g` `[g` / `]d` `[d` | Next/prev git change / diagnostic |
| `Ctrl+t` | Terminal in folder |
| `q` | Close |
| `Ctrl+w h` / `Ctrl+w l` | Move to explorer / file |

## neo-tree — alternate explorer
`Space E` toggle · `Enter` open · `a` new · `r` rename · `d` delete · `c` copy · `m` move · `H` hidden · `<` `>` files/buffers/git views · `?` help · `q` close

## Buffers & splits (built-in)
| Key | Action |
|---|---|
| `:e file` | Open file |
| `Ctrl+^` | Toggle last two files |
| `]b` / `[b` | Next / prev buffer (`3]b` = jump 3) |
| `]B` / `[B` | Last / first buffer |
| `:bd` | Close buffer |
| `:vsp file` / `:sp file` | Vertical / horizontal split |
| `Ctrl+w w` / `Ctrl+w hjkl` | Cycle / move between splits |
| `:q` | Close split |

## Command line (built-in, Neovim 0.12)
Suggestions pop up automatically as you type after `:`.
| Key | Action |
|---|---|
| `Tab` / `Shift+Tab` | Next / prev suggestion |
| `Ctrl+y` / `Ctrl+e` | Accept / close list |
| `Up` / `Down` | History matching typed text |
| `Ctrl+f` | Edit history in a window |

## Shell commands (built-in)
`%` file · `%:p` full path · `%:h` file's folder · `%:t` file name
Auto: each window's working folder follows its file (`:lcd %:h` on open/switch), so `:!cmd` runs in the file's folder.
| Command | Action |
|---|---|
| `:!cd %:h && ls` | Run in file's folder |
| `:lcd %:h` / `:cd %:h` | Set folder for window / all of nvim |
| `:lcd %:h \| term` | Terminal in file's folder |
| `:r !cmd` | Insert command output into file |
| `:!wc -l %` | Run on current file |

## Terminal (built-in, zsh)
Opens ready to type. "modifiable is off" = you're in normal mode → press `i`.
| Key | Action |
|---|---|
| `Space t` | Terminal below current window (`:bel sp \| term`) |
| `:term` / `:vsp \| term` / `:tab term` | Terminal here / side split / new tab |
| `Ctrl+\` `Ctrl+n` | Stop typing (scroll, search, copy) |
| `i` | Type again |
| `Ctrl+w hjkl` | Move to other window (after `Ctrl+\ Ctrl+n`) |
| `exit` | Close shell |

## fzf-lua — fuzzy finder
| Key | Action |
|---|---|
| `Ctrl+p` / `Space ff` | Find files |
| `Space fg` | Search text in project |
| `Space fw` | Search word under cursor |
| `Space f/` | Search in current file |
| `Space fb` | Open buffers |
| `Space fr` | Recent files |
| `Space fk` / `Space fh` | Keymaps / help |
| `:FzfLua` + `Tab` | All pickers (git, diagnostics, …) |

In picker: type to filter · `Ctrl+j/k` move · `Enter` open · `Ctrl+v` vsplit · `Ctrl+s` split · `Ctrl+t` tab · `Esc` close

## scroll.nvim — scrollbars + minimap
Settings: minimap on, bars always visible, bars in Snacks explorer/neo-tree. Horizontal bar shows with `:set nowrap` on long lines.
Mouse: click track to jump · drag thumb · wheel over bar/minimap scrolls.
Ruler marks: diagnostics, git changes, search matches, current scope.
| Command | Action |
|---|---|
| `:ScrollToggle` | Scrollbars on/off |
| `:ScrollMinimapToggle` | Minimap on/off |
| `:ScrollRefresh` | Redraw |

## markdown-preview.nvim — live preview in browser
In a `.md` file: `Space mp` toggle preview (or `:MarkdownPreview` / `:MarkdownPreviewStop`). Scrolls and updates live as you type.

## plenary.nvim, nui.nvim
Helper libraries for neo-tree. No keys.

## nvim-web-devicons
File icons for Snacks, neo-tree and fzf-lua. Needs a Nerd Font in the terminal. No keys.

## tokyonight — color scheme
Active: `tokyonight-night`. Try others: `:colorscheme tokyonight-storm` / `-moon` / `-day`. Change permanently in `init.lua`.
