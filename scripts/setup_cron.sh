#!/bin/bash

# Setup script for Rails daily research cron job

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESEARCH_SCRIPT="$SCRIPT_DIR/rails_daily_research.sh"
CRON_LOG_DIR="$SCRIPT_DIR/../logs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Rails Daily Research Cron Setup${NC}"
echo "=================================="

# Check if research script exists
if [ ! -f "$RESEARCH_SCRIPT" ]; then
    echo -e "${RED}Error: Research script not found at $RESEARCH_SCRIPT${NC}"
    exit 1
fi

# Make research script executable
chmod +x "$RESEARCH_SCRIPT"
echo -e "${GREEN}✓${NC} Made research script executable"

# Create logs directory
mkdir -p "$CRON_LOG_DIR"
echo -e "${GREEN}✓${NC} Created logs directory"

# Get current user's crontab
current_cron=$(crontab -l 2>/dev/null || true)

# Check if job already exists
if echo "$current_cron" | grep -q "rails_daily_research.sh"; then
    echo -e "${YELLOW}Warning: Rails research cron job already exists${NC}"
    echo "Current entry:"
    echo "$current_cron" | grep "rails_daily_research.sh"
    echo
    read -p "Do you want to replace it? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing cron job"
        exit 0
    fi
    # Remove existing entry
    current_cron=$(echo "$current_cron" | grep -v "rails_daily_research.sh")
fi

# Ask user for schedule preference
echo "When should the Rails research run?"
echo "1) Daily at 9:00 AM (recommended)"
echo "2) Daily at 6:00 AM"
echo "3) Daily at 12:00 PM (noon)"
echo "4) Daily at 6:00 PM"
echo "5) Every Monday at 9:00 AM"
echo "6) Custom schedule"

read -p "Select option (1-6): " schedule_choice

case $schedule_choice in
    1)
        cron_schedule="0 9 * * *"
        schedule_desc="Daily at 9:00 AM"
        ;;
    2)
        cron_schedule="0 6 * * *"
        schedule_desc="Daily at 6:00 AM"
        ;;
    3)
        cron_schedule="0 12 * * *"
        schedule_desc="Daily at 12:00 PM"
        ;;
    4)
        cron_schedule="0 18 * * *"
        schedule_desc="Daily at 6:00 PM"
        ;;
    5)
        cron_schedule="0 9 * * 1"
        schedule_desc="Every Monday at 9:00 AM"
        ;;
    6)
        echo "Enter custom cron schedule (e.g., '0 9 * * *' for daily at 9 AM):"
        read -r cron_schedule
        schedule_desc="Custom: $cron_schedule"
        ;;
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

# Ask about notifications
echo
echo "Optional: Enter email for notifications (press Enter to skip):"
read -r notification_email

echo
echo "Optional: Enter Slack webhook URL for notifications (press Enter to skip):"
read -r slack_webhook

# Create environment file for cron
ENV_FILE="$SCRIPT_DIR/.rails_research_env"
cat > "$ENV_FILE" << EOF
# Rails Research Environment Variables
# Generated on $(date)

# Repository path
export RAILS_GUIDE_REPO="$(dirname "$SCRIPT_DIR")"

# Notifications (optional)
EOF

if [ -n "$notification_email" ]; then
    echo "export NOTIFICATION_EMAIL=\"$notification_email\"" >> "$ENV_FILE"
fi

if [ -n "$slack_webhook" ]; then
    echo "export SLACK_WEBHOOK_URL=\"$slack_webhook\"" >> "$ENV_FILE"
fi

# Ensure PATH includes claude command location
CLAUDE_PATH=$(which claude 2>/dev/null || echo "/usr/local/bin/claude")
echo "export PATH=\"$(dirname "$CLAUDE_PATH"):\$PATH\"" >> "$ENV_FILE"

# Create the cron entry
new_cron_entry="$cron_schedule source $ENV_FILE && $RESEARCH_SCRIPT >> $CRON_LOG_DIR/cron.log 2>&1"

# Add to crontab
if [ -n "$current_cron" ]; then
    echo "$current_cron" | { cat; echo "$new_cron_entry"; } | crontab -
else
    echo "$new_cron_entry" | crontab -
fi

echo -e "${GREEN}✓${NC} Cron job installed successfully!"
echo
echo "Schedule: $schedule_desc"
echo "Script: $RESEARCH_SCRIPT"
echo "Logs: $CRON_LOG_DIR/"
echo
echo "To verify the cron job:"
echo "  crontab -l"
echo
echo "To manually run the research:"
echo "  $RESEARCH_SCRIPT"
echo
echo "To remove the cron job:"
echo "  crontab -l | grep -v 'rails_daily_research.sh' | crontab -"
echo
echo -e "${GREEN}Setup complete!${NC} The Rails research will run automatically according to your schedule."