# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About This Repository

This is a Rails 8 knowledge base created from real-world debugging experience. It contains verified information about Rails 8.0 (released November 2024) that may not be in Claude Code's training data.

## Repository Purpose

This repository serves as a reference guide for Rails 8 development, focusing on:
- Critical Rails 8 changes from official documentation
- Active Storage best practices and pitfalls
- The Solid trilogy (Queue/Cache/Cable) replacing Redis
- Deployment with Thruster and Kamal 2
- Performance optimizations with YJIT

## Key Rails 8 Facts

- **Solid Queue** handles 20M jobs/day at HEY (replaces Sidekiq/Redis)
- **Propshaft** is the new default asset pipeline (replaces Sprockets)
- **Active Storage proxy mode** is a performance killer - use redirect mode
- **YJIT** enabled by default (15-30% performance boost)
- **Thruster** provides HTTP/2, SSL, and compression out of the box

## Critical Guidelines

### Active Storage Configuration
- **NEVER** switch between proxy/redirect modes without understanding the cost
- **ALWAYS** use redirect mode with `public: true` for public images
- **Pre-generate variants** to avoid synchronous processing delays
- Each configuration change can trigger expensive variant regeneration

### Solid Trilogy Setup
- **Always use separate databases** for Solid Queue/Cache to avoid locks
- Solid Cable has no 8KB limit (Turbo 8 sends signals, not HTML)
- Test database-backed solutions before removing Redis entirely

## Essential Resources in This Repository

### Core Documentation
1. **README.md** - Comprehensive Rails 8 changes and verified research
2. **CLAUDE_CODE_CHECKLIST.md** - Quick reference to avoid costly mistakes  
3. **MIGRATION_GUIDE.md** - Step-by-step guide for upgrading from Rails 7 to Rails 8

### Specialized Guides
4. **active_storage_examples.md** - Real-world Active Storage patterns and anti-patterns
5. **active_storage_costs.md** - Cost calculator and financial impact of configuration changes
6. **solid_trilogy_setup.md** - Complete configuration for Solid Queue/Cache/Cable
7. **turbo_8_morphing.md** - Turbo 8 morphing and broadcasting patterns
8. **COMMON_ERRORS.md** - Rails 8-specific error messages and solutions

## When Working with Rails 8

If uncertain about Rails 8 behavior:
1. Reference the guides in this repository first
2. Admit uncertainty rather than guessing
3. Check Rails source code when documentation is unclear
4. Test configuration changes in development before production

## Common Rails 8 Commands

```ruby
# Check configuration
RubyVM::YJIT.enabled?
Rails.application.config.active_storage.resolve_model_to_route
Rails.application.config.active_job.queue_adapter

# Generate authentication scaffolding
bin/rails generate authentication

# Run with Thruster (HTTP/2 proxy)
bin/thrust bin/rails server

# Deploy with Kamal 2
kamal setup   # First deployment
kamal deploy  # Zero-downtime deploy
```

## Important Warnings

⚠️ Every variant regeneration costs real money in S3 operations
⚠️ Proxy mode for public images can cause 2+ minute load times
⚠️ Configuration changes may trigger bulk reprocessing
⚠️ Test all Active Storage changes in development first