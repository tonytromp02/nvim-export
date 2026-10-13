#!/usr/bin/env bash
# Export Neovim config + plugins into a portable tarball with an installer.
# Usage: ./nvim-export.sh [output-dir]   (default: current directory)
# On the target machine:  tar xzf nvim-bundle-*.tar.gz && ./nvim-bundle/install.sh
set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
PACK_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/pack"
README="$HOME/nvim.readme.md"
OUT_DIR="${1:-$PWD}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$OUT_DIR/nvim-bundle-$STAMP.tar.gz"

# Progress bar, shared with install.sh (copied into it below)
read -r -d '' PROGRESS_LIB <<'LIB' || true
# Step progress bar. Animated in place when stdout is a terminal (NO_ANIM=1 to
# disable), otherwise one line per step. While animated, step output goes to a
# log that is shown only if the step fails; use `note` for messages to show.
PB_W=30 PB_TOTAL=1 PB_ANIM=0 PB_PID="" PB_LABEL="" PB_LOG="" PB_SPIN='|/-\'
if [[ -t 1 && "${TERM:-dumb}" != dumb && -z "${NO_ANIM:-}" ]]; then PB_ANIM=1; fi
exec 3>&1

pb_init() {  # pb_init <total_steps>
  PB_TOTAL=$1
  PB_LOG="$(mktemp)"
  if (( PB_ANIM )); then tput civis 2>/dev/null || true; fi
}

pb_draw() {  # pb_draw <steps_done> <label> [suffix] [tick]
  local done=$1 tick=${4:--1} fill seg i bar=""
  fill=$(( done * PB_W / PB_TOTAL ))
  seg=$(( (done + 1) * PB_W / PB_TOTAL - fill ))
  (( seg > 0 )) || seg=1
  for (( i = 0; i < PB_W; i++ )); do
    if (( i < fill )); then bar+="#"
    elif (( tick >= 0 && i - fill < tick % seg )); then bar+="="
    elif (( tick >= 0 && i - fill == tick % seg )); then bar+=">"
    else bar+="-"
    fi
  done
  printf '[%s] %3d%% (%d/%d) %s %s' "$bar" $(( done * 100 / PB_TOTAL )) "$done" "$PB_TOTAL" "$2" "${3:-}"
}

pb_stop() {
  if [[ -n "$PB_PID" ]]; then
    { kill "$PB_PID"; wait "$PB_PID"; } 2>/dev/null || true
    PB_PID=""
  fi
}

pb_step() {  # pb_step <steps_done> <label> <command...>
  local n=$1
  PB_LABEL=$2
  shift 2
  if (( PB_ANIM )); then
    (
      start=$SECONDS t=0
      while :; do
        printf '\r\033[K%s' "$(pb_draw "$n" "$PB_LABEL" "${PB_SPIN:t%4:1} $(( SECONDS - start ))s" $(( t / 2 )))" >&3
        t=$(( t + 1 ))
        sleep 0.1
      done
    ) &
    PB_PID=$!
    "$@" >>"$PB_LOG" 2>&1
    pb_stop
  else
    pb_draw "$n" "$PB_LABEL"
    printf '\n'
    "$@"
  fi
}

note() {  # Message shown above the bar
  if (( PB_ANIM )); then printf '\r\033[K%s\n' "$*" >&3; else printf '%s\n' "$*"; fi
}

pb_done() {  # pb_done <label>
  pb_stop
  if (( PB_ANIM )); then printf '\r\033[K' >&3; fi
  pb_draw "$PB_TOTAL" "$1" >&3
  printf '\n' >&3
  PB_LABEL=""
}

pb_cleanup() {  # Call first in the EXIT trap
  local rc=$?
  pb_stop
  if (( PB_ANIM )); then tput cnorm 2>/dev/null || true; fi
  if (( rc != 0 )) && [[ -n "$PB_LABEL" ]]; then
    printf '\nFAILED: %s\n' "$PB_LABEL" >&2
    if (( PB_ANIM )) && [[ -s "$PB_LOG" ]]; then
      tail -n 20 "$PB_LOG" >&2
      echo "Full log: $PB_LOG" >&2
      return
    fi
  fi
  rm -f "$PB_LOG"
}
LIB
eval "$PROGRESS_LIB"

[[ -d "$CONFIG_DIR" ]] || { echo "Missing $CONFIG_DIR" >&2; exit 1; }
[[ -d "$PACK_DIR" ]] || { echo "Missing $PACK_DIR" >&2; exit 1; }

STAGE="$(mktemp -d)"
trap 'pb_cleanup; rm -rf "$STAGE"' EXIT
BUNDLE="$STAGE/nvim-bundle"
mkdir -p "$BUNDLE"

copy_config() {
  cp -R "$CONFIG_DIR" "$BUNDLE/config"
  if [[ -f "$README" ]]; then cp "$README" "$BUNDLE/nvim.readme.md"; fi
}

