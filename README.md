# Rails 8 Study Guide for Claude Code Sessions

*Last Updated: September 2025*  
*Rails 8.0: Released November 7, 2024*  
*Rails 8.1 Beta 1: Released September 4, 2025*

This concise guide provides essential Rails 8 knowledge for Claude Code sessions, focusing on verified changes from official documentation and production usage.

> **🆕 Rails 8.1 Beta Available**: Job Continuations, Structured Events, and Local CI are now in beta. See [Rails 8.1 Beta Features](rails_8_1_beta.md) for implementation details.

## Table of Contents
1. [Rails 8 Core Changes](#rails-8-core-changes)
2. [Rails 8.1 Beta Features](rails_8_1_beta.md)
3. [Active Storage Critical Points](#active-storage-critical-points)
4. [The Solid Trilogy](#the-solid-trilogy)
5. [Propshaft Asset Pipeline](#propshaft-asset-pipeline)
6. [Turbo 8 & Morphing](#turbo-8--morphing)
7. [Deployment Stack](#deployment-stack)
8. [Performance](#performance)
9. [Common Pitfalls](#common-pitfalls)

## Rails 8 Core Changes

**Philosophy**: "No PaaS Required" - Deploy to any VPS with built-in production tools

### What's New
- **Solid Queue/Cache/Cable**: SQLite-backed, replaces Redis (20M jobs/day at HEY)
- **Propshaft**: Replaces 15-year-old Sprockets
- **Authentication Generator**: Built-in auth scaffolding
- **Thruster**: HTTP/2 proxy with SSL, compression, X-Sendfile
- **Kamal 2**: Zero-downtime deployment tool
- **YJIT**: Enabled by default (15-30% faster)

### What's Removed
- **Azure Storage Backend**: Completely removed
- **Sprockets**: No longer default (still available)

## Active Storage Critical Points

### Proxy vs Redirect Mode
```ruby
# Redirect (DEFAULT, FAST) - Direct S3 URLs
config.active_storage.resolve_model_to_route = :rails_storage_redirect

# Proxy (SLOW) - Forces through Rails
config.active_storage.resolve_model_to_route = :rails_storage_proxy
```

**⚠️ CRITICAL**: Switching modes changes URLs but NOT variant digests. However, it triggers URL regeneration which can be expensive.

### Public Access (New in Rails 8)
```yaml
# config/storage.yml
amazon:
  service: S3
  public: true  # Permanent public URLs without signatures
```

### Variant Generation
```ruby
# Pre-generate to avoid synchronous processing
Photo.find_each { |p| p.image.variant(:large).processed }
```

## The Solid Trilogy

### Solid Queue (Replaces Sidekiq)
```ruby
config.active_job.queue_adapter = :solid_queue
```
- Handles 20M jobs/day at HEY
- Recurring jobs, concurrency controls
- Use separate database to avoid locks

### Solid Cache (Replaces Redis cache)
```ruby
config.cache_store = :solid_cache_store
```
- Disk-based, handles terabytes
- Encrypted entries support
- No memory limits

### Solid Cable (Replaces Redis pub/sub)
```ruby
# config/cable.yml
production:
  adapter: solid_cable
```
- No 8KB limit (Turbo 8 sends signals, not HTML)
- Database LISTEN/NOTIFY or polling

## Propshaft Asset Pipeline

**Philosophy**: No transpilation, no concatenation, just fingerprinting

```ruby
# New apps default
gem 'propshaft'

# Sprockets apps migrating
# Remove: gem 'sprockets-rails'
```

### Key Differences from Sprockets
- **No Sass/Coffee compilation** (use jsbundling/cssbundling)
- **No minification** (HTTP/2 makes bundling less critical)
- **Faster builds**: Direct fingerprinting
- **Import maps**: Native integration

## Turbo 8 & Morphing

Released February 2024, enables real-time updates with minimal code:

### Model Broadcasting
```ruby
class Post < ApplicationRecord
  broadcasts_refreshes  # One line for real-time!
end
```

### View Setup
```erb
<%= turbo_refreshes_with method: :morph, scroll: :preserve %>
```

### How It Works
1. Model changes trigger refresh broadcast (not HTML)
2. Idiomorph calculates minimal DOM changes
3. Morphing preserves scroll position and form state
4. 0.5s debouncing batches updates

## Deployment Stack

### Thruster (HTTP/2 Proxy)
```dockerfile
# Included in Rails 8 Dockerfile
CMD ["./bin/thrust", "./bin/rails", "server"]
```

Features:
- HTTP/2 (Puma doesn't support)
- Auto SSL with Let's Encrypt
- Gzip compression
- X-Sendfile acceleration

### Kamal 2
```yaml
# config/deploy.yml
service: myapp
servers:
  web:
    - 192.168.1.100
proxy:
  ssl: true
  host: myapp.com
```

```bash
kamal setup   # First deployment
kamal deploy  # Zero-downtime deploy
```

## Performance

### Ruby 3.3 + YJIT
- **Enabled by default** in Rails 8 production
- **15-30% faster** (80M requests/minute at Shopify)
- **21% memory increase** (improved from 40% in Ruby 3.2)

### ActiveRecord Improvements
- Better complex association queries
- JSONB with GIN indexes
- Read replica support
- Batch processing optimizations

## Common Pitfalls

### 1. Active Storage URL Changes
**Problem**: Switching proxy/redirect regenerates all URLs  
**Solution**: Pick one mode and stick with it

### 2. Variant Regeneration
**Problem**: Config changes trigger expensive reprocessing  
**Solution**: Pre-generate variants with background jobs

### 3. Proxy Mode Performance
**Problem**: Loading gallery takes 2+ minutes  
**Solution**: Use redirect mode with public: true

### 4. Solid Queue in Same Database
**Problem**: Job processing causes app locks  
**Solution**: Always use separate database

### 5. Missing CORS Headers
**Problem**: Service worker can't cache S3 images  
**Solution**: Configure S3 CORS properly

## Quick Diagnostic Commands

```ruby
# Check configuration
RubyVM::YJIT.enabled?
Rails.application.config.active_storage.resolve_model_to_route
Rails.application.config.active_job.queue_adapter
Rails.application.config.cache_store

# Generate authentication
bin/rails generate authentication

# Run with Thruster
bin/thrust bin/rails server
```

## Rails 8.1 Beta Highlights

**Released September 4, 2025** - Three game-changing features:

### Job Continuations
- Break long-running jobs into resumable steps
- Survive deployments and restarts
- Perfect for Kamal's 30-second shutdown window

### Structured Events
- Machine-readable logging with `Rails.event`
- Tagged context and structured data
- Built for modern observability tools

### Local CI
- Run CI locally with `bin/ci`
- Defined in `config/ci.rb`
- Optional GitHub integration

See [Rails 8.1 Beta Features Guide](rails_8_1_beta.md) for complete documentation.

## Essential Resources

- [Rails 8 Release Notes](https://rubyonrails.org/2024/11/7/rails-8-no-paas-required)
- [Rails Guides](https://guides.rubyonrails.org/)
- [Solid Queue](https://github.com/rails/solid_queue)
- [Propshaft](https://github.com/rails/propshaft)
- [Kamal](https://kamal-deploy.org/)
- [Thruster](https://github.com/basecamp/thruster)

---

*Created after extensive research following Rails 8 Active Storage debugging. Based on official documentation and production usage at Shopify, 37signals, and others.*