#!/usr/bin/env bash
# Intelligent Learning Assistant - OpenClaw Agent Setup Script
# Usage: bash setup.sh [agent-id]
# Default agent-id: intelligent-learning-assistant

set -euo pipefail

AGENT_ID="${1:-intelligent-learning-assistant}"
AGENT_DIR="$HOME/.openclaw/agents/$AGENT_ID"
WORKSPACE_DIR="$HOME/.openclaw/workspace-$AGENT_ID"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================="
echo " Intelligent Learning Assistant Setup"
echo "========================================="
echo ""
echo "Agent ID:    $AGENT_ID"
echo "Agent Dir:   $AGENT_DIR"
echo "Workspace:   $WORKSPACE_DIR"
echo ""

# Step 1: Create directories
echo "[1/6] Creating directories..."
mkdir -p "$AGENT_DIR/agent"
mkdir -p "$WORKSPACE_DIR/skills/learning"
mkdir -p "$WORKSPACE_DIR/templates"
mkdir -p "$WORKSPACE_DIR/knowledge-trees"
mkdir -p "$WORKSPACE_DIR/learning-profiles"
mkdir -p "$WORKSPACE_DIR/progress"
mkdir -p "$WORKSPACE_DIR/memory"
mkdir -p "$WORKSPACE_DIR/artifacts"

# Step 2: Copy agent files
echo "[2/6] Copying agent files..."
if [ -f "$SCRIPT_DIR/agent/agent.json" ]; then
    cp "$SCRIPT_DIR/agent/agent.json" "$AGENT_DIR/agent/agent.json"
    echo "  ✓ agent.json"
fi
if [ -f "$SCRIPT_DIR/agent/SKILL.md" ]; then
    cp "$SCRIPT_DIR/agent/SKILL.md" "$AGENT_DIR/agent/SKILL.md"
    echo "  ✓ SKILL.md"
fi

# Step 3: Copy workspace files
echo "[3/6] Copying workspace files..."
if [ -f "$SCRIPT_DIR/workspace/IDENTITY.md" ]; then
    cp "$SCRIPT_DIR/workspace/IDENTITY.md" "$WORKSPACE_DIR/IDENTITY.md"
    echo "  ✓ IDENTITY.md"
fi
if [ -f "$SCRIPT_DIR/workspace/SOUL.md" ]; then
    cp "$SCRIPT_DIR/workspace/SOUL.md" "$WORKSPACE_DIR/SOUL.md"
    echo "  ✓ SOUL.md"
fi

# Step 4: Copy skills
echo "[4/6] Copying skills..."
if [ -d "$SCRIPT_DIR/workspace/skills/learning" ]; then
    cp -r "$SCRIPT_DIR/workspace/skills/learning"/* "$WORKSPACE_DIR/skills/learning/"
    echo "  ✓ $(ls "$WORKSPACE_DIR/skills/learning/" | wc -l) skills copied"
fi

# Step 5: Copy templates
echo "[5/6] Copying templates..."
if [ -d "$SCRIPT_DIR/workspace/templates" ]; then
    cp -r "$SCRIPT_DIR/workspace/templates"/* "$WORKSPACE_DIR/templates/"
    echo "  ✓ $(ls "$WORKSPACE_DIR/templates/" | wc -l) templates copied"
fi

# Step 6: Register agent with OpenClaw CLI
echo "[6/6] Registering agent..."
if command -v openclaw &>/dev/null; then
    openclaw agents add "$AGENT_ID" \
        --workspace "$WORKSPACE_DIR" \
        --agent-dir "$AGENT_DIR/agent" \
        --non-interactive --json 2>/dev/null || true
    echo "  ✓ Agent registered"
else
    echo "  ⚠ openclaw CLI not found, please register manually"
    echo "    openclaw agents add $AGENT_ID --workspace $WORKSPACE_DIR --agent-dir $AGENT_DIR/agent"
fi

echo ""
echo "========================================="
echo " Setup Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Add feishu channel account in openclaw.json:"
echo '   channels.feishu.accounts.intelligent-learning = { appId, appSecret, enabled: true, streaming: true }'
echo "   ⚡ streaming: true — 开启流式输出，用户实时看到 Agent 回复"
echo "2. Add binding:"
echo "   bindings: [{ agentId: '$AGENT_ID', match: { channel: 'feishu', accountId: 'intelligent-learning' } }]"
echo "3. Configure model (recommended: thinking/reasoning model):"
echo "   agents.list[].model.primary = \"bailian-thinking/qwen3.7-plus\""
echo "   学吧需要深度推理能力（知识图谱审计、题目验证、内容交叉验证等），强烈推荐使用推理模型"
echo "4. Restart gateway:"
echo "   openclaw gateway restart"
echo "5. (Optional) Initialize Feishu sync:"
echo "   In chat, ask the agent to '初始化飞书同步' to set up"
echo "   knowledge base and bitable database."
echo ""
echo "📋 Full scope list: workspace/templates/feishu-scopes.json (180+ permissions)"
echo "🤖 AI tool deploy prompt: docs/DEPLOY-PROMPT.md"
echo ""