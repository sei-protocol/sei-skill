#!/bin/bash

# Sei Skill Installer for Claude Code
# Defaults to the full skill when no --variant / --name is given.
# Usage: ./install.sh [--variant <name>|--name <name>] [--project | --path <path>]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/skill"

# Variant config — full (default) | contracts | frontend | ecosystem
# Aliases also accepted for the actual skill names: sei, sei-contracts, sei-frontend, sei-ecosystem
VARIANT=""        # empty = use default; resolved to "full" below
INSTALL_PATH=""
INSTALL_PATH_TYPE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --variant|--name)
            VARIANT="$2"
            shift 2
            ;;
        --project)
            INSTALL_PATH_TYPE="project"
            shift
            ;;
        --path)
            INSTALL_PATH="$2"
            shift 2
            ;;
        -h|--help)
            cat <<EOF
Sei Skill Installer

Usage: ./install.sh [OPTIONS]

Options:
  --variant NAME    Which skill variant to install. Default: full.
  --name NAME       Alias for --variant. Accepts the actual skill name.

                    Accepted values (short and full names are interchangeable):
                      full       | sei              → ~/.claude/skills/sei
                                 (covers contracts, frontend, ecosystem)
                      contracts  | sei-contracts    → ~/.claude/skills/sei-contracts
                                 (smart contracts, tooling)
                      frontend   | sei-frontend     → ~/.claude/skills/sei-frontend
                                 (UI stack + site awareness)
                      ecosystem  | sei-ecosystem    → ~/.claude/skills/sei-ecosystem
                                 (apps, integrations, infra)

  --project         Install to current project (.claude/skills/<name>)
                    instead of user-level (~/.claude/skills/<name>)
  --path PATH       Install to a custom path (overrides --variant naming)
  -h, --help        Show this help

Examples:
  ./install.sh                          # full skill (default)
  ./install.sh --variant contracts      # contracts-only variant
  ./install.sh --name sei-frontend      # frontend variant by skill name
  ./install.sh --variant ecosystem --project   # in current project's .claude/
  ./install.sh --path /tmp/sei-test     # custom location
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Default to full when nothing was specified
if [ -z "$VARIANT" ]; then
    VARIANT="full"
    USING_DEFAULT="yes"
fi

# Normalise variant input (accept both short alias and full skill name)
case "$VARIANT" in
    full|sei)
        VARIANT="full"
        SKILL_NAME="sei"
        VARIANT_FILE="SKILL.md"
        ;;
    contracts|sei-contracts)
        VARIANT="contracts"
        SKILL_NAME="sei-contracts"
        VARIANT_FILE="SKILL-CONTRACTS.md"
        ;;
    frontend|sei-frontend)
        VARIANT="frontend"
        SKILL_NAME="sei-frontend"
        VARIANT_FILE="SKILL-FRONTEND.md"
        ;;
    ecosystem|sei-ecosystem)
        VARIANT="ecosystem"
        SKILL_NAME="sei-ecosystem"
        VARIANT_FILE="SKILL-ECOSYSTEM.md"
        ;;
    *)
        echo "Error: unknown variant/name '$VARIANT'"
        echo "Accepted values: full|sei, contracts|sei-contracts, frontend|sei-frontend, ecosystem|sei-ecosystem"
        echo "Run with --help for details."
        exit 1
        ;;
esac

# Resolve install path if not explicitly set
if [ -z "$INSTALL_PATH" ]; then
    if [ "$INSTALL_PATH_TYPE" = "project" ]; then
        INSTALL_PATH=".claude/skills/$SKILL_NAME"
    else
        INSTALL_PATH="$HOME/.claude/skills/$SKILL_NAME"
    fi
fi

# Check source dir + variant SKILL.md exist
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory '$SOURCE_DIR' not found"
    exit 1
fi

if [ ! -f "$SOURCE_DIR/$VARIANT_FILE" ]; then
    echo "Error: '$VARIANT_FILE' not found in '$SOURCE_DIR'"
    exit 1
fi

# Create parent directory if needed
mkdir -p "$(dirname "$INSTALL_PATH")"

# Confirm overwrite if destination exists
if [ -d "$INSTALL_PATH" ]; then
    echo "Warning: '$INSTALL_PATH' already exists"
    read -p "Overwrite? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi
    rm -rf "$INSTALL_PATH"
fi

# Copy skill files (whole tree, then swap in variant SKILL.md if needed)
if [ "$USING_DEFAULT" = "yes" ]; then
    echo "Installing Sei Skill (full — default) → $INSTALL_PATH"
else
    echo "Installing Sei Skill ($VARIANT variant) → $INSTALL_PATH"
fi
cp -r "$SOURCE_DIR" "$INSTALL_PATH"

# Replace SKILL.md with the variant if not the full install
if [ "$VARIANT_FILE" != "SKILL.md" ]; then
    cp "$SOURCE_DIR/$VARIANT_FILE" "$INSTALL_PATH/SKILL.md"
fi

# Strip the unused variant SKILL-*.md files from the install (keep SKILL.md only)
find "$INSTALL_PATH" -maxdepth 1 -name 'SKILL-*.md' -delete

echo ""
echo "Successfully installed '$SKILL_NAME' to: $INSTALL_PATH"
echo ""
echo "Installed reference files:"
find "$INSTALL_PATH/references" -type f -name "*.md" | sort | while read -r file; do
    echo "  - ${file#$INSTALL_PATH/}"
done
echo ""
echo "The skill is now available in Claude Code."
echo "Try asking about Sei to activate it!"
