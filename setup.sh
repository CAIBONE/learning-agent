#!/usr/bin/env bash
# Intelligent Learning Assistant - OpenClaw Dual Agent Setup Script
# Usage: bash setup.sh
# Sets up both Main Agent and Audit Agent

set -euo pipefail

MAIN_AGENT_ID="intelligent-learning-assistant"
AUDIT_AGENT_ID="intelligent-learning-audit"

MAIN_AGENT_DIR="$HOME/.openclaw/agents/$MAIN_AGENT_ID"
AUDIT_AGENT_DIR="$HOME/.openclaw/agents/$AUDIT_AGENT_ID"

MAIN_WORKSPACE_DIR="$HOME/.openclaw/workspace-$MAIN_AGENT_ID"
AUDIT_WORKSPACE_DIR="$HOME/.openclaw/workspace-$AUDIT_AGENT_ID"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================="
echo " Intelligent Learning Assistant Setup"
echo " Dual Agent Architecture"
echo "========================================="
echo ""
echo "Main Agent:  $MAIN_AGENT_ID"
echo "  Agent Dir: $MAIN_AGENT_DIR"
echo "  Workspace: $MAIN_WORKSPACE_DIR"
echo ""
echo "Audit Agent: $AUDIT_AGENT_ID"
echo "  Agent Dir: $AUDIT_AGENT_DIR"
echo "  Workspace: $AUDIT_WORKSPACE_DIR"
echo ""

# Step 1: Create directories
echo "[1/7] Creating directories..."
mkdir -p "$MAIN_AGENT_DIR/agent"
mkdir -p "$AUDIT_AGENT_DIR/agent"
mkdir -p "$MAIN_WORKSPACE_DIR/skills/learning"
mkdir -p "$MAIN_WORKSPACE_DIR/templates"
mkdir -p "$MAIN_WORKSPACE_DIR/data"
mkdir -p "$AUDIT_WORKSPACE_DIR/skills/learning"

# Step 2: Copy Main Agent files
echo "[2/7] Copying Main Agent files..."
if [ -f "$SCRIPT_DIR/agent/intelligent-learning-assistant/agent.json" ]; then
    cp "$SCRIPT_DIR/agent/intelligent-learning-assistant/agent.json" "$MAIN_AGENT_DIR/agent/agent.json"
    echo "  ✓ agent/intelligent-learning-assistant/agent.json"
fi
if [ -f "$SCRIPT_DIR/agent/intelligent-learning-assistant/SKILL.md" ]; then
    cp "$SCRIPT_DIR/agent/intelligent-learning-assistant/SKILL.md" "$MAIN_AGENT_DIR/agent/SKILL.md"
    echo "  ✓ agent/intelligent-learning-assistant/SKILL.md"
fi

# Step 3: Copy Audit Agent files
echo "[3/7] Copying Audit Agent files..."
if [ -f "$SCRIPT_DIR/agent/intelligent-learning-audit/agent.json" ]; then
    cp "$SCRIPT_DIR/agent/intelligent-learning-audit/agent.json" "$AUDIT_AGENT_DIR/agent/agent.json"
    echo "  ✓ agent/intelligent-learning-audit/agent.json"
fi
if [ -f "$SCRIPT_DIR/agent/intelligent-learning-audit/SKILL.md" ]; then
    cp "$SCRIPT_DIR/agent/intelligent-learning-audit/SKILL.md" "$AUDIT_AGENT_DIR/agent/SKILL.md"
    echo "  ✓ agent/intelligent-learning-audit/SKILL.md"
fi

# Step 4: Copy Main workspace files
echo "[4/7] Copying Main workspace files..."
if [ -f "$SCRIPT_DIR/workspace/intelligent-learning-assistant/IDENTITY.md" ]; then
    cp "$SCRIPT_DIR/workspace/intelligent-learning-assistant/IDENTITY.md" "$MAIN_WORKSPACE_DIR/IDENTITY.md"
    echo "  ✓ IDENTITY.md"
fi
if [ -f "$SCRIPT_DIR/workspace/intelligent-learning-assistant/SOUL.md" ]; then
    cp "$SCRIPT_DIR/workspace/intelligent-learning-assistant/SOUL.md" "$MAIN_WORKSPACE_DIR/SOUL.md"
    echo "  ✓ SOUL.md"
