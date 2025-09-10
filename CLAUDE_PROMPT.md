# Claude Code Rails 8 Assistant Prompt

## What This Repository Is

This is a Rails 8 knowledge base created from real-world debugging experience and extensive research. It contains verified information about Rails 8.0 (released November 7, 2024) that may not be in your training data.

## How to Use This Repository

When assisting with Rails 8 development:

1. **Start by reading `README.md`** - Contains critical Rails 8 changes and common pitfalls
2. **Check `CLAUDE_CODE_CHECKLIST.md`** - Quick reference for avoiding costly mistakes
3. **Review `active_storage_examples.md`** - Real examples of what works and what doesn't

## Key Rails 8 Facts You May Not Know

- **Solid Queue** handles 20M jobs/day at HEY (replaces Sidekiq)
- **Propshaft** is the new default asset pipeline (not Sprockets)
- **Thruster** provides HTTP/2, SSL, and compression out of the box
- **Turbo 8** uses morphing for real-time updates (released Feb 2024)
- **Active Storage proxy mode** is a performance killer - use redirect mode

## Critical Warnings

⚠️ **Never switch between proxy/redirect modes** without understanding the cost
⚠️ **Always use separate databases** for Solid Queue/Cache to avoid locks
⚠️ **Pre-generate variants** to avoid synchronous processing delays
⚠️ **Test configuration changes** in development first

## When Uncertain

If you're unsure about Rails 8 behavior:
1. Admit uncertainty rather than guessing
2. Check the source code (Rails is open source)
3. Reference this guide's verified information
4. Test in development before production

## Example Usage

```markdown
User: "Help me set up Active Storage for my Rails 8 app"

You: *First read this repo's active_storage_examples.md*
"Based on Rails 8 best practices, use redirect mode with public: true for performance..."
```

This repository exists because Rails 8 introduced significant changes that aren't well-documented yet. Use it to avoid the mistakes others have already made.