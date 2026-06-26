#!/usr/bin/env bash
# Intelligent Learning Assistant - OpenClaw Dual Agent Setup Script
# Usage: bash setup.sh
# Sets up both Main Agent and Audit Agent, merges config, and restarts gateway

set -euo pipefail

MAIN_AGENT_ID="intelligent-learning-assistant"
AUDIT_AGENT_ID="intelligent-learning-audit"

MAIN_AGENT_DIR="$HOME/.openclaw/agents/$MAIN_AGENT_ID"
AUDIT_AGENT_DIR="$HOME/.openclaw/agents/$AUDIT_AGENT_ID"

MAIN_WORKSPACE_DIR="$HOME/.openclaw/workspace-$MAIN_AGENT_ID"
AUDIT_WORKSPACE_DIR="$HOME/.openclaw/workspace-$AUDIT_AGENT_ID"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$HOME/.openclaw/openclaw.json"

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
echo "[1/9] Creating directories..."
mkdir -p "$MAIN_AGENT_DIR/agent"
mkdir -p "$AUDIT_AGENT_DIR/agent"
mkdir -p "$MAIN_WORKSPACE_DIR/skills/learning"
mkdir -p "$MAIN_WORKSPACE_DIR/templates"
mkdir -p "$MAIN_WORKSPACE_DIR/data"
mkdir -p "$AUDIT_WORKSPACE_DIR/skills/learning"

# Step 2: Copy Main Agent files
echo "[2/9] Copying Main Agent files..."
if [ -f "$SCRIPT_DIR/agent/intelligent-learning-assistant/agent.json" ]; then
    cp "$SCRIPT_DIR/agent/intelligent-learning-assistant/agent.json" "$MAIN_AGENT_DIR/agent/agent.json"
    echo "  ✓ agent/intelligent-learning-assistant/agent.json"
fi
if [ -f "$SCRIPT_DIR/agent/intelligent-learning-assistant/SKILL.md" ]; then
    cp "$SCRIPT_DIR/agent/intelligent-learning-assistant/SKILL.md" "$MAIN_AGENT_DIR/agent/SKILL.md"
    echo "  ✓ agent/intelligent-learning-assistant/SKILL.md"
fi

# Step 3: Copy Audit Agent files
echo "[3/9] Copying Audit Agent files..."
if [ -f "$SCRIPT_DIR/agent/intelligent-learning-audit/agent.json" ]; then
    cp "$SCRIPT_DIR/agent/intelligent-learning-audit/agent.json" "$AUDIT_AGENT_DIR/agent/agent.json"
    echo "  ✓ agent/intelligent-learning-audit/agent.json"
fi
if [ -f "$SCRIPT_DIR/agent/intelligent-learning-audit/SKILL.md" ]; then
    cp "$SCRIPT_DIR/agent/intelligent-learning-audit/SKILL.md" "$AUDIT_AGENT_DIR/agent/SKILL.md"
    echo "  ✓ agent/intelligent-learning-audit/SKILL.md"
fi

# Step 3b: Fix agent.json workspace paths to absolute
echo "[3b/9] Fixing agent.json workspace paths..."
python3 -c "
import json
for agent_id, ws_dir in [
    ('$MAIN_AGENT_ID', '$MAIN_WORKSPACE_DIR'),
    ('$AUDIT_AGENT_ID', '$AUDIT_WORKSPACE_DIR')
]:
    path = f'$HOME/.openclaw/agents/{agent_id}/agent/agent.json'
    with open(path) as f:
        d = json.load(f)
    d['workspace'] = ws_dir
    with open(path, 'w') as f:
        json.dump(d, f, indent=2, ensure_ascii=False)
    print(f'  ✓ {agent_id}: workspace={ws_dir}')
"

# Step 4: Copy Main workspace files
echo "[4/9] Copying Main workspace files..."
for f in AGENTS.md IDENTITY.md README.md SOUL.md; do
    if [ -f "$SCRIPT_DIR/workspace/intelligent-learning-assistant/$f" ]; then
        cp "$SCRIPT_DIR/workspace/intelligent-learning-assistant/$f" "$MAIN_WORKSPACE_DIR/$f"
        echo "  ✓ $f"
    fi
