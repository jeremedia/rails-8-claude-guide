#!/bin/bash

# Rails Daily Research Automation Script
# Runs Claude Code in headless mode to research Rails updates and maintain the repository

set -euo pipefail

# Configuration
REPO_PATH="${RAILS_GUIDE_REPO:-/Users/jeremy/Desktop/rails-8-claude-guide}"
LOG_DIR="${REPO_PATH}/logs"
LOG_FILE="${LOG_DIR}/rails_research_$(date +%Y%m%d_%H%M%S).log"
ERROR_LOG="${LOG_DIR}/rails_research_errors.log"
MAX_RETRIES=3
RETRY_DELAY=60

# Ensure PATH includes common Mac locations
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:$PATH"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Logging functions
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error_log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "$ERROR_LOG" >&2
}

# Function to run Claude Code for Rails research
run_rails_research() {
    local attempt=1
    local success=false
    
    while [ $attempt -le $MAX_RETRIES ] && [ "$success" = false ]; do
        log "Starting Rails research (attempt $attempt/$MAX_RETRIES)..."
        
        # Run Claude Code with the Rails research prompt
        if claude -p "$(cat <<'EOF'
You are maintaining the Rails 8 knowledge base repository. Perform the following tasks:

1. Check these sources for Rails news:
   - Rails Blog (https://rubyonrails.org/blog)
   - Rails GitHub Releases (https://github.com/rails/rails/releases)
   - Rails Edge Guides (https://edgeguides.rubyonrails.org/)
   - 37signals Dev Blog (https://dev.37signals.com/)

2. Look for:
   - New Rails 8.x releases or patches
   - Security updates
   - Breaking changes
   - New features in beta/RC
   - Performance improvements
   - Production insights from companies using Rails 8

3. If you find relevant updates:
   - Add a comment to GitHub issue #2 with your findings
   - Update repository documentation if needed
   - Commit any changes with descriptive messages

4. If no relevant news is found, still comment on issue #2 stating "No new relevant Rails updates found today"

Use the template format from issue #2 for your comment.
Focus on information that would help Claude Code assist with Rails 8 development.
EOF
        )" \
        --cwd "$REPO_PATH" \
        --output-format json \
        --allowedTools "WebSearch,WebFetch,Bash,Read,Write,Edit,MultiEdit,TodoWrite" \
        --append-system-prompt "You are an automated Rails news researcher. Be thorough but concise. Focus on actionable updates for Rails 8 developers." \
        --verbose \
        2>> "$ERROR_LOG" | tee -a "$LOG_FILE"; then
            
            success=true
            log "Rails research completed successfully"
            
            # Extract session ID and cost from JSON output
            if command -v jq >/dev/null 2>&1; then
                session_id=$(tail -n 1 "$LOG_FILE" | jq -r '.session_id // empty')
                cost=$(tail -n 1 "$LOG_FILE" | jq -r '.total_cost_usd // 0')
                
                if [ -n "$session_id" ]; then
                    log "Session ID: $session_id"
                fi
                
                if [ "$cost" != "0" ]; then
                    log "Cost: \$$cost USD"
                fi
            fi
        else
            error_log "Rails research failed on attempt $attempt"
            
            if [ $attempt -lt $MAX_RETRIES ]; then
                log "Retrying in $RETRY_DELAY seconds..."
                sleep $RETRY_DELAY
            fi
            
            ((attempt++))
        fi
    done
    
    if [ "$success" = false ]; then
        error_log "Rails research failed after $MAX_RETRIES attempts"
        return 1
    fi
    
    return 0
}

# Function to check repository status
check_repo_status() {
    log "Checking repository status..."
    
    cd "$REPO_PATH" || {
        error_log "Failed to change to repository directory: $REPO_PATH"
        return 1
    }
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        error_log "Not a git repository: $REPO_PATH"
        return 1
    }
    
    # Pull latest changes
    if ! git pull origin main 2>> "$ERROR_LOG"; then
        error_log "Failed to pull latest changes"
        # Continue anyway - maybe we have local changes to push
    fi
    
    return 0
}

# Function to push any changes
push_changes() {
    log "Checking for changes to push..."
    
    cd "$REPO_PATH" || return 1
    
    if [ -n "$(git status --porcelain)" ]; then
        log "Uncommitted changes found, attempting to commit..."
        
        # Stage all changes
        git add -A
        
        # Create commit message
        git commit -m "Automated Rails research update - $(date +'%Y-%m-%d')

Automated daily Rails research performed by rails_daily_research.sh
See issue #2 for details

🤖 Generated with Claude Code (headless mode)" 2>> "$ERROR_LOG" || {
            error_log "Failed to commit changes"
            return 1
        }
    fi
    
    # Push if there are commits to push
    if [ -n "$(git log origin/main..HEAD 2>/dev/null)" ]; then
        log "Pushing changes to remote..."
        
        if git push origin main 2>> "$ERROR_LOG"; then
            log "Changes pushed successfully"
        else
            error_log "Failed to push changes"
            return 1
        fi
    else
        log "No changes to push"
    fi
    
    return 0
}

# Function to send notification (optional)
send_notification() {
    local status="$1"
    local message="$2"
    
    # If slack webhook is configured, send notification
    if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
        curl -X POST "$SLACK_WEBHOOK_URL" \
            -H 'Content-Type: application/json' \
            -d "{\"text\": \"Rails Research $status: $message\"}" \
            2>/dev/null || true
    fi
    
    # If email is configured, send email
    if [ -n "${NOTIFICATION_EMAIL:-}" ] && command -v mail >/dev/null 2>&1; then
        echo "$message" | mail -s "Rails Research $status" "$NOTIFICATION_EMAIL" 2>/dev/null || true
    fi
}

# Main execution
main() {
    log "========================================="
    log "Starting Rails Daily Research Automation"
    log "========================================="
    
    # Check if Claude Code is available
    if ! command -v claude >/dev/null 2>&1; then
        error_log "Claude Code CLI not found. Please ensure 'claude' is in PATH"
        send_notification "FAILED" "Claude Code CLI not found"
        exit 1
    fi
    
    # Check repository status
    if ! check_repo_status; then
        error_log "Repository check failed"
        send_notification "FAILED" "Repository check failed"
        exit 1
    fi
    
    # Run Rails research
    if run_rails_research; then
        # Push any changes
        push_changes || {
            error_log "Failed to push changes but research completed"
            send_notification "WARNING" "Research completed but push failed"
        }
        
        log "Rails daily research completed successfully"
        send_notification "SUCCESS" "Rails daily research completed. Check issue #2 for updates."
    else
        error_log "Rails research failed"
        send_notification "FAILED" "Rails research automation failed. Check logs at $ERROR_LOG"
        exit 1
    fi
    
    # Clean up old logs (keep last 30 days)
    log "Cleaning up old logs..."
    find "$LOG_DIR" -name "rails_research_*.log" -mtime +30 -delete 2>/dev/null || true
    
    log "Script completed successfully"
}

# Run main function
main "$@"