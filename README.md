# Rails 8 Study Guide for Claude Code

> A comprehensive guide for AI assistants working with Rails 8 applications. Learn from mistakes, avoid pitfalls, and understand the modern Rails stack.

## ⚠️ Critical Context

**Rails 8 Release Date**: November 2024  
**Important**: If your training data predates this, you're missing critical information. Always check documentation and source code before making assumptions.

## 📚 Table of Contents

1. [Rails 8 Overview](#rails-8-overview)
2. [The Solid Trilogy](#the-solid-trilogy)
3. [Active Storage in Rails 8](#active-storage-in-rails-8)
4. [Authentication](#authentication)
5. [Asset Pipeline Changes](#asset-pipeline-changes)
6. [Deployment with Kamal](#deployment-with-kamal)
7. [Performance Improvements](#performance-improvements)
8. [Critical Pitfalls](#critical-pitfalls)
9. [Essential Resources](#essential-resources)

---

## Rails 8 Overview

Rails 8 represents a major shift toward **"No Build"** philosophy and production-ready defaults. Key themes:

- **SQLite as production-ready database** (with proper configuration)
- **Solid adapters** replace Redis/Sidekiq dependencies
- **Built-in authentication** generator
- **Propshaft** as default asset pipeline (replacing Sprockets)
- **Kamal 2** for deployment

### Key Philosophy Changes

```ruby
# Rails 7 and earlier - multiple dependencies
gem 'redis'
gem 'sidekiq'
gem 'devise'

# Rails 8 - batteries included
# Solid Queue, Solid Cache, Solid Cable built-in
# Authentication generator included
# SQLite production-ready with proper config
```

## The Solid Trilogy

### 1. Solid Queue

**What it is**: Database-backed Active Job backend replacing Redis/Sidekiq  
**Source**: [rails/solid_queue](https://github.com/rails/solid_queue)

```ruby
# config/application.rb
config.active_job.queue_adapter = :solid_queue

# config/database.yml
production:
  primary:
    <<: *default
    database: storage/production.sqlite3
  queue:
    <<: *default
    database: storage/production_queue.sqlite3
    migrations_paths: db/queue_migrate
```

**Key Points**:
- Uses database (SQLite/PostgreSQL/MySQL) instead of Redis
- Supports multiple databases for queue isolation
- Built-in mission-critical job support
- Automatic job expiration

### 2. Solid Cache

**What it is**: Database-backed Rails cache store  
**Source**: [rails/solid_cache](https://github.com/rails/solid_cache)

```ruby
# config/environments/production.rb
config.cache_store = :solid_cache_store

# config/database.yml
production:
  cache:
    <<: *default
    database: storage/production_cache.sqlite3
    migrations_paths: db/cache_migrate
```

**Key Points**:
- Disk-based caching with database
- Can handle terabytes of cache data
- No memory limits like Redis
- Automatic expiration handling

### 3. Solid Cable

**What it is**: Database/disk-backed Action Cable adapter  
**Source**: [rails/solid_cable](https://github.com/rails/solid_cable)

```ruby
# config/cable.yml
production:
  adapter: solid_cable
  
# config/database.yml
production:
  cable:
    <<: *default
    database: storage/production_cable.sqlite3
    migrations_paths: db/cable_migrate
```

## Active Storage in Rails 8

### ⚠️ Critical Understanding Points

1. **Variant Digest Calculation**:
```ruby
# What determines variant digest:
def digest
  OpenSSL::Digest::SHA1.base64digest Marshal.dump(transformations)
end

# The variant KEY includes:
# - blob.key
# - SHA256 hash of variation.key
# - NOT affected by proxy/redirect mode in the digest itself
```

2. **Proxy vs Redirect Mode**:

```ruby
# application.rb

# Default (Redirect mode) - RECOMMENDED for most cases
# Generates 302 redirects to S3, fast and efficient
# config.active_storage.resolve_model_to_route = :rails_storage_redirect

# Proxy mode - Use ONLY when needed
# Forces all images through Rails (SLOW!)
config.active_storage.resolve_model_to_route = :rails_storage_proxy
```

3. **Public vs Private Storage**:

```yaml
# config/storage.yml
amazon:
  service: S3
  # ...
  public: true  # Makes URLs permanently accessible without signatures
  # Does NOT change variant digests!
```

### Common Active Storage Mistakes

❌ **DON'T**: Change proxy/redirect modes without understanding implications  
❌ **DON'T**: Assume variant URLs are stable across configuration changes  
❌ **DON'T**: Use proxy mode for public-facing images (performance killer)  

✅ **DO**: Use redirect mode with public: true for public images  
✅ **DO**: Pre-generate variants with rake tasks for large collections  
✅ **DO**: Understand that variant processing is expensive (CPU, bandwidth, storage)

## Authentication

Rails 8 includes a built-in authentication generator:

```bash
# Generates complete authentication system
rails generate authentication

# Creates:
# - User model with has_secure_password
# - Sessions controller
# - Password reset functionality
# - Email verification (optional)
```

**Key Files Generated**:
- `app/models/user.rb`
- `app/controllers/sessions_controller.rb`
- `app/controllers/passwords_controller.rb`
- `app/views/sessions/new.html.erb`

**Important**: This replaces the need for Devise in many applications.

## Asset Pipeline Changes

### Propshaft (New Default)

**What it is**: Simplified asset pipeline replacing Sprockets  
**Philosophy**: "No Build" - serve modern JavaScript/CSS directly

```ruby
# Gemfile
gem 'propshaft' # Default in Rails 8

# config/application.rb
config.assets.compile = true # Always true with Propshaft
```

**Key Differences from Sprockets**:
- No asset concatenation
- No built-in minification (use external tools)
- Simpler, faster, fewer dependencies
- Relies on HTTP/2 multiplexing

### When to Use Sprockets

Still use Sprockets if you need:
- Asset concatenation
- Built-in Sass compilation
- Complex asset transformation pipeline

## Deployment with Kamal

**What it is**: Docker-based deployment tool from 37signals  
**Replaces**: Capistrano, complex CI/CD pipelines

```yaml
# config/deploy.yml
service: myapp
image: myapp

servers:
  web:
    - 192.168.1.1
  job:
    - 192.168.1.2
    cmd: bin/jobs

registry:
  username: myuser
  password:
    - KAMAL_REGISTRY_PASSWORD

env:
  secret:
    - RAILS_MASTER_KEY
```

```bash
# Deployment commands
kamal setup      # First time setup
kamal deploy     # Deploy application
kamal rollback   # Rollback to previous version
```

## Performance Improvements

### 1. SQLite Production Optimizations

```ruby
# config/database.yml
production:
  adapter: sqlite3
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000
  database: storage/production.sqlite3
  
  # Critical for production SQLite
  journal_mode: WAL
  synchronous: NORMAL
  cache_size: 10000
  mmap_size: 134217728
  busy_timeout: 5000
```

### 2. Lazy Loading by Default

Rails 8 improves lazy loading throughout:
- Zeitwerk code loading optimizations
- Lazy route loading
- Improved boot time

### 3. Better Caching Defaults

```ruby
# Production defaults are much more aggressive
config.action_controller.perform_caching = true
config.public_file_server.headers = {
  'Cache-Control' => 'public, max-age=31536000'
}
```

## Critical Pitfalls

### 1. Active Storage Variant Regeneration

**Problem**: Changing certain configurations triggers expensive variant regeneration

**Triggers**:
- Changing image processor (vips → mini_magick)
- Modifying transformation parameters
- Switching between proxy/redirect modes (in some cases)

**Solution**: 
- Understand what affects variant digests
- Pre-generate variants with rake tasks
- Test configuration changes in development first

### 2. Proxy Mode Performance

**Problem**: Setting `rails_storage_proxy` globally kills performance

**Why**: Every image request goes through Rails instead of direct to S3

**Solution**:
```ruby
# Use redirect mode (default)
# Only use proxy for specific protected resources
<%= image_tag rails_storage_proxy_path(@user.avatar) %> # Selective proxy
```

### 3. Solid Queue Database Separation

**Problem**: Running jobs in same database as application causes locks

**Solution**: Always use separate database for Solid Queue:
```yaml
# config/database.yml
production:
  primary:
    database: production.sqlite3
  queue:
    database: production_queue.sqlite3
```

## Essential Resources

### Official Documentation
- [Rails 8 Release Notes](https://rubyonrails.org/2024/11/7/rails-8-0-has-been-released)
- [Rails Guides (Edge)](https://edgeguides.rubyonrails.org/)
- [Rails API Documentation](https://api.rubyonrails.org/)

### Source Code (Critical for Understanding)
- [Rails Main Repository](https://github.com/rails/rails)
- [Active Storage Source](https://github.com/rails/rails/tree/main/activestorage)
- [Solid Queue](https://github.com/rails/solid_queue)
- [Solid Cache](https://github.com/rails/solid_cache)
- [Solid Cable](https://github.com/rails/solid_cable)

### Video Resources
- [Rails 8: The Demo](https://www.youtube.com/watch?v=iqXjGiQ_D-A) - DHH's walkthrough
- [Rails World 2024 Opening Keynote](https://www.youtube.com/watch?v=iqXjGiQ_D-A)

### Deployment
- [Kamal Documentation](https://kamal-deploy.org/)
- [Kamal GitHub](https://github.com/basecamp/kamal)

### Community Resources
- [Rails Discord](https://discord.gg/rails)
- [Rails Discussions](https://discuss.rubyonrails.org/)
- [Rails Reddit](https://www.reddit.com/r/rails/)

## Quick Reference Checklist

When working with Rails 8 applications:

- [ ] Check Ruby version (3.3+ recommended)
- [ ] Verify which Solid adapters are in use
- [ ] Understand the asset pipeline (Propshaft vs Sprockets)
- [ ] Check Active Storage configuration (proxy vs redirect)
- [ ] Review database configuration (separate DBs for queue/cache?)
- [ ] Confirm deployment method (Kamal vs traditional)
- [ ] Test variant generation in development before production
- [ ] Always read source code when documentation is unclear

## Lessons Learned

From real-world Rails 8 debugging:

1. **When unsure, read the source code** - Rails is open source, use it
2. **Test configuration changes cheaply** - Use development/staging first
3. **Understand the money costs** - S3 operations, processing time, storage
4. **Admit uncertainty** - Better to research than guess
5. **Configuration changes can cascade** - One change may trigger many effects

---

## Contributing

This guide is meant to evolve. Key areas needing expansion:
- Turbo 8 / Strada integration
- More Solid Queue patterns
- Production SQLite optimization
- Real-world Kamal deployment examples

---

*Created: January 2025 | Last Updated: January 2025*

*This guide was created after learning painful lessons about Rails 8's Active Storage system. May it prevent future mistakes.*