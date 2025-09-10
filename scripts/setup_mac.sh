#!/bin/bash

# Mac-specific setup for Rails daily research automation

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🍎 Rails Research Automation Setup for macOS${NC}"
echo "============================================"

# Paths
REPO_PATH="/Users/jeremy/Desktop/rails-8-claude-guide"
SCRIPT_PATH="$REPO_PATH/scripts/rails_daily_research.sh"
PLIST_PATH="$REPO_PATH/scripts/com.rails.research.plist"
LAUNCHD_PATH="$HOME/Library/LaunchAgents/com.rails.research.plist"

# Check if we're in the right directory
if [ ! -d "$REPO_PATH" ]; then
    echo -e "${RED}Error: Repository not found at $REPO_PATH${NC}"
    exit 1
fi

# Make script executable
chmod +x "$SCRIPT_PATH"
echo -e "${GREEN}✓${NC} Script made executable"

# Create logs directory
mkdir -p "$REPO_PATH/logs"
echo -e "${GREEN}✓${NC} Logs directory created"

# Check for Claude Code
if ! command -v claude &> /dev/null; then
    echo -e "${YELLOW}⚠️  Claude Code CLI not found in PATH${NC}"
    echo "Please ensure Claude Code is installed and accessible"
    echo "You can check with: which claude"
    exit 1
fi

CLAUDE_PATH=$(which claude)
echo -e "${GREEN}✓${NC} Claude Code found at: $CLAUDE_PATH"

# Create environment configuration
ENV_FILE="$REPO_PATH/scripts/.rails_research_env"
cat > "$ENV_FILE" << EOF
#!/bin/bash
# Rails Research Environment Configuration for macOS
# Generated on $(date)

# Repository location
export RAILS_GUIDE_REPO="$REPO_PATH"

# Ensure Claude is in PATH
export PATH="$(dirname "$CLAUDE_PATH"):/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:\$PATH"

# GitHub CLI should already be authenticated
# The gh command will use existing authentication

# Optional: Add any custom settings here
# export NOTIFICATION_EMAIL=""
# export SLACK_WEBHOOK_URL=""
EOF

echo -e "${GREEN}✓${NC} Environment configuration created"

# Setup method selection
echo
echo "Choose setup method:"
echo "1) Use launchd (macOS native - recommended)"
echo "2) Use cron (traditional Unix)"
echo "3) Manual execution only"

read -p "Select option (1-3): " setup_choice

case $setup_choice in
    1)
        # Setup with launchd
        echo -e "\n${GREEN}Setting up launchd...${NC}"
        
        # Copy plist to LaunchAgents
        cp "$PLIST_PATH" "$LAUNCHD_PATH"
        
        # Load the launch agent
        launchctl load "$LAUNCHD_PATH" 2>/dev/null || {
            echo -e "${YELLOW}Reloading existing agent...${NC}"
            launchctl unload "$LAUNCHD_PATH" 2>/dev/null || true
            launchctl load "$LAUNCHD_PATH"
        }
        
        echo -e "${GREEN}✓${NC} launchd agent installed and loaded"
        echo
        echo "The Rails research will run daily at 9:00 AM"
        echo
        echo "Useful commands:"
        echo "  View status:  launchctl list | grep rails"
        echo "  Run now:      launchctl start com.rails.research"
        echo "  Disable:      launchctl unload $LAUNCHD_PATH"
        echo "  Re-enable:    launchctl load $LAUNCHD_PATH"
        ;;
        
    2)
        # Setup with cron
        echo -e "\n${GREEN}Setting up cron...${NC}"
        
        # Check current crontab
        current_cron=$(crontab -l 2>/dev/null || true)
        
        # Check if already exists
        if echo "$current_cron" | grep -q "rails_daily_research.sh"; then
            echo -e "${YELLOW}Cron job already exists. Updating...${NC}"
            current_cron=$(echo "$current_cron" | grep -v "rails_daily_research.sh")
        fi
        
        # Add new cron job (daily at 9 AM)
        new_cron="0 9 * * * source $ENV_FILE && $SCRIPT_PATH >> $REPO_PATH/logs/cron.log 2>&1"
        
        if [ -n "$current_cron" ]; then
            echo "$current_cron" | { cat; echo "$new_cron"; } | crontab -
        else
            echo "$new_cron" | crontab -
        fi
        
        echo -e "${GREEN}✓${NC} Cron job installed"
        echo
        echo "The Rails research will run daily at 9:00 AM"
        echo
        echo "Useful commands:"
        echo "  View crontab: crontab -l"
        echo "  Edit crontab: crontab -e"
        echo "  Remove job:   crontab -l | grep -v rails_daily_research | crontab -"
        ;;
        
    3)
        # Manual only
        echo -e "\n${GREEN}Manual setup complete${NC}"
        echo
        echo "To run the Rails research manually:"
        echo "  $SCRIPT_PATH"
        echo
        echo "You can set up automation later by running this script again."
        ;;
        
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

# Test run offer
echo
read -p "Would you like to do a test run now? (y/n) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "\n${GREEN}Running Rails research test...${NC}"
    echo "(This will actually check for Rails updates and update the repository)"
    echo
    
    # Source environment and run
    source "$ENV_FILE"
    "$SCRIPT_PATH" || {
        echo -e "${RED}Test run failed. Check logs at:${NC}"
        echo "  $REPO_PATH/logs/rails_research_errors.log"
        exit 1
    }
    
    echo -e "\n${GREEN}✓ Test run completed successfully!${NC}"
fi

# Final instructions
echo
echo -e "${GREEN}🎉 Setup Complete!${NC}"
echo
echo "Repository: $REPO_PATH"
echo "Logs: $REPO_PATH/logs/"
echo "Issue tracking: GitHub issue #2"
echo
echo "The automation will:"
echo "1. Check Rails news sources daily"
echo "2. Comment findings on GitHub issue #2"
echo "3. Update documentation as needed"
echo "4. Commit and push changes automatically"
echo
echo "Monitor progress:"
echo "  tail -f $REPO_PATH/logs/rails_research_*.log"
echo
echo -e "${GREEN}Happy automated Rails researching! 🚂${NC}"