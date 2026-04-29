#!/bin/bash

# Sei Skill Installer for Claude Code
# Usage: ./install.sh [--variant <name>] [--project | --path <path>]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/skill"

# Variant config — full|dev|website|ecosystem
VARIANT="full"
INSTALL_PATH=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --variant)
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
  --variant NAME    Which skill variant to install (default: full)
                    Choices:
                      full       Full Sei skill (covers dev, website, ecosystem)
                                 → installs as ~/.claude/skills/sei
                      dev        Dev-only variant (smart contracts, tooling)
                                 → installs as ~/.claude/skills/sei-dev
                      website    Website variant (frontend stack + site awareness)
                                 → installs as ~/.claude/skills/sei-website
                      ecosystem  Ecosystem variant (apps, integrations, infra)
                                 → installs as ~/.claude/skills/sei-ecosystem
  --project         Install to current project (.claude/skills/<name>)
                    instead of user-level (~/.claude/skills/<name>)
  --path PATH       Install to a custom path (overrides --variant naming)
  -h, --help        Show this help

Examples:
  ./install.sh                          # full skill, user-level
  ./install.sh --variant dev            # dev-only variant
  ./install.sh --variant website --project   # website variant in this project
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

# Determine SKILL.md source + skill name based on variant
case "$VARIANT" in
    full)
        SKILL_NAME="sei"
        VARIANT_FILE="SKILL.md"
        ;;
    dev)
        SKILL_NAME="sei-dev"
        VARIANT_FILE="SKILL-DEV.md"
        ;;
    website)
        SKILL_NAME="sei-website"
        VARIANT_FILE="SKILL-WEBSITE.md"
        ;;
    ecosystem)
        SKILL_NAME="sei-ecosystem"
        VARIANT_FILE="SKILL-ECOSYSTEM.md"
        ;;
    *)
        echo "Error: unknown variant '$VARIANT' — must be one of: full, dev, website, ecosystem"
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
echo "Installing Sei Skill ($VARIANT variant) → $INSTALL_PATH"
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
