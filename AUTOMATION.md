# Rails Research Automation Guide

*Automated daily Rails 8 updates using Claude Code's headless mode*

## Overview

This automation system uses Claude Code's headless mode to automatically research Rails updates daily, maintaining the knowledge base without manual intervention.

## Architecture

```
┌─────────────────┐
│   Scheduler     │  (cron/systemd)
└────────┬────────┘
         │ Daily trigger
         ▼
┌─────────────────┐
│  Research       │  rails_daily_research.sh
│  Script         │
└────────┬────────┘
         │ Executes
         ▼
┌─────────────────┐
│  Claude Code    │  Headless mode
│  (--print)      │
└────────┬────────┘
         │ Performs
         ▼
┌─────────────────┐
│  Web Research   │  → Rails Blog
│  & Analysis     │  → GitHub Releases
│                 │  → Documentation
└────────┬────────┘
         │ Updates
         ▼
┌─────────────────┐
│  GitHub Repo    │  → Issue #2 comments
│  & Documentation│  → File updates
└─────────────────┘
```

## Quick Setup

### macOS/Linux with Cron

```bash
# 1. Make scripts executable
chmod +x scripts/rails_daily_research.sh
chmod +x scripts/setup_cron.sh

# 2. Run setup script
./scripts/setup_cron.sh

# 3. Verify installation
crontab -l | grep rails_daily_research
```

### Linux with systemd

```bash
# 1. Copy service files
sudo cp scripts/rails-research.service /etc/systemd/system/
sudo cp scripts/rails-research.timer /etc/systemd/system/

# 2. Copy script to system location
sudo cp scripts/rails_daily_research.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/rails_daily_research.sh

# 3. Enable and start timer
sudo systemctl daemon-reload
sudo systemctl enable rails-research.timer
sudo systemctl start rails-research.timer

# 4. Check status
sudo systemctl status rails-research.timer
sudo systemctl list-timers | grep rails
```

## Configuration

### Environment Variables

Create `.rails_research_env` in the scripts directory:

```bash
# Required
export RAILS_GUIDE_REPO="/path/to/rails-8-claude-guide"
export PATH="/usr/local/bin:$PATH"  # Include claude binary location

# Optional notifications
export NOTIFICATION_EMAIL="your-email@example.com"
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."

# Optional: Custom Claude Code settings
export CLAUDE_MAX_TOKENS="8192"
export CLAUDE_TEMPERATURE="0.7"
```

### Schedule Options

#### Cron Format
```bash
# Daily at 9 AM
0 9 * * * /path/to/rails_daily_research.sh

# Every Monday at 9 AM
0 9 * * 1 /path/to/rails_daily_research.sh

# Every 6 hours
0 */6 * * * /path/to/rails_daily_research.sh

# Weekdays at 8:30 AM
30 8 * * 1-5 /path/to/rails_daily_research.sh
```

#### systemd Timer Format
Edit `/etc/systemd/system/rails-research.timer`:
```ini
[Timer]
# Daily at specific time
OnCalendar=daily
OnCalendar=09:00:00

# Multiple times per day
OnCalendar=09:00,15:00,21:00

# Weekly
OnCalendar=weekly
OnCalendar=Mon 09:00
```

## How It Works

### 1. Research Script (`rails_daily_research.sh`)

The main script that:
- Validates environment and dependencies
- Pulls latest repository changes
- Executes Claude Code in headless mode
- Handles retries and error logging
- Pushes changes back to GitHub
- Sends optional notifications

### 2. Claude Code Headless Execution

Uses Claude Code's `--print` flag for non-interactive mode:

```bash
claude -p "Research Rails updates..." \
  --cwd /path/to/repo \
  --output-format json \
  --allowedTools "WebSearch,WebFetch,Bash,Read,Write,Edit" \
  --append-system-prompt "You are an automated Rails researcher..."
```

### 3. Research Prompt

The automated prompt instructs Claude Code to:
1. Check official Rails sources
2. Look for specific types of updates
3. Comment on GitHub issue #2
4. Update documentation if needed
5. Commit and describe changes

### 4. Output Processing

JSON output includes:
- `session_id`: For debugging and continuity
- `total_cost_usd`: Track API usage costs
- `result`: The actual response
- `is_error`: Success/failure status

## Manual Execution

### Run Research Manually

```bash
# Direct execution
./scripts/rails_daily_research.sh

# With custom repo path
RAILS_GUIDE_REPO=/custom/path ./scripts/rails_daily_research.sh

# Verbose mode
VERBOSE=1 ./scripts/rails_daily_research.sh
```

### Test Claude Code Command

```bash
# Test basic functionality
claude -p "Check Rails blog for updates" --output-format json

# Test with specific tools
claude -p "Search for Rails 8.1 news" \
  --allowedTools "WebSearch,WebFetch" \
  --output-format json

# Dry run (no actual changes)
claude -p "What Rails updates would you research?" \
  --allowedTools "WebSearch" \
  --output-format json
```

## Monitoring

### Log Files

```bash
# View today's research log
tail -f logs/rails_research_$(date +%Y%m%d).log

# View error log
tail -f logs/rails_research_errors.log

# View cron execution log
tail -f logs/cron.log

# Check systemd logs (Linux)
sudo journalctl -u rails-research.service -f
```

### Health Checks

```bash
# Check last run time (cron)
grep "Starting Rails Daily Research" logs/rails_research_*.log | tail -1

# Check systemd timer status
systemctl status rails-research.timer

# Verify GitHub updates
gh issue view 2 --comments | grep "Rails Update Research"
```

