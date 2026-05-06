#!/bin/bash

# Sei Skill Installer
# Default (no flags): installs the full skill for Claude Code.
# Use --agent <name> or --flatten to output a single markdown file for other AI agents.
#
# Usage: ./install.sh [--variant <name>|--name <name>] [--agent <name>]
#                     [--flatten] [--output <path>] [--project | --path <path>]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/skill"

VARIANT=""
INSTALL_PATH=""
INSTALL_PATH_TYPE=""
FLATTEN=false
OUTPUT_PATH=""
AGENT=""
AGENT_FRONTMATTER=""
AGENT_POST_MSG=""
AGENT_SIZE_WARN=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --variant|--name)
            VARIANT="$2"
            shift 2
            ;;
        --agent)
            AGENT="$2"
            FLATTEN=true
            shift 2
            ;;
        --flatten)
            FLATTEN=true
            shift
            ;;
        --output)
            OUTPUT_PATH="$2"
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
                      full       | sei              — all three domains
                      contracts  | sei-contracts    — smart contracts and tooling
                      frontend   | sei-frontend     — UI stack and site awareness
                      ecosystem  | sei-ecosystem    — apps, integrations, infra

  --agent NAME      Install for a specific AI agent. Implies --flatten and sets
                    the correct output path and formatting automatically.

                    Supported agents:
                      cursor      → .cursor/rules/<skill>.mdc  (MDC frontmatter)
                      copilot     → .github/copilot-instructions.md
                      windsurf    → .windsurf/rules/<skill>.md
                      aider       → ~/.aider/<skill>.md  (+ config instructions)
                      openhands   → .openhands/SKILL.md  (YAML frontmatter)
                      codex       → AGENTS.md
                      gemini      → GEMINI.md

  --flatten         Output a single flat markdown file without agent-specific
                    formatting. Use --output to set the path.

  --output PATH     Override the default output path. Only valid with --agent
                    or --flatten.

  --project         (Claude Code) Install to .claude/skills/<name> in the
                    current project instead of ~/.claude/skills/<name>
  --path PATH       (Claude Code) Install to a custom path
  -h, --help        Show this help

Examples:
  # Claude Code (default)
  ./install.sh
  ./install.sh --variant contracts
  ./install.sh --variant ecosystem --project

  # Specific agents
  ./install.sh --agent cursor
  ./install.sh --agent cursor --variant contracts
  ./install.sh --agent copilot
  ./install.sh --agent codex --output ~/.codex/AGENTS.md

  # Generic flat file
  ./install.sh --flatten --output ./sei-context.md
  ./install.sh --flatten --variant frontend --output ./sei-context.md
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

# Validate flag combinations
if [ -n "$AGENT" ] && { [ "$INSTALL_PATH_TYPE" = "project" ] || [ -n "$INSTALL_PATH" ]; }; then
    echo "Error: --agent cannot be combined with --project or --path"
    echo "Use --output to override the output path for agent installs."
    exit 1
fi

if [ -n "$OUTPUT_PATH" ] && [ "$FLATTEN" = false ]; then
    echo "Error: --output is only valid with --agent or --flatten"
    exit 1
fi

# Default to full when nothing was specified
if [ -z "$VARIANT" ]; then
    VARIANT="full"
    USING_DEFAULT="yes"
fi

# Resolve variant
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

# Validate source
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory '$SOURCE_DIR' not found"
    exit 1
fi

if [ ! -f "$SOURCE_DIR/$VARIANT_FILE" ]; then
    echo "Error: '$VARIANT_FILE' not found in '$SOURCE_DIR'"
    exit 1
fi

# ── Resolve agent-specific settings ──────────────────────────────────────────

if [ -n "$AGENT" ]; then
    case "$AGENT" in
        cursor)
            AGENT_DEFAULT_OUTPUT=".cursor/rules/${SKILL_NAME}.mdc"
            case "$VARIANT" in
                contracts) CURSOR_DESC="Sei Network smart contract development — EVM, precompiles, tooling" ;;
                frontend)  CURSOR_DESC="Sei Network frontend development — Wagmi, Viem, sei-js, wallets" ;;
                ecosystem) CURSOR_DESC="Sei Network ecosystem — dApps, bridges, oracles, node operations" ;;
                *)         CURSOR_DESC="Sei Network development — smart contracts, frontend, and ecosystem" ;;
            esac
            AGENT_FRONTMATTER="---
description: ${CURSOR_DESC}
globs:
alwaysApply: true
---

"
            AGENT_SIZE_WARN="Warning: Cursor recommends ≤500 lines for always-apply rules. This file is larger — consider using a focused --variant (contracts, frontend, or ecosystem) to reduce context size."
            ;;
        copilot)
            AGENT_DEFAULT_OUTPUT=".github/copilot-instructions.md"
            AGENT_SIZE_WARN="Note: GitHub Copilot works best with ≤1,000 lines. Consider using a focused --variant."
            ;;
        windsurf)
            AGENT_DEFAULT_OUTPUT=".windsurf/rules/${SKILL_NAME}.md"
            ;;
        aider)
            AGENT_DEFAULT_OUTPUT="$HOME/.aider/${SKILL_NAME}.md"
            AGENT_POST_MSG="To load this file automatically, add the following to ~/.aider.conf.yml:
  read:
    - $HOME/.aider/${SKILL_NAME}.md"
            ;;
        openhands)
            AGENT_DEFAULT_OUTPUT=".openhands/SKILL.md"
            AGENT_FRONTMATTER="---
