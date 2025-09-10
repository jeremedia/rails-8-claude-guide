# GitHub Actions for Rails Research Automation

This directory contains GitHub Actions workflows that automate Rails 8 research and documentation updates.

## 🤖 Available Workflows

### 1. Daily Rails Research (`rails-daily-research.yml`)

**Purpose**: Automatically researches Rails updates every day and updates documentation.

**Schedule**: Daily at 9:00 AM UTC

**Features**:
- Checks Rails blog, GitHub releases, and documentation
- Posts findings to GitHub issue #2
- Updates repository documentation when needed
- Automatic commits and pushes

**Manual Trigger**:
```bash
gh workflow run rails-daily-research.yml
```

### 2. Claude Mentions (`claude-mentions.yml`)

**Purpose**: Responds to `@claude` mentions in issues and pull requests.

**Triggers**:
- Issue comments with `@claude`
- PR review comments with `@claude`
- New issues with `@claude` in body

**Usage**:
```markdown
@claude Can you explain the changes in Rails 8.1 Beta?
@claude Help me understand Active Storage proxy mode
```

### 3. Manual Research (`manual-research.yml`)

**Purpose**: Manually trigger targeted Rails research with custom parameters.

**Features**:
- Specify research focus areas
- Choose whether to update documentation
- Add custom sources to check

**Usage**:
```bash
# Via GitHub UI
Go to Actions → Manual Rails Research → Run workflow

# Via CLI
gh workflow run manual-research.yml \
  -f research_focus="Rails 8.1 Turbo morphing" \
  -f update_docs=true
```

## 🔑 Required Setup

### 1. Add Repository Secret

Go to **Settings → Secrets and variables → Actions** and add:

- `ANTHROPIC_API_KEY`: Your Anthropic API key from [console.anthropic.com](https://console.anthropic.com)

### 2. Verify Permissions

Ensure workflows have these permissions (already configured in workflows):
- `contents: write` - To update documentation
- `issues: write` - To comment on issue #2
- `pull-requests: write` - For PR interactions

## 📊 Monitoring

### View Workflow Runs

```bash
# List all workflow runs
gh run list

# List runs for specific workflow
gh run list --workflow=rails-daily-research.yml

# View specific run details
gh run view <run-id>

# Watch a run in progress
gh run watch
```

### Check Latest Research

- View [Issue #2](../../../issues/2) for all research comments
- Check [Actions tab](../../../actions) for workflow history
- Review commit history for documentation updates

## ⚙️ Customization

### Change Schedule

Edit the cron expression in `rails-daily-research.yml`:

```yaml
on:
  schedule:
    # Examples:
    - cron: '0 9 * * *'    # Daily at 9 AM UTC
    - cron: '0 */6 * * *'  # Every 6 hours
    - cron: '0 9 * * 1'    # Weekly on Monday
```

### Modify Research Focus

Edit the prompt in any workflow to change what Rails topics to prioritize:

```yaml
prompt: |
  Focus especially on:
  - Rails 8.1 Beta updates
  - Active Storage changes
  - Turbo and Stimulus updates
```

### Change Claude Model

Update the `claude_args` in any workflow:

```yaml
claude_args: |
  --max-turns 15
  --model claude-opus-4-1-20250805  # Use Opus for more thorough research
```

## 🚨 Troubleshooting

### Workflow Not Running

1. Check if Actions are enabled: Settings → Actions → General
2. Verify `ANTHROPIC_API_KEY` is set in secrets
3. Check workflow syntax: `gh workflow view <workflow-name>`

### Claude Not Responding

1. Ensure `@claude` is used (not `/claude` or `@Claude`)
2. Check API key is valid
3. Review [workflow runs](../../../actions) for error messages

### No Documentation Updates

1. Workflow may determine no updates needed
2. Check issue #2 for "No updates found" comments
3. Manually trigger with specific focus area

## 📈 Cost Tracking

Each workflow run uses the Anthropic API. Typical costs:
- Daily research: ~$0.05-0.15 per run
- Manual research: ~$0.10-0.25 per run
- Claude mentions: ~$0.02-0.10 per response

Monthly estimate (daily runs): ~$3-5

## 🔒 Security Notes

- API keys are stored as encrypted secrets
- Workflows run in isolated GitHub-hosted runners
- No sensitive data is logged or exposed
- All changes are tracked in git history

---

*These workflows use the [Claude Code GitHub Action](https://github.com/anthropics/claude-code-action) v1.*