### Cost Tracking

Monitor API usage costs:

```bash
# Extract costs from logs
grep "Cost:" logs/rails_research_*.log | \
  awk '{sum+=$2} END {print "Total: $"sum}'

# Daily cost report
for file in logs/rails_research_*.log; do
  date=$(basename $file | sed 's/rails_research_//;s/.log//')
  cost=$(grep "Cost:" $file | awk '{sum+=$2} END {print sum}')
  echo "$date: \$$cost"
done
```

## Troubleshooting

### Common Issues

#### 1. Claude Command Not Found

```bash
# Check if claude is in PATH
which claude

# Add to PATH in .rails_research_env
export PATH="/path/to/claude:$PATH"
```

#### 2. Git Push Failures

```bash
# Ensure SSH key is loaded
ssh-add ~/.ssh/id_rsa

# Or use HTTPS with token
git remote set-url origin https://token@github.com/user/repo.git
```

#### 3. Cron Not Running

```bash
# Check cron service
sudo service cron status  # Linux
sudo launchctl list | grep cron  # macOS

# Check cron logs
grep CRON /var/log/syslog  # Linux
log show --predicate 'process == "cron"' --last 1h  # macOS
```

#### 4. Permission Errors

```bash
# Fix script permissions
chmod +x scripts/*.sh

# Fix log directory permissions
chmod 755 logs/
```

### Debug Mode

Enable debug output by editing the script:

```bash
# In rails_daily_research.sh, add:
set -x  # Enable bash debug mode

# Or set environment variable
DEBUG=1 ./scripts/rails_daily_research.sh
```

## Advanced Configuration

### Custom Research Focus

Modify the research prompt in `rails_daily_research.sh`:

```bash
claude -p "$(cat <<'EOF'
Focus on Rails security updates and performance improvements.
Prioritize ActionCable and Active Storage changes.
Include Hotwire and Turbo updates.
EOF
)"
```

### Multiple Repositories

Create separate cron entries for different repos:

```bash
# Rails 8 guide
0 9 * * * RAILS_GUIDE_REPO=/path/to/rails-8-guide /usr/local/bin/rails_daily_research.sh

# Rails 7 guide
0 10 * * * RAILS_GUIDE_REPO=/path/to/rails-7-guide /usr/local/bin/rails_daily_research.sh
```

### Webhook Integration

Send results to external services:

```bash
# In rails_daily_research.sh, add:
send_to_webhook() {
    local result="$1"
    curl -X POST https://your-webhook.com/rails-updates \
      -H "Content-Type: application/json" \
      -d "{\"update\": \"$result\"}"
}
```

### Cost Limits

Add spending controls:

```bash
# Check monthly cost before running
MONTHLY_LIMIT=10.00
current_cost=$(calculate_monthly_cost)

if (( $(echo "$current_cost > $MONTHLY_LIMIT" | bc -l) )); then
    error_log "Monthly cost limit exceeded: $current_cost > $MONTHLY_LIMIT"
    exit 1
fi
```

## Security Considerations

### Best Practices

1. **Limit Tool Access**: Only allow necessary tools
   ```bash
   --allowedTools "WebSearch,WebFetch,Read,Write"
   ```

2. **Restrict File Access**: Use `--cwd` to limit scope
   ```bash
   --cwd /specific/repo/path
   ```

3. **Secure Credentials**: Never commit sensitive data
   - Use environment variables
   - Store in separate `.env` files
   - Use GitHub secrets for Actions

4. **Audit Logs**: Regularly review logs for anomalies
   ```bash
   # Weekly audit
   ./scripts/audit_logs.sh
   ```

5. **Rate Limiting**: Prevent runaway costs
   - Set maximum retries
   - Add delay between attempts
   - Monitor usage patterns

## Maintenance

### Weekly Tasks

```bash
# Review logs for errors
grep ERROR logs/rails_research_errors.log | tail -20

# Check disk usage
du -sh logs/

# Verify GitHub connectivity
gh auth status
```

### Monthly Tasks

```bash
# Clean old logs (automated in script)
find logs/ -name "*.log" -mtime +30 -delete

# Review cost trends
./scripts/cost_report.sh

# Update Claude Code CLI
claude --version
# Update if needed
```

## Extending the Automation

### Add New Sources

Edit the research prompt to include additional sources:

```bash
# In rails_daily_research.sh
"Check these sources for Rails news:
   - Rails Blog
   - Ruby Weekly newsletter
   - RailsConf announcements
   - Popular Rails gems updates"
```

### Custom Actions

Add post-research actions:

```bash
# After successful research
if [ "$success" = true ]; then
    # Generate summary report
    ./scripts/generate_summary.sh
    
    # Update dashboard
    ./scripts/update_dashboard.sh
    
    # Trigger CI/CD
    gh workflow run update-docs.yml
fi
```

### Integration with CI/CD

```yaml
# .github/workflows/on-research-update.yml
name: Post-Research Actions
on:
  push:
    branches: [main]
    paths:
      - '**.md'
      - 'rails_8_1_beta.md'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Validate documentation
        run: ./scripts/validate_docs.sh
      - name: Deploy to documentation site
        run: ./scripts/deploy_docs.sh
```

---

*This automation system ensures the Rails 8 knowledge base stays current with minimal manual intervention, leveraging Claude Code's headless mode for intelligent research and updates.*