# Rails 7 to Rails 8 Migration Guide

*Complete guide for upgrading your Rails 7.x application to Rails 8.0*

## Pre-Migration Checklist

### Requirements
- [ ] Ruby 3.3.0 or higher (for YJIT support)
- [ ] All gems compatible with Rails 8
- [ ] Test suite passing on Rails 7.2
- [ ] Database backups created
- [ ] Staging environment available for testing

### Preparation Steps

```bash
# 1. Ensure you're on latest Rails 7
bundle update rails -v '~> 7.2'
bundle exec rails app:update

# 2. Run tests
bundle exec rails test
bundle exec rails test:system

# 3. Check gem compatibility
bundle outdated --strict
```

## Step 1: Update Ruby Version

```ruby
# .ruby-version
3.3.5  # or latest 3.3.x

# Gemfile
ruby "~> 3.3"

# Verify YJIT availability
ruby -v --yjit
# => ruby 3.3.5 (2024-09-03 revision ef084cc8f4) +YJIT
```

## Step 2: Update Gemfile

```ruby
# Gemfile

# Core Rails gems
gem "rails", "~> 8.0.3"

# Remove if migrating to Solid trilogy
# gem "redis"
# gem "sidekiq"
# gem "sprockets-rails"

# Add new Rails 8 defaults (usually included automatically)
gem "solid_queue"      # Background jobs
gem "solid_cache"      # Caching
gem "solid_cable"      # WebSockets
gem "propshaft"        # Asset pipeline
gem "thruster"         # HTTP/2 proxy
gem "kamal"           # Deployment

# Authentication (new generator)
# Run: bin/rails generate authentication
# Instead of devise or other gems
```

## Step 3: Run Rails Update Task

```bash
bundle update rails
bundle exec rails app:update

# Review each conflict carefully:
# - config/application.rb
# - config/environments/*.rb
# - config/initializers/*.rb
# - bin/*
```

## Step 4: Migrate from Sprockets to Propshaft

### Option A: Simple Assets (Recommended)

```ruby
# Remove from Gemfile
# gem "sprockets-rails"
# gem "sass-rails"

# Add to Gemfile
gem "propshaft"
gem "importmap-rails"  # For JavaScript
gem "cssbundling-rails"  # For CSS

# Run installers
bin/rails importmap:install
bin/rails css:install:tailwind  # or bootstrap, postcss, sass
```

### Option B: Keep Sprockets (Temporary)

```ruby
# Gemfile
gem "sprockets-rails"  # Keep for now

# config/application.rb
config.assets.compile = true  # If needed in production
```

### Migration Steps

```bash
# 1. Move assets
mv app/assets/stylesheets/application.scss app/assets/stylesheets/application.css
# Update syntax from Sass to CSS or use cssbundling

# 2. Update manifest
# app/assets/config/manifest.js (Propshaft doesn't use this)
# Delete or keep empty

# 3. Update layouts
# app/views/layouts/application.html.erb
<%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
<%= javascript_importmap_tags %>

# 4. Update JavaScript
# Convert Sprockets requires to ES6 imports
# app/javascript/application.js
import "@hotwired/turbo-rails"
import "controllers"
```

## Step 5: Migrate from Redis to Solid Trilogy

### Solid Queue (Replace Sidekiq/Resque)

```ruby
# 1. Install Solid Queue
bin/rails generate solid_queue:install

# 2. Update configuration
# config/application.rb
config.active_job.queue_adapter = :solid_queue

# 3. Create queue database
# config/database.yml
production:
  primary:
    <<: *default
  queue:
    <<: *default
    database: myapp_queue_production
    migrations_paths: db/queue_migrate

# 4. Migrate queue database
bin/rails db:create:queue
bin/rails db:migrate:queue

# 5. Update Procfile
web: bin/rails server
jobs: bin/jobs start

# 6. Migrate existing jobs
# Keep Sidekiq running during transition
# New jobs → Solid Queue
# Old jobs → Process in Sidekiq
```

### Solid Cache (Replace Redis Cache)

```ruby
# 1. Install Solid Cache
bin/rails generate solid_cache:install

# 2. Update configuration
# config/environments/production.rb
config.cache_store = :solid_cache_store

# 3. Migrate cache data (optional)
Rails.cache.clear  # Simple approach

# Or migrate important keys
old_cache = ActiveSupport::Cache::RedisCacheStore.new
new_cache = ActiveSupport::Cache::SolidCacheStore.new

important_keys.each do |key|
  value = old_cache.read(key)
  new_cache.write(key, value) if value
end
```

### Solid Cable (Replace Redis ActionCable)

```yaml
# config/cable.yml
production:
  # Before
  adapter: redis
  url: <%= ENV["REDIS_URL"] %>
  
  # After
  adapter: solid_cable
  connects_to:
    database:
      writing: :cable
  polling_interval: 0.1.seconds
```

## Step 6: Update Active Storage Configuration

```ruby
# config/application.rb

# Review and potentially change
config.active_storage.resolve_model_to_route = :rails_storage_redirect  # Default
# config.active_storage.resolve_model_to_route = :rails_storage_proxy  # If needed

# config/storage.yml
amazon:
  service: S3
  # ...
  public: true  # Add for public buckets (new in Rails 8)
```

## Step 7: Enable YJIT

```ruby
# config/boot.rb
ENV["RUBY_YJIT_ENABLE"] = "1"  # Rails 8 does this by default

# Or in production.rb
config.yjit = true  # Rails 8 helper

# Verify in console
Rails.console
> RubyVM::YJIT.enabled?
# => true
```

## Step 8: Update Turbo for Morphing