copy_plugins() {
  cp -R "$PACK_DIR" "$BUNDLE/pack"
  # markdown-preview's node_modules / binary are platform-specific; the installer fetches a binary
  rm -rf "$BUNDLE"/pack/*/start/markdown-preview.nvim/app/{node_modules,bin}
}

# File names that may hold secrets; never bundled
SENSITIVE_NAMES=(.env '.env.*' '*.pem' '*.key' '*.p12' '*.pfx' 'id_rsa*' 'id_ed25519*' 'id_ecdsa*'
  .netrc .npmrc .pypirc '.git-credentials' 'credentials*' '*.kdbx' '.ssh' '.aws' '.gnupg')

# Content patterns for common secrets (API keys, tokens, private keys, passwords)
SECRET_RE='AKIA[0-9A-Z]{16}|sk-ant-[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9]{32,}|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{20}|xox[abprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{35}|-----BEGIN [A-Z ]*PRIVATE KEY-----|https?://[^/[:space:]:@]+:[^/[:space:]@$<{]+@|(password|passwd|secret|api_?key|access_?token)[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"'[:space:]]{8,}'

strip_sensitive() {
  local args=() n f
  for n in "${SENSITIVE_NAMES[@]}"; do args+=(-o -name "$n"); done
  # Sensitive files/dirs (outside .git internals)
  find "$BUNDLE" -path '*/.git' -prune -o \( "${args[@]:1}" \) -print | while IFS= read -r f; do
    note "Excluded sensitive file: ${f#"$BUNDLE"/}"
    rm -rf "$f"
  done
  # Plugin git metadata: reflogs carry your name/email; config may hold credentials
  find "$BUNDLE" -type d -name .git -prune | while IFS= read -r g; do
    rm -rf "$g/logs"
    git config --file "$g/config" --remove-section user 2>/dev/null || true
    git config --file "$g/config" --remove-section credential 2>/dev/null || true
    { git config --file "$g/config" --get-regexp '^http\..*extraheader$' 2>/dev/null || true; } | cut -d' ' -f1 \
      | while IFS= read -r k; do git config --file "$g/config" --unset-all "$k"; done
    # Drop user:token@ from remote URLs
    { git config --file "$g/config" --get-regexp '^remote\..*\.url$' 2>/dev/null || true; } | while read -r k url; do
      git config --file "$g/config" "$k" "$(printf '%s' "$url" | sed -E 's#://[^/@]+@#://#')"
    done
  done
}

# Fail the export if any bundled text file still looks like it contains a secret
scan_secrets() {
  local hits
  hits="$(grep -rIlE --exclude-dir=objects -e "$SECRET_RE" "$BUNDLE" || true)"
  if [[ -n "$hits" ]]; then
    note "Possible secrets found; export aborted. Review these files:"
    while IFS= read -r f; do note "  ${f#"$BUNDLE"/}"; done <<<"$hits"
    return 1
  fi
}

record_versions() {
  {
    echo "Exported $(date) on $(uname -s) with $(nvim --version | head -1)"
    for d in "$BUNDLE"/pack/*/start/*/; do
      n="$(basename "$d")"
      url="$(git -C "$d" remote get-url origin 2>/dev/null || echo '?')"
      rev="$(git -C "$d" rev-parse --short HEAD 2>/dev/null || echo '?')"
      echo "$n  $url  $rev"
    done
  } > "$BUNDLE/PLUGINS.txt"
}

write_installer() {
  {
    cat <<'HEAD'
#!/usr/bin/env bash
# Install this Neovim bundle. Existing config/plugins are backed up, not deleted.
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
PACK_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/pack"
STAMP="$(date +%Y%m%d-%H%M%S)"

HEAD
    printf '%s\n\n' "$PROGRESS_LIB"
    cat <<'INSTALL'
# True if nvim 0.12+ is on PATH (config uses 0.12 features)
nvim_ok() {
  command -v nvim >/dev/null || return 1
  local major minor
  read -r major minor <<<"$(nvim --version | head -1 | sed -E 's/.*v([0-9]+)\.([0-9]+).*/\1 \2/')"
  (( major > 0 || minor >= 12 ))
}

IS_UBUNTU=0
if [[ -r /etc/os-release ]] && grep -qE '^(ID|ID_LIKE)=.*ubuntu' /etc/os-release; then IS_UBUNTU=1; fi

SUDO_PID=""
stop_sudo_keepalive() { if [[ -n "$SUDO_PID" ]]; then kill "$SUDO_PID" 2>/dev/null || true; fi; }
trap 'pb_cleanup; stop_sudo_keepalive' EXIT

# Ask for the sudo password up front, before the progress bar takes the line
if (( IS_UBUNTU )); then
  echo "Some steps need sudo."
  sudo -v
  ( while sleep 50; do sudo -n true 2>/dev/null || exit; done ) &
  SUDO_PID=$!
fi

install_packages() {
  if (( ! IS_UBUNTU )); then
    note "Not Ubuntu: skipping apt-get"
    return
  fi
  note "Ubuntu detected: installing dependencies with sudo apt-get"
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y git curl fzf ripgrep
}

install_neovim() {
  # apt's neovim is too old; install the official release into /opt
  if (( IS_UBUNTU )) && ! nvim_ok; then
    local arch tmp
    case "$(uname -m)" in
      x86_64) arch=x86_64 ;;
      aarch64|arm64) arch=arm64 ;;
      *) arch="" ;;
    esac
    if [[ -n "$arch" ]]; then
      tmp="$(mktemp -d)"
      curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-$arch.tar.gz" | tar xz -C "$tmp"
      sudo rm -rf "/opt/nvim-linux-$arch"
      sudo mv "$tmp/nvim-linux-$arch" /opt/
      sudo ln -sf "/opt/nvim-linux-$arch/bin/nvim" /usr/local/bin/nvim
      rm -rf "$tmp"
      hash -r
      note "Installed $(/usr/local/bin/nvim --version | head -1) -> /usr/local/bin/nvim"
    else
      note "WARNING: no Neovim release for $(uname -m); install 0.12+ manually."
    fi
  fi
  if ! nvim_ok; then
    note "WARNING: Neovim 0.12+ not found on PATH. Install it (brew install neovim / official release)."
  fi
}

backup_existing() {
  local d
  for d in "$CONFIG_DIR" "$PACK_DIR"; do
    if [[ -e "$d" ]]; then
      mv "$d" "$d.bak-$STAMP"
      note "Backed up $d -> $d.bak-$STAMP"
    fi
  done
}

copy_bundle() {
  mkdir -p "$(dirname "$CONFIG_DIR")" "$(dirname "$PACK_DIR")"
  cp -R "$SRC/config" "$CONFIG_DIR"
  cp -R "$SRC/pack" "$PACK_DIR"
  if [[ -f "$SRC/nvim.readme.md" ]]; then cp "$SRC/nvim.readme.md" "$HOME/nvim.readme.md"; fi
  note "Installed config -> $CONFIG_DIR"
  note "Installed plugins -> $PACK_DIR"
}

build_markdown_preview() {
  # Download the plugin's prebuilt, self-contained binary (no Node.js needed)
  local app
  for app in "$PACK_DIR"/*/start/markdown-preview.nvim/app; do
    [[ -d "$app" ]] || continue
    bash "$app/install.sh" || true  # latest release
    if compgen -G "$app/bin/markdown-preview-*" >/dev/null; then
      note "Installed markdown-preview binary"
    else
      note "WARNING: no markdown-preview binary for $(uname -sm); install Node.js and run 'npx yarn install' in $app"
    fi
  done
}

add_aliases() {
  local rc
  for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    [[ -f "$rc" ]] || continue
    if ! grep -q "alias vim='nvim'" "$rc"; then
      printf "\n# Use Neovim for vim/vi\nalias vim='nvim'\nalias vi='nvim'\n" >> "$rc"
      note "Added vim/vi aliases to $rc"
    fi
  done
}

check_tools() {
  local t missing=()
  for t in git fzf rg; do command -v "$t" >/dev/null || missing+=("$t"); done
  if (( ${#missing[@]} )); then
    note "Tools missing: ${missing[*]} (needed by fzf-lua, Snacks and neo-tree)"
  fi
  if ! command -v claude >/dev/null; then
    note "Claude Code CLI not found; claudecode.nvim needs it (https://claude.com/claude-code)"
  fi
}

pb_init 7
pb_step 0 "Installing system packages" install_packages
pb_step 1 "Checking Neovim" install_neovim
pb_step 2 "Backing up existing config" backup_existing
pb_step 3 "Installing config and plugins" copy_bundle
pb_step 4 "Building markdown-preview" build_markdown_preview
pb_step 5 "Adding vim/vi aliases" add_aliases
pb_step 6 "Checking optional tools" check_tools
pb_done "Done"
echo "Icons need a Nerd Font in your terminal. Cheatsheet: ~/nvim.readme.md"
INSTALL
  } > "$BUNDLE/install.sh"
  chmod +x "$BUNDLE/install.sh"
}

compress() {
  mkdir -p "$OUT_DIR"
  tar -czf "$OUT" -C "$STAGE" nvim-bundle
}

pb_init 7
pb_step 0 "Copying config" copy_config
pb_step 1 "Copying plugins" copy_plugins
pb_step 2 "Removing sensitive data" strip_sensitive
pb_step 3 "Recording plugin versions" record_versions
pb_step 4 "Writing installer" write_installer
pb_step 5 "Scanning for secrets" scan_secrets
pb_step 6 "Compressing bundle" compress
pb_done "Done"
echo "Created $OUT ($(du -h "$OUT" | cut -f1))"
echo "On the target machine:  tar xzf $(basename "$OUT") && ./nvim-bundle/install.sh"
