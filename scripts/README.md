# Rails Research Automation Scripts

This directory contains automation scripts for daily Rails 8 research using Claude Code's headless mode.

## 🚀 Quick Start (macOS)

```bash
# 1. Test Claude Code headless mode
./test_claude_headless.sh

# 2. Run the setup wizard
./setup_mac.sh

# 3. Choose your preferred automation method (launchd or cron)
```

## 📁 Scripts Overview

### Core Scripts

- **`rails_daily_research.sh`** - Main research automation script
  - Runs Claude Code in headless mode
  - Searches for Rails updates
  - Updates GitHub issue #2
  - Commits and pushes changes
  - Handles retries and logging

- **`setup_mac.sh`** - macOS setup wizard
  - Interactive configuration
  - Sets up launchd or cron
  - Creates environment files
  - Offers test run

- **`test_claude_headless.sh`** - Verification script
  - Tests Claude Code headless mode
  - Verifies tool access
  - Checks GitHub authentication

### Alternative Setup Scripts

- **`setup_cron.sh`** - Generic Unix/Linux cron setup
- **`rails-research.service`** - systemd service file (Linux)
- **`rails-research.timer`** - systemd timer file (Linux)
- **`com.rails.research.plist`** - launchd configuration (macOS)

## ⚙️ Configuration

### Environment Variables

Create `.rails_research_env` in this directory:

```bash
# Required
export RAILS_GUIDE_REPO="/Users/jeremy/Desktop/rails-8-claude-guide"
export PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$PATH"

# Optional notifications
export NOTIFICATION_EMAIL="your-email@example.com"
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."
```

### Schedule Configuration

#### Option 1: launchd (macOS native)
Edit `com.rails.research.plist`:
```xml
<key>StartCalendarInterval</key>
<dict>
    <key>Hour</key>
    <integer>9</integer>  <!-- Change hour here -->
    <key>Minute</key>
    <integer>0</integer>  <!-- Change minute here -->
</dict>
```

#### Option 2: cron
```bash
# Edit crontab
crontab -e

# Daily at 9 AM
0 9 * * * /path/to/rails_daily_research.sh
```

## 🔧 Manual Execution

```bash
# Run the research manually
./rails_daily_research.sh

# Run with custom repo path
RAILS_GUIDE_REPO=/custom/path ./rails_daily_research.sh

# Test specific Claude Code command
claude -p "Check Rails blog for updates" --output-format json
```

## 📊 Monitoring

### View Logs

```bash
# Today's research log
tail -f ../logs/rails_research_$(date +%Y%m%d)*.log

# Error log
tail -f ../logs/rails_research_errors.log

# All recent logs
ls -la ../logs/
```

### Check Automation Status

```bash
# launchd (macOS)
launchctl list | grep rails

# cron
crontab -l | grep rails

# View GitHub issue updates
gh issue view 2 --comments
```

## 🛠 Troubleshooting

### Common Issues

1. **Claude command not found**
   ```bash
   which claude  # Should return path
   # If not, ensure Claude Code is installed
   ```

2. **Permission denied**
   ```bash
   chmod +x *.sh  # Make scripts executable
   ```

3. **GitHub authentication failed**
   ```bash
   gh auth login  # Re-authenticate
   ```

4. **Automation not running**
   ```bash
   # Check launchd
   launchctl list | grep rails
   
   # Check cron
   grep CRON /var/log/system.log
   ```

## 📈 Cost Tracking

The automation tracks API usage costs in logs:

```bash
# Extract daily costs
grep "Cost:" ../logs/rails_research_*.log | awk '{sum+=$2} END {print "Total: $"sum}'

# Monthly estimate (assuming daily runs)
echo "Monthly estimate: $$(echo "0.10 * 30" | bc)"  # Adjust 0.10 to your average
```

## 🔐 Security Notes

- GitHub authentication uses existing `gh` CLI credentials
- No credentials are stored in scripts
- Logs may contain API responses - review before sharing
- Use environment variables for sensitive data

## 🚦 Automation Controls

### Start/Stop launchd

```bash
# Stop automation
launchctl unload ~/Library/LaunchAgents/com.rails.research.plist

# Start automation
launchctl load ~/Library/LaunchAgents/com.rails.research.plist

# Run immediately
launchctl start com.rails.research
```

### Manage cron

```bash
# View current jobs
crontab -l

# Remove Rails research job
crontab -l | grep -v rails_daily_research | crontab -

# Edit manually
crontab -e
```

## 📝 Customization

To modify the research focus, edit the prompt in `rails_daily_research.sh`:

```bash
# Line ~32-45: Modify the research prompt
claude -p "$(cat <<'EOF'
Your custom research instructions here...
EOF
)"
```

## 🆘 Support

- Check logs in `../logs/` for detailed error messages
- Review GitHub issue #2 for research history
- See `../AUTOMATION.md` for complete documentation

---

*These scripts automate Rails 8 knowledge base maintenance using Claude Code's headless mode.*