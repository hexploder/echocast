#!/usr/bin/env bash
#
# Echocast guided installer.
#
# Works two ways:
#   curl -fsSL https://raw.githubusercontent.com/hexploder/echocast/main/install.sh | bash
#   (or) clone the repo and run ./install.sh from inside it
#
# Either way it: installs the `echocast` CLI, installs the Omarchy bar
# widget (if this machine has one), asks whether this machine is the
# server or the client, and walks through the rest interactively.
set -euo pipefail

REPO_URL="https://github.com/hexploder/echocast.git"
RAW_URL="https://raw.githubusercontent.com/hexploder/echocast/main"
BIN_DIR="$HOME/.local/bin"
SYSTEMD_DIR="$HOME/.config/systemd/user"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/io.github.hexploder.echocast"

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# ---- locate the source files (local checkout, or a fresh temp clone) -----

SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ]; then
  candidate="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
  [ -f "$candidate/echocast" ] && SCRIPT_DIR="$candidate"
fi

CLEANUP_DIR=""
if [ -z "$SCRIPT_DIR" ]; then
  say "Fetching Echocast..."
  command -v git >/dev/null 2>&1 || die "git is required (or run this from inside a clone of the repo)"
  CLEANUP_DIR="$(mktemp -d)"
  git clone --depth 1 -q "$REPO_URL" "$CLEANUP_DIR" || die "couldn't clone $REPO_URL"
  SCRIPT_DIR="$CLEANUP_DIR"
  trap 'rm -rf "$CLEANUP_DIR"' EXIT
fi

# ---- dependency check -----------------------------------------------------

missing=()
for cmd in jq pactl paplay parecord ssh ssh-keygen; do
  command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done
if [ "${#missing[@]}" -gt 0 ]; then
  die "missing dependencies: ${missing[*]} (Echocast needs PipeWire/PulseAudio tools, jq, and OpenSSH)"
fi

# ---- install the CLI -------------------------------------------------------

mkdir -p "$BIN_DIR"
cp "$SCRIPT_DIR/echocast" "$BIN_DIR/echocast"
chmod +x "$BIN_DIR/echocast"
say "Installed $BIN_DIR/echocast"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) warn "$BIN_DIR isn't on your PATH yet — add it to your shell profile, then re-open your terminal." ;;
esac

# ---- install the Omarchy bar widget, if this looks like an Omarchy box ----

if [ -d "$HOME/.config/omarchy" ]; then
  mkdir -p "$PLUGIN_DIR"
  cp "$SCRIPT_DIR/manifest.json" "$SCRIPT_DIR/Service.qml" "$SCRIPT_DIR/BarWidget.qml" "$SCRIPT_DIR/Panel.qml" "$PLUGIN_DIR/"
  say "Installed the bar widget to $PLUGIN_DIR"
  say "Add it to your bar with: omarchy-shell shell toggle omarchy.menu '{}' (Settings → Bar), or add"
  say '  {"id": "io.github.hexploder.echocast"}'
  say "to a section of bar.layout in ~/.config/omarchy/shell.json, then: omarchy-restart-shell"
else
  warn "No ~/.config/omarchy found — skipping the bar widget, installing the CLI only."
fi

# ---- role ------------------------------------------------------------------

echo
say "Is THIS machine the one with the speakers you want sound to come out of?"
echo "  1) server — this machine has the speakers"
echo "  2) client — this machine sends its audio elsewhere"
read -r -p "Choice [1/2]: " choice
echo

case "$choice" in
  1)
    "$BIN_DIR/echocast" set-role server
    "$BIN_DIR/echocast" server-set-enabled false
    "$BIN_DIR/echocast" server-set-device default
    say "Server configured (starts switched off)."
    echo
    echo "Once you've installed the client on another machine, it will print a"
    echo "public key. Register it here with:"
    echo
    echo "    echocast add-client <a-name-for-that-machine> \"<its public key>\""
    echo
    echo "Then flip it on — from the bar widget, or:"
    echo "    echocast server-set-enabled true"
    ;;
  2)
    "$BIN_DIR/echocast" set-role client
    mkdir -p "$SYSTEMD_DIR"
    cp "$SCRIPT_DIR/echocast-client.service" "$SYSTEMD_DIR/"
    systemctl --user daemon-reload
    read -r -p "Server address, as user@host (e.g. alice@192.168.1.50): " addr
    "$BIN_DIR/echocast" client-set-server "$addr"
    "$BIN_DIR/echocast" client-set-enabled false
    systemctl --user enable --now echocast-client.service
    pubkey="$("$BIN_DIR/echocast" init-keys)"
    say "Client service installed and running (starts switched off)."
    echo
    echo "Go to the SERVER machine and register this one:"
    echo
    echo "    echocast add-client $(hostname) \"$pubkey\""
    echo
    read -r -p "Press Enter once that's done to turn passthrough on now (Ctrl-C to leave it off for now): " _
    "$BIN_DIR/echocast" client-set-enabled true
    say "Passthrough enabled."
    ;;
  *)
    warn "Not 1 or 2 — skipping role setup. Run 'echocast set-role server' or 'echocast set-role client' yourself, and see the README for the rest."
    ;;
esac

echo
say "Done. If you installed the bar widget, click its icon to check status or change settings any time."