```erb
<!-- app/views/layouts/application.html.erb -->
<%= turbo_refreshes_with method: :morph, scroll: :preserve %>

<!-- Update models for broadcasting -->
```

```ruby
# app/models/post.rb
# Before (Turbo 7)
after_update_commit -> { 
  broadcast_replace_to "posts", 
    target: self,
    partial: "posts/post"
}

# After (Turbo 8)
broadcasts_refreshes
```

## Step 9: Authentication Generator

```bash
# Generate authentication scaffolding
bin/rails generate authentication

# This creates:
# - User model with secure password
# - Sessions controller
# - Password reset functionality
# - Email verification
# - Authentication concern

# Review and customize:
# - app/models/user.rb
# - app/controllers/sessions_controller.rb
# - app/views/sessions/*
```

## Step 10: Update Deployment

### Dockerfile Updates

```dockerfile
# Rails 8 includes optimized Dockerfile
# Key changes:

# Uses Thruster
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]

# YJIT enabled
ENV RUBY_YJIT_ENABLE="1"

# Multi-stage build optimized
FROM ruby:3.3-slim as base
```

### Kamal Configuration

```yaml
# config/deploy.yml
service: myapp
image: myapp

servers:
  web:
    - 192.168.1.1

proxy:
  ssl: true
  host: myapp.com

registry:
  username: <%= ENV["DOCKER_USERNAME"] %>
  password: <%= ENV["DOCKER_PASSWORD"] %>

env:
  RAILS_MASTER_KEY: <%= ENV["RAILS_MASTER_KEY"] %>

# Deploy
kamal setup  # First time
kamal deploy # Subsequent deploys
```

## Step 11: Testing the Migration

```ruby
# test/migration_test.rb
class MigrationTest < ActiveSupport::TestCase
  test "YJIT is enabled" do
    assert RubyVM::YJIT.enabled?
  end
  
  test "Solid Queue is configured" do
    assert_equal :solid_queue, Rails.application.config.active_job.queue_adapter
  end
  
  test "Solid Cache is working" do
    Rails.cache.write("test", "value")
    assert_equal "value", Rails.cache.read("test")
  end
  
  test "Propshaft serves assets" do
    assert defined?(Propshaft)
  end
end
```

## Rollback Plan

### Quick Rollback

```ruby
# Gemfile
gem "rails", "~> 7.2"  # Revert

# Restore Redis
config.active_job.queue_adapter = :sidekiq
config.cache_store = :redis_cache_store

# Restore Sprockets
gem "sprockets-rails"
```

### Database Rollback

```bash
# If Solid trilogy databases were created
bin/rails db:drop:queue
bin/rails db:drop:cache
bin/rails db:drop:cable
```

## Common Migration Issues

### Issue 1: Gems Incompatible

```ruby
# Check for Rails 8 compatibility
bundle update --conservative

# Common problematic gems:
# - devise (use Rails authentication generator)
# - paperclip (already deprecated, use Active Storage)
# - quiet_assets (not needed with Propshaft)
```

### Issue 2: Asset Pipeline Errors

```bash
# Clear all caches
bin/rails assets:clobber
bin/rails tmp:clear
bin/rails assets:precompile

# Check for Sprockets-specific code
grep -r "asset_path" app/
grep -r "require_tree" app/assets/
```

### Issue 3: Background Job Failures

```ruby
# Run both adapters during transition
class ApplicationJob < ActiveJob::Base
  # Route specific jobs during migration
  def self.queue_adapter
    if self.name.in?(["LegacyJob", "OldProcessorJob"])
      :sidekiq
    else
      :solid_queue
    end
  end
end
```

### Issue 4: Cache Key Changes

```ruby
# Clear all caches after migration
Rails.cache.clear

# Or version your cache keys
config.cache_version = 2.0
```

## Performance Comparison

```ruby
# Benchmark before and after
require 'benchmark/ips'

Benchmark.ips do |x|
  x.report("Rails 7.2") { load_rails_7_endpoint }
  x.report("Rails 8.0") { load_rails_8_endpoint }
  x.compare!
end

# Expected improvements:
# - 15-30% faster with YJIT
# - 10-20% faster asset serving with Propshaft
# - Similar job processing with Solid Queue
# - Reduced memory with Solid Cache (disk-based)
```

## Post-Migration Checklist

- [ ] All tests passing
- [ ] YJIT enabled and verified
- [ ] Solid Queue processing jobs
- [ ] Solid Cache serving cached content
- [ ] Solid Cable handling WebSockets
- [ ] Assets served via Propshaft
- [ ] Deployment working with Kamal
- [ ] Monitoring updated for new components
- [ ] Documentation updated
- [ ] Team trained on new features

## Gradual Migration Strategy

```ruby
# Phase 1: Update Ruby and Rails (Week 1)
# - Update to Ruby 3.3
# - Update to Rails 8
# - Keep existing infrastructure

# Phase 2: Asset Pipeline (Week 2)
# - Migrate from Sprockets to Propshaft
# - Update JavaScript to use importmaps

# Phase 3: Background Jobs (Week 3-4)
# - Run Solid Queue alongside Sidekiq
# - Gradually move job classes
# - Monitor performance

# Phase 4: Caching Layer (Week 5)
# - Implement Solid Cache
# - Keep Redis as fallback
# - Monitor hit rates

# Phase 5: WebSockets (Week 6)
# - Migrate ActionCable to Solid Cable
# - Test with subset of users

# Phase 6: Cleanup (Week 7)
# - Remove Redis
# - Remove old gems
# - Optimize configuration
```

---

*Remember: Rails 8 is about simplification. The migration might seem complex, but the end result is a simpler, more maintainable application with fewer dependencies.*