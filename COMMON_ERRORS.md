# Rails 8 Common Errors & Solutions

*Quick reference for debugging Rails 8-specific issues*

## Table of Contents
1. [Active Storage Errors](#active-storage-errors)
2. [Solid Queue Errors](#solid-queue-errors)
3. [Solid Cache Errors](#solid-cache-errors)
4. [Solid Cable Errors](#solid-cable-errors)
5. [Propshaft Asset Pipeline Errors](#propshaft-asset-pipeline-errors)
6. [Turbo 8 Morphing Issues](#turbo-8-morphing-issues)
7. [YJIT Configuration Errors](#yjit-configuration-errors)
8. [Kamal Deployment Errors](#kamal-deployment-errors)

## Active Storage Errors

### Error: Variant processing timeout
```
ActiveStorage::InvariableError: Could not transform blob, 
execution expired
```

**Cause**: Large image processing in synchronous mode

**Solution**:
```ruby
# config/application.rb
config.active_storage.variant_processor = :vips # Faster than mini_magick

# Pre-process variants in background
class ProcessVariantsJob < ApplicationJob
  def perform(record)
    record.image.variant(:thumb).processed
    record.image.variant(:large).processed
  end
end
```

### Error: URLs not working after switching modes
```
ActionController::RoutingError: No route matches 
[GET] "/rails/active_storage/redirect/..."
```

**Cause**: Switching between proxy/redirect modes without clearing cache

**Solution**:
```ruby
# Clear CDN cache after mode switch
Rails.cache.clear
ActiveStorage::Current.url_options = { host: request.base_url }

# Regenerate URLs (expensive!)
Model.find_each do |record|
  record.image.url(expires_in: 1.week) # Force new URL generation
end
```

### Error: CORS blocking S3 images
```
Access to image at 'https://s3.amazonaws.com/...' from origin 
'https://myapp.com' has been blocked by CORS policy
```

**Solution**: Configure S3 bucket CORS
```json
[
  {
    "AllowedHeaders": ["*"],
    "AllowedMethods": ["GET", "HEAD"],
    "AllowedOrigins": ["https://myapp.com"],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 3600
  }
]
```

## Solid Queue Errors

### Error: Database locked
```
ActiveRecord::StatementInvalid: SQLite3::BusyException: 
database is locked
```

**Cause**: Queue using same database as main app

**Solution**: Use separate database
```yaml
# config/database.yml
production:
  primary:
    <<: *default
    database: myapp_production
  queue:
    <<: *default
    database: myapp_queue_production
    migrations_paths: db/queue_migrate
```

```ruby
# config/application.rb
config.solid_queue.connects_to = { database: { writing: :queue } }
```

### Error: Jobs not processing
```
SolidQueue::Job::EnqueueError: Failed to enqueue job
```

**Diagnosis**:
```ruby
# Rails console
SolidQueue::Job.failed.count
SolidQueue::Job.failed.last.exception
SolidQueue::Process.all
```

**Solution**:
```bash
# Restart queue workers
bin/jobs restart

# Clear failed jobs (careful!)
SolidQueue::Job.failed.destroy_all
```

## Solid Cache Errors

### Error: Cache misses despite writes
```
Rails.cache.write("key", "value") # => true
Rails.cache.read("key") # => nil
```

**Cause**: Cache database not configured properly

**Solution**:
```ruby
# config/environments/production.rb
config.cache_store = :solid_cache_store, {
  connects_to: { database: { writing: :cache } }
}

# Verify configuration
Rails.cache.stats
```

### Error: Encryption key issues
```
ActiveSupport::MessageEncryptor::InvalidMessage
```

**Solution**:
```ruby
# config/application.rb
config.solid_cache.encryption = true
config.solid_cache.encryption_key = Rails.application.credentials.cache_encryption_key

# Generate new key
Rails.application.credentials.cache_encryption_key ||= SecureRandom.hex(32)
```

## Solid Cable Errors

### Error: WebSocket connection failing
```
WebSocket connection to 'wss://myapp.com/cable' failed
```

**Diagnosis**:
```javascript
// Browser console
new WebSocket('wss://myapp.com/cable').onerror = (e) => console.log(e)
```

**Solution**:
```yaml
# config/cable.yml
production:
  adapter: solid_cable
  connects_to:
    database:
      writing: :cable
  polling_interval: 0.1.seconds # For SQLite, use polling
```

### Error: Messages exceeding size limit
```
SolidCable::BroadcastError: Message too large
```

**Solution**: Turbo 8 sends signals, not HTML
```ruby
# Instead of broadcasting HTML
broadcast_replace_to "posts", target: "post_#{post.id}", 
                     html: render(post) # BAD

# Broadcast refresh signal
broadcast_refresh_to "posts" # GOOD - Turbo fetches fresh HTML
```

## Propshaft Asset Pipeline Errors

### Error: Assets not compiling
```
Propshaft::AssetNotFound: Could not find asset "application.css"
```

**Cause**: Expecting Sprockets behavior

**Solution**: Propshaft doesn't compile/concatenate
```ruby
# Use importmap for JS
bin/importmap pin stimulus

# Use cssbundling for CSS
bundle add cssbundling-rails
bin/rails css:install:tailwind
```

### Error: Missing asset helpers
```
NoMethodError: undefined method `asset_path' for #<Propshaft::Asset>
```

**Solution**: Update to Propshaft syntax
```erb
<!-- Old Sprockets -->
<%= asset_path('logo.png') %>

<!-- New Propshaft -->
<%= image_path('logo.png') %>
```

## Turbo 8 Morphing Issues

### Error: Form state lost on morph
```
Page refreshes but form inputs are cleared
```

**Solution**: Configure morphing properly
```erb
<%= turbo_refreshes_with method: :morph, scroll: :preserve %>
<%= form_with model: @post, data: { turbo_permanent: true } do |f| %>
```

### Error: Morphing not working
```
Console: "Turbo Streams response missing"
```

**Solution**: Ensure model broadcasts
```ruby
class Post < ApplicationRecord
  # Must be after callbacks
  after_commit :broadcast_refresh
  
  # Or use the helper
  broadcasts_refreshes
end
```

## YJIT Configuration Errors

### Error: YJIT not enabled
```ruby
RubyVM::YJIT.enabled? # => false
```

**Solution**: Check Ruby version and enable
```ruby
# Requires Ruby 3.3+
RUBY_VERSION # => "3.3.0"

# config/boot.rb (Rails 8 default)
ENV["RUBY_YJIT_ENABLE"] = "1"

# Or in Dockerfile
ENV RUBY_YJIT_ENABLE=1
```

### Error: Memory usage spike
```
Memory usage increased by 40%
```

**Solution**: Normal for YJIT, but can tune
```ruby
# Limit YJIT memory (MB)
ENV["RUBY_YJIT_EXEC_MEM_SIZE"] = "128"

# Monitor YJIT stats
RubyVM::YJIT.runtime_stats
```

## Kamal Deployment Errors

### Error: Let's Encrypt SSL failing
```
Kamal: SSL certificate generation failed
```

**Requirements**:
- Domain must point to server IP
- Port 443 must be open
- Single server for initial cert

**Solution**:
```yaml
# config/deploy.yml
proxy:
  ssl: true
  host: myapp.com # Must resolve to this server

servers:
  web:
    - 1.2.3.4 # Domain must point here
```

### Error: Zero-downtime deploy failing
```
Kamal: Health check failed, rollback initiated
```

**Solution**: Fix health check endpoint
```ruby
# config/routes.rb
get "up" => "rails/health#show", as: :rails_health_check

# Ensure it returns 200
curl https://myapp.com/up
```

### Error: Container not starting
```
Kamal: Container exited with code 1
```

**Debug**:
```bash
# Check logs
kamal app logs --lines 100

# SSH to server
kamal app exec -i bash

# Check container directly
docker ps -a
docker logs <container_id>
```

## Troubleshooting Decision Tree

```
Is it an Active Storage issue?
├── YES → Check proxy/redirect mode
│         Check variant configuration
│         Verify S3 CORS settings
└── NO → Continue

Is it a Solid trilogy issue?
├── YES → Verify separate database config
│         Check connection pools
│         Review job/cache/cable logs
└── NO → Continue

Is it an asset issue?
├── YES → Verify Propshaft vs Sprockets
│         Check importmap/jsbundling
│         Review asset paths
└── NO → Continue

Is it a deployment issue?
├── YES → Check Kamal logs
│         Verify SSL/domain setup
│         Test health endpoints
└── NO → Check YJIT and Ruby version
```

## Quick Diagnostic Commands

```bash
# Check all configurations
rails runner "
  puts 'Storage mode: ' + Rails.application.config.active_storage.resolve_model_to_route.to_s
  puts 'Queue adapter: ' + Rails.application.config.active_job.queue_adapter.to_s
  puts 'Cache store: ' + Rails.application.config.cache_store.to_s
  puts 'Cable adapter: ' + ActionCable.server.config.cable.to_s
  puts 'YJIT enabled: ' + RubyVM::YJIT.enabled?.to_s
  puts 'Ruby version: ' + RUBY_VERSION
"

# Monitor background jobs
watch -n 1 'rails runner "puts SolidQueue::Job.pending.count"'

# Check variant processing
rails runner "ActiveStorage::VariantRecord.where(created_at: 1.hour.ago..).count"
```

---

*Remember: Most Rails 8 errors stem from configuration mismatches or attempting Rails 7 patterns. When in doubt, check the [official Rails 8 guides](https://guides.rubyonrails.org/) for the latest patterns.*