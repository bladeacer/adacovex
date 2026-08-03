#!/usr/bin/env bash
#
# adacovex -- universal installer
#
# Downloads and installs the adacovex binary (with the `covex` alias) from
# the GitHub Releases of the repository it ships with.  Detects the OS and
# architecture, fetches the matching release bundle, and puts the binary in
# ~/.adacovex/bin (or $ADACOVEX_HOME/bin), adding it to PATH.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/bladeacer/adacovex/main/install.sh | bash
#   bash install.sh                      # latest release
#   bash install.sh v1.4.0               # a specific release tag
#   bash install.sh v1.4.0 /tmp/adacovex # a custom install prefix
#
# Environment:
#   ADACOVEX_HOME   Install prefix (default ~/.adacovex)
#   ADACOVEX_REPO   GitHub repo to fetch from (default bladeacer/adacovex)
#   ADACOVEX_VERSION Release tag to install (default: latest)
#
set -euo pipefail

REPO="${ADACOVEX_REPO:-bladeacer/adacovex}"
VERSION="${1:-${ADACOVEX_VERSION:-latest}}"
PREFIX="${ADACOVEX_HOME:-$HOME/.adacovex}"
BINDIR="$PREFIX/bin"

# --- OS / architecture detection ------------------------------------------
detect_os() {
    case "$(uname -s)" in
        Linux)  echo linux ;;
        Darwin) echo macos ;;
        FreeBSD) echo freebsd ;;
        *) echo "error: unsupported OS: $(uname -s)" >&2; exit 1 ;;
    esac
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo x86_64 ;;
        aarch64|arm64) echo aarch64 ;;
        *) echo "error: unsupported architecture: $(uname -m)" >&2; exit 1 ;;
    esac
}

OS="$(detect_os)"
ARCH="$(detect_arch)"

# --- resolve the release tag ----------------------------------------------
if [ "$VERSION" = "latest" ]; then
    VERSION="$(
        curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
            | grep -oE '"tag_name": *"v[0-9]+\.[0-9]+\.[0-9]+"' \
            | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1
    )" || {
        echo "error: could not resolve latest release for $REPO" >&2
        exit 1
    }
fi

ASSET="adacovex-${VERSION#v}.tar.gz"
URL="https://github.com/$REPO/releases/download/$VERSION/$ASSET"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

echo "adacovex installer: $OS/$ARCH"
echo "  repo:     $REPO"
echo "  version:  $VERSION"
echo "  asset:    $ASSET"
echo "  prefix:   $PREFIX"

mkdir -p "$BINDIR"

echo "  downloading $URL"
curl -fsSL "$URL" -o "$TMPDIR/$ASSET"
tar -xzf "$TMPDIR/$ASSET" -C "$TMPDIR"
cp "$TMPDIR/adacovex" "$BINDIR/adacovex"
chmod +x "$BINDIR/adacovex"
ln -sf adacovex "$BINDIR/covex"

# --- PATH setup ------------------------------------------------------------
if [[ ":$PATH:" != *":$BINDIR:"* ]]; then
    SHELL_RC="${SHELL_RC:-}"
    case "${SHELL:-bash}" in
        *zsh) SHELL_RC="${SHELL_RC:-$HOME/.zshrc}" ;;
        *fish) SHELL_RC="${SHELL_RC:-$HOME/.config/fish/config.fish}" ;;
        *) SHELL_RC="${SHELL_RC:-$HOME/.bashrc}" ;;
    esac
    if [ -f "$SHELL_RC" ]; then
        printf '\n# adacovex\nexport PATH="%s:$PATH"\n' "$BINDIR" >> "$SHELL_RC"
        echo "  added $BINDIR to PATH in $SHELL_RC"
    else
        echo "  PATH entry skipped (no shell rc at $SHELL_RC)"
    fi
    export PATH="$BINDIR:$PATH"
fi

echo ""
echo "Installed:"
echo "  $BINDIR/adacovex"
echo "  $BINDIR/covex -> adacovex"
echo ""
"$BINDIR/adacovex" --help >/dev/null 2>&1 || true
echo "Run 'adacovex --target=/path/to/project' (or 'covex') to assess a project."