done

# Step 4b: Copy Audit workspace files
echo "[4b/9] Copying Audit workspace files..."
for f in AGENTS.md IDENTITY.md SOUL.md; do
    if [ -f "$SCRIPT_DIR/workspace/intelligent-learning-audit/$f" ]; then
        cp "$SCRIPT_DIR/workspace/intelligent-learning-audit/$f" "$AUDIT_WORKSPACE_DIR/$f"
        echo "  ✓ $f"
    fi
done

# Step 5: Copy skills
echo "[5/9] Copying skills..."
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
echo "[6/9] Copying templates..."
if [ -d "$SCRIPT_DIR/workspace/intelligent-learning-assistant/templates" ]; then
    cp -r "$SCRIPT_DIR/workspace/intelligent-learning-assistant/templates"/* "$MAIN_WORKSPACE_DIR/templates/"
    echo "  ✓ $(ls "$MAIN_WORKSPACE_DIR/templates/" | wc -l) templates"
fi

# Step 7: Register agents with OpenClaw CLI
echo "[7/9] Registering agents..."
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

# Step 8: Merge config into openclaw.json
echo "[8/9] Merging config into openclaw.json..."
python3 << 'PYEOF'
import json, os, sys

CONFIG = os.path.expanduser('~/.openclaw/openclaw.json')
if not os.path.exists(CONFIG):
    print("  ⚠ openclaw.json not found, skipping config merge")
    sys.exit(0)

with open(CONFIG) as f:
    c = json.load(f)

# --- Preserve existing Feishu credentials ---
existing_creds = {}
for name, acc in c.get('channels',{}).get('feishu',{}).get('accounts',{}).items():
    if acc.get('appId') and acc['appId'] not in ('YOUR_APP_ID', ''):
        existing_creds[name] = {'appId': acc['appId'], 'appSecret': acc['appSecret']}

# --- Remove old study-assistant channel/binding if present ---
if 'study-assistant' in c.get('channels',{}).get('feishu',{}).get('accounts',{}):
    del c['channels']['feishu']['accounts']['study-assistant']
    print("  ✓ Removed study-assistant channel")
c['bindings'] = [b for b in c.get('bindings', [])
                  if b.get('match',{}).get('accountId') != 'study-assistant']

# --- Agent definitions (tools: alsoAllow only, NO subagents) ---
MAIN_ALSO_ALLOW = [
    "sessions_send","cron_create","cron_update","cron_delete","cron_list",
    "web_search","web_fetch",
    "feishu_bitable_app","feishu_bitable_app_table",
    "feishu_bitable_app_table_field","feishu_bitable_app_table_record",
    "feishu_bitable_app_table_view",
    "feishu_calendar_calendar","feishu_calendar_event",
    "feishu_calendar_event_attendee","feishu_calendar_freebusy",
    "feishu_chat","feishu_chat_members",
    "feishu_create_doc","feishu_doc_comments","feishu_doc_media",
    "feishu_drive_file","feishu_fetch_doc","feishu_get_user",
    "feishu_im_bot_image","feishu_im_user_fetch_resource",
    "feishu_im_user_get_messages","feishu_im_user_get_thread_messages",
    "feishu_im_user_message","feishu_im_user_search_messages",
    "feishu_oauth","feishu_oauth_batch_auth",
    "feishu_search_doc_wiki","feishu_search_user",
    "feishu_sheet","feishu_task_comment","feishu_task_subtask",
    "feishu_task_task","feishu_task_tasklist",
    "feishu_update_doc","feishu_wiki_space","feishu_wiki_space_node"
]

HOME = os.path.expanduser('~')
patch_agents = {
    "intelligent-learning-assistant": {
        "id": "intelligent-learning-assistant",
        "name": "学吧",
        "workspace": f"{HOME}/.openclaw/workspace-intelligent-learning-assistant",
        "agentDir": f"{HOME}/.openclaw/agents/intelligent-learning-assistant/agent",
        "skills": ["learning-core","learning-goals","learning-knowledge-tree",
                   "learning-plan","learning-content","learning-quiz",
                   "learning-reports","learning-review","learning-cron","learning-feishu-sync"],
        "tools": {"alsoAllow": MAIN_ALSO_ALLOW}
        # NOTE: subagents config is in agent.json, NOT here
    },
    "intelligent-learning-audit": {
        "id": "intelligent-learning-audit",
        "name": "学习审计 Agent",
        "workspace": f"{HOME}/.openclaw/workspace-intelligent-learning-audit",
        "agentDir": f"{HOME}/.openclaw/agents/intelligent-learning-audit/agent",
        "skills": ["learning-audit"]
    }
}

# Detect reasoning model
reasoning_model = None
for p_name, p_val in c.get('models',{}).get('providers',{}).items():
    for m in p_val.get('models',[]):
        if m.get('reasoning'):
            reasoning_model = f"{p_name}/{m['id']}"
            break
    if reasoning_model:
        break

if reasoning_model:
    for aid in patch_agents:
        patch_agents[aid]['model'] = {"primary": reasoning_model}
    print(f"  ✓ Detected reasoning model: {reasoning_model}")
else:
    print("  ⚠ No reasoning model found. Please set model.primary manually.")

# Replace agent entries
new_agents = []
seen_ids = set()
for a in c['agents']['list']:
    if a['id'] in patch_agents:
        new_agents.append(patch_agents[a['id']])
        seen_ids.add(a['id'])
    else:
        new_agents.append(a)
for aid, adata in patch_agents.items():
    if aid not in seen_ids:
        new_agents.append(adata)
c['agents']['list'] = new_agents

# --- Feishu channel: preserve credentials, set streaming ---
c.setdefault('channels',{}).setdefault('feishu',{}).setdefault('accounts',{})
il_acc = c['channels']['feishu']['accounts'].get('intelligent-learning', {})
if 'intelligent-learning' in existing_creds:
    il_acc.update(existing_creds['intelligent-learning'])
il_acc['enabled'] = True
il_acc['streaming'] = True
il_acc.setdefault('uat', {})['ownerOnly'] = False
c['channels']['feishu']['accounts']['intelligent-learning'] = il_acc
print(f"  ✓ intelligent-learning channel: streaming=true")

# --- Binding ---
c['bindings'] = [b for b in c.get('bindings', [])
                  if not (b.get('agentId') == 'intelligent-learning-assistant'
                          and b.get('match',{}).get('accountId') == 'intelligent-learning')]
c['bindings'].append({
    "agentId": "intelligent-learning-assistant",
    "match": {"channel": "feishu", "accountId": "intelligent-learning"}
})

# --- Top-level tools: allow cross-agent sessions_send ---
c.setdefault('tools', {})
c['tools']['sessions'] = {'visibility': 'all'}
print("  ✓ tools.sessions.visibility=all (cross-agent calls)")

with open(CONFIG, 'w') as f:
    json.dump(c, f, indent=2, ensure_ascii=False)
print("  ✓ openclaw.json saved")
PYEOF

# Step 9: Validate and restart
echo "[9/9] Validating config and restarting gateway..."
if command -v openclaw &>/dev/null; then
    if openclaw config validate 2>&1 | grep -q "valid"; then
        echo "  ✓ Config valid"
        openclaw gateway restart 2>&1
        echo "  ✓ Gateway restarted"
    else
        echo "  ⚠ Config validation failed. Run: openclaw config validate"
        echo "    Then fix issues and run: openclaw gateway restart"
    fi
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
echo "1. In Feishu, send '你好' to the bot to test"
echo "2. Agent should reply with self-introduction"
echo ""
echo "📋 Feishu scopes: workspace/intelligent-learning-assistant/templates/feishu-scopes.json"
echo "🤖 AI tool deploy prompt: docs/DEPLOY-PROMPT.md"
echo ""
