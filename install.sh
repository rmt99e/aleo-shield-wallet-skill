#!/usr/bin/env bash
set -euo pipefail

# aleo-dev.skill installer
# Installs the Aleo development skill for Claude Code.

REPO_URL="https://github.com/rmt99e/aleo-dev.skill.git"
SKILL_NAME="aleo-dev.skill"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Install the aleo-dev.skill Claude Code plugin.

Options:
  --global    Install globally (default)
  --local     Install in current directory
  --force     Overwrite existing installation
  -h, --help  Show this help message

Examples:
  curl -fsSL https://raw.githubusercontent.com/rmt99e/aleo-dev.skill/main/install.sh | bash
  ./install.sh --local
  ./install.sh --force
EOF
}

INSTALL_MODE="global"
FORCE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --global) INSTALL_MODE="global"; shift ;;
        --local)  INSTALL_MODE="local"; shift ;;
        --force)  FORCE=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
done

# Check for claude CLI
if ! command -v claude &>/dev/null; then
    echo "Error: 'claude' CLI not found. Install Claude Code first:"
    echo "  https://docs.anthropic.com/en/docs/claude-code"
    exit 1
fi

if [[ "$INSTALL_MODE" == "local" ]]; then
    INSTALL_DIR="./${SKILL_NAME}"
else
    INSTALL_DIR="${HOME}/.claude/plugins/${SKILL_NAME}"
    mkdir -p "$(dirname "$INSTALL_DIR")"
fi

if [[ -d "$INSTALL_DIR" ]]; then
    if [[ "$FORCE" == true ]]; then
        echo "Removing existing installation at ${INSTALL_DIR}..."
        rm -rf "$INSTALL_DIR"
    else
        echo "Error: ${INSTALL_DIR} already exists. Use --force to overwrite."
        exit 1
    fi
fi

echo "Cloning ${SKILL_NAME}..."
git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"

echo "Installing plugin..."
claude plugin add "$INSTALL_DIR"

echo ""
echo "✓ aleo-dev.skill installed successfully!"
echo "  Location: ${INSTALL_DIR}"
echo ""
echo "Start using it:"
echo "  claude"
echo "  > /aleo scaffold a token program"