name: ${SKILL_NAME}
description: Sei Network development knowledge — smart contracts, precompiles, frontend, and ecosystem integrations
---

"
            ;;
        codex)
            AGENT_DEFAULT_OUTPUT="AGENTS.md"
            AGENT_SIZE_WARN="Warning: Codex CLI has a 32 KiB total limit across all AGENTS.md files. This file exceeds that — consider using a focused --variant (contracts, frontend, or ecosystem)."
            ;;
        gemini)
            AGENT_DEFAULT_OUTPUT="GEMINI.md"
            ;;
        *)
            echo "Error: unknown agent '$AGENT'"
            echo "Supported agents: cursor, copilot, windsurf, aider, openhands, codex, gemini"
            echo "Run with --help for details."
            exit 1
            ;;
    esac

    if [ -z "$OUTPUT_PATH" ]; then
        OUTPUT_PATH="$AGENT_DEFAULT_OUTPUT"
    fi
fi

# ── Flatten mode (other AI agents) ───────────────────────────────────────────

if [ "$FLATTEN" = true ]; then
    if [ -z "$OUTPUT_PATH" ]; then
        OUTPUT_PATH="./${SKILL_NAME}.md"
    fi

    if [ -n "$AGENT" ]; then
        echo "Installing Sei Skill ($VARIANT) for $AGENT → $OUTPUT_PATH"
    else
        echo "Flattening Sei Skill ($VARIANT) → $OUTPUT_PATH"
    fi

    # Create output directory if needed
    mkdir -p "$(dirname "$OUTPUT_PATH")"

    # Extract reference paths directly from the variant SKILL.md so the list
    # stays in sync automatically when new reference files are added.
    REFS=()
    while IFS= read -r ref; do
        [ -n "$ref" ] && REFS+=("$ref")
    done < <(grep -Eo 'references/[^)"[:space:]]+\.md' "$SOURCE_DIR/$VARIANT_FILE" | sort -u)

    # Write agent frontmatter if applicable, then SKILL.md with YAML frontmatter stripped
    if [ -n "$AGENT_FRONTMATTER" ]; then
        printf '%s' "$AGENT_FRONTMATTER" > "$OUTPUT_PATH"
        awk 'BEGIN{n=0} /^---$/{n++; if(n==2){found=1; next}} found{print}' \
            "$SOURCE_DIR/$VARIANT_FILE" >> "$OUTPUT_PATH"
    else
        awk 'BEGIN{n=0} /^---$/{n++; if(n==2){found=1; next}} found{print}' \
            "$SOURCE_DIR/$VARIANT_FILE" > "$OUTPUT_PATH"
    fi

    # Append each reference file with a separator
    for ref in "${REFS[@]}"; do
        ref_path="$SOURCE_DIR/$ref"
        if [ -f "$ref_path" ]; then
            printf '\n\n---\n\n' >> "$OUTPUT_PATH"
            cat "$ref_path" >> "$OUTPUT_PATH"
        fi
    done

    FILE_SIZE=$(wc -c < "$OUTPUT_PATH" | tr -d ' ')
    FILE_LINES=$(wc -l < "$OUTPUT_PATH" | tr -d ' ')

    echo ""
    echo "Successfully wrote: $OUTPUT_PATH ($FILE_LINES lines, $FILE_SIZE bytes)"
    echo ""
    echo "Reference files included (${#REFS[@]}):"
    for ref in "${REFS[@]}"; do
        echo "  - $ref"
    done

    if [ -n "$AGENT_SIZE_WARN" ]; then
        echo ""
        echo "$AGENT_SIZE_WARN"
    fi

    if [ -n "$AGENT_POST_MSG" ]; then
        echo ""
        echo "$AGENT_POST_MSG"
    fi

    exit 0
fi

# ── Claude Code install mode ──────────────────────────────────────────────────

# Resolve install path
if [ -z "$INSTALL_PATH" ]; then
    if [ "$INSTALL_PATH_TYPE" = "project" ]; then
        INSTALL_PATH=".claude/skills/$SKILL_NAME"
    else
        INSTALL_PATH="$HOME/.claude/skills/$SKILL_NAME"
    fi
fi

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

# Copy skill files
if [ "$USING_DEFAULT" = "yes" ]; then
    echo "Installing Sei Skill (full — default) → $INSTALL_PATH"
else
    echo "Installing Sei Skill ($VARIANT variant) → $INSTALL_PATH"
fi
cp -r "$SOURCE_DIR" "$INSTALL_PATH"

# Replace SKILL.md with the variant entry point if not the full install
if [ "$VARIANT_FILE" != "SKILL.md" ]; then
    cp "$SOURCE_DIR/$VARIANT_FILE" "$INSTALL_PATH/SKILL.md"
fi

# Strip unused variant SKILL-*.md files from the install destination
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