fi

# Step 5: Copy skills
echo "[5/7] Copying skills..."
# Main Agent skills (10 skills)
if [ -d "$SCRIPT_DIR/workspace/intelligent-learning-assistant/skills/learning" ]; then
    for skill_dir in "$SCRIPT_DIR/workspace/intelligent-learning-assistant/skills/learning"/*/; do
        skill_name=$(basename "$skill_dir")
        if [ "$skill_name" != "learning-audit" ]; then
            mkdir -p "$MAIN_WORKSPACE_DIR/skills/learning/$skill_name"
            cp -r "$skill_dir"* "$MAIN_WORKSPACE_DIR/skills/learning/$skill_name/"
        fi
    done
    echo "  ✓ Main Agent: $(ls "$MAIN_WORKSPACE_DIR/skills/learning/" | wc -l) skills"
fi

# Audit Agent skills (1 skill)
if [ -d "$SCRIPT_DIR/workspace/intelligent-learning-audit/skills/learning/learning-audit" ]; then
    mkdir -p "$AUDIT_WORKSPACE_DIR/skills/learning/learning-audit"
    cp -r "$SCRIPT_DIR/workspace/intelligent-learning-audit/skills/learning/learning-audit"/* "$AUDIT_WORKSPACE_DIR/skills/learning/learning-audit/"
    echo "  ✓ Audit Agent: 1 skill (learning-audit)"
fi

# Step 6: Copy templates
echo "[6/7] Copying templates..."
if [ -d "$SCRIPT_DIR/workspace/intelligent-learning-assistant/templates" ]; then
    cp -r "$SCRIPT_DIR/workspace/intelligent-learning-assistant/templates"/* "$MAIN_WORKSPACE_DIR/templates/"
    echo "  ✓ $(ls "$MAIN_WORKSPACE_DIR/templates/" | wc -l) templates"
fi

# Step 7: Register agents with OpenClaw CLI
echo "[7/7] Registering agents..."
if command -v openclaw &>/dev/null; then
    # Register Main Agent
    openclaw agents add "$MAIN_AGENT_ID" \
        --workspace "$MAIN_WORKSPACE_DIR" \
        --agent-dir "$MAIN_AGENT_DIR/agent" \
        --non-interactive --json 2>/dev/null || true
    echo "  ✓ Main Agent registered"

    # Register Audit Agent
    openclaw agents add "$AUDIT_AGENT_ID" \
        --workspace "$AUDIT_WORKSPACE_DIR" \
        --agent-dir "$AUDIT_AGENT_DIR/agent" \
        --non-interactive --json 2>/dev/null || true
    echo "  ✓ Audit Agent registered"
else
    echo "  ⚠ openclaw CLI not found, please register manually:"
    echo "    openclaw agents add $MAIN_AGENT_ID --workspace $MAIN_WORKSPACE_DIR --agent-dir $MAIN_AGENT_DIR/agent"
    echo "    openclaw agents add $AUDIT_AGENT_ID --workspace $AUDIT_WORKSPACE_DIR --agent-dir $AUDIT_AGENT_DIR/agent"
fi

echo ""
echo "========================================="
echo " Setup Complete!"
echo "========================================="
echo ""
echo "Architecture:"
echo "  Main Agent (学吧) → 10 skills → generates content"
echo "       ↓ sessions_send (sync)"
echo "  Audit Agent (审计官) → 1 skill → audits quality"
echo ""
echo "Next steps:"
echo "1. Merge openclaw-config-patch.json into ~/.openclaw/openclaw.json"
echo "   (contains both agents, bindings, channels config)"
echo "2. Replace YOUR_APP_ID and YOUR_APP_SECRET with actual Feishu credentials"
echo "3. Configure model (must be a reasoning/thinking model):"
echo "   Check available reasoning models: openclaw models list | grep reasoning"
echo "   Set in openclaw.json: agents.list[].model.primary = \"<reasoning-model-id>\""
echo "   Example: glm-5.2, bailian-thinking/qwen3.7-plus, etc."
echo "4. Restart gateway:"
echo "   openclaw gateway restart"
echo ""
echo "📋 Feishu scopes: workspace/intelligent-learning-assistant/templates/feishu-scopes.json"
echo "🤖 AI tool deploy prompt: docs/DEPLOY-PROMPT.md"
echo ""
