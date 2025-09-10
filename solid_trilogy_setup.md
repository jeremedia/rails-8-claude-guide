# Solid Trilogy Setup Guide for Rails 8

*Complete configuration guide for Solid Queue, Solid Cache, and Solid Cable*

## Overview

The Solid trilogy replaces Redis with SQLite/PostgreSQL/MySQL-backed solutions:
- **Solid Queue**: Background job processing (replaces Sidekiq/Redis)
- **Solid Cache**: Database-backed caching (replaces Redis cache)
- **Solid Cable**: WebSocket pub/sub (replaces Redis ActionCable)

## Critical Setup Rule

**⚠️ ALWAYS USE SEPARATE DATABASES** to avoid lock contention and performance issues.

## Complete Database Configuration

### SQLite Setup (Development/Small Apps)

```yaml
# config/database.yml
default: &default
  adapter: sqlite3
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000

development:
  primary:
    <<: *default
    database: storage/development.sqlite3
  queue:
    <<: *default
    database: storage/queue_development.sqlite3
    migrations_paths: db/queue_migrate
  cache:
    <<: *default
    database: storage/cache_development.sqlite3
    migrations_paths: db/cache_migrate
  cable:
    <<: *default
    database: storage/cable_development.sqlite3
    migrations_paths: db/cable_migrate

production:
  primary:
    <<: *default
    database: storage/production.sqlite3
  queue:
    <<: *default
    database: storage/queue_production.sqlite3
    migrations_paths: db/queue_migrate
  cache:
    <<: *default
    database: storage/cache_production.sqlite3
    migrations_paths: db/cache_migrate
  cable:
    <<: *default
    database: storage/cable_production.sqlite3
    migrations_paths: db/cable_migrate
```

### PostgreSQL Setup (Production)

```yaml
# config/database.yml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  username: <%= ENV['DATABASE_USERNAME'] %>
  password: <%= ENV['DATABASE_PASSWORD'] %>
  host: <%= ENV.fetch("DATABASE_HOST", "localhost") %>

production:
  primary:
    <<: *default
    database: myapp_production
    pool: 10
  queue:
    <<: *default
    database: myapp_queue_production
    pool: 20  # Higher pool for job processing
    migrations_paths: db/queue_migrate
  cache:
    <<: *default
    database: myapp_cache_production
    pool: 5
    migrations_paths: db/cache_migrate
  cable:
    <<: *default
    database: myapp_cable_production
    pool: 5
    migrations_paths: db/cable_migrate
```

### MySQL Setup

```yaml
# config/database.yml
default: &default
  adapter: mysql2
  encoding: utf8mb4
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  username: <%= ENV['DATABASE_USERNAME'] %>
  password: <%= ENV['DATABASE_PASSWORD'] %>
  host: <%= ENV.fetch("DATABASE_HOST", "localhost") %>

production:
  primary:
    <<: *default
    database: myapp_production
  queue:
    <<: *default
    database: myapp_queue_production
    pool: 20
    migrations_paths: db/queue_migrate
    variables:
      # Required for FOR UPDATE SKIP LOCKED
      innodb_lock_wait_timeout: 5
  cache:
    <<: *default
    database: myapp_cache_production
    migrations_paths: db/cache_migrate
  cable:
    <<: *default
    database: myapp_cable_production
    migrations_paths: db/cable_migrate
```

## Solid Queue Configuration

### Installation

```bash
# Add to Gemfile (included by default in Rails 8)
bundle add solid_queue

# Generate migrations
bin/rails generate solid_queue:install

# Move migrations to queue database
mv db/migrate/*solid_queue*.rb db/queue_migrate/

# Create queue database and run migrations
bin/rails db:create:queue
bin/rails db:migrate:queue
```

### Configuration

```ruby
# config/application.rb
config.active_job.queue_adapter = :solid_queue

# Connect to separate database
config.solid_queue.connects_to = { 
  database: { 
    writing: :queue,
    reading: :queue 
  } 
}

# config/solid_queue.yml
production:
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "*"
      threads: 3
      processes: 2
      polling_interval: 0.1
```

### Starting Queue Workers

```ruby
# Procfile
web: bin/rails server
jobs: bin/jobs start

# Or use systemd
# /etc/systemd/system/solid_queue.service
[Unit]
Description=Solid Queue Worker
After=network.target

[Service]
Type=simple
User=deploy
WorkingDirectory=/var/www/myapp
ExecStart=/usr/bin/env bin/jobs start
Restart=always

[Install]
WantedBy=multi-user.target
```

### Recurring Jobs

```ruby
# config/recurring.yml
production:
  cleanup_old_sessions:
    class: CleanupJob
    queue: maintenance
    schedule: every day at 3am

  process_analytics:
    class: AnalyticsJob
    schedule: every hour

# app/jobs/cleanup_job.rb
class CleanupJob < ApplicationJob
  def perform
    Session.where("created_at < ?", 30.days.ago).destroy_all
  end
end
```

## Solid Cache Configuration

### Installation

```bash
# Add to Gemfile (included by default in Rails 8)
bundle add solid_cache

# Generate migrations
bin/rails generate solid_cache:install

# Move to cache database
mv db/migrate/*solid_cache*.rb db/cache_migrate/

# Create and migrate
bin/rails db:create:cache
bin/rails db:migrate:cache
```

### Configuration

```ruby
# config/environments/production.rb
config.cache_store = :solid_cache_store, {
  connects_to: { database: { writing: :cache, reading: :cache } },
  cluster: {
    shards: 3,
    nodes: 3
  },
  expiry_method: :job,  # Use job for cleanup
  expiry_batch_size: 1000,
  max_age: 1.week,
  max_size: 512.megabytes,
  encrypt: true  # Encrypt cache entries
}

# For simpler setup
config.cache_store = :solid_cache_store
```

### Cache Key Configuration

```ruby
# config/application.rb
# Enable encryption for sensitive data
config.solid_cache.encrypt = true
config.solid_cache.encryption_key = Rails.application.credentials.solid_cache_key

# Generate key
Rails.application.credentials.solid_cache_key ||= SecureRandom.hex(32)
```

## Solid Cable Configuration

### Installation

```bash
# Add to Gemfile (included by default in Rails 8)
bundle add solid_cable

# Generate migrations
bin/rails generate solid_cable:install

# Move to cable database
mv db/migrate/*solid_cable*.rb db/cable_migrate/

# Create and migrate
bin/rails db:create:cable
bin/rails db:migrate:cable
```

### Configuration

```yaml
# config/cable.yml
development:
  adapter: solid_cable
  connects_to:
    database:
      writing: :cable
      reading: :cable
  polling_interval: 0.1.seconds
  message_retention: 1.day

production:
  adapter: solid_cable
  connects_to:
    database:
      writing: :cable
      reading: :cable
  polling_interval: 0.1.seconds  # For SQLite
  # polling_interval: 1.second    # For PostgreSQL/MySQL with LISTEN/NOTIFY
  message_retention: 1.hour
```

### PostgreSQL with LISTEN/NOTIFY

```ruby
# More efficient than polling for PostgreSQL
# config/cable.yml
production:
  adapter: solid_cable
  connects_to:
    database:
      writing: :cable
      reading: :cable
  use_listen_notify: true  # Enable LISTEN/NOTIFY
  polling_interval: nil    # Disable polling
```

## Migration from Redis

### Step 1: Parallel Running

```ruby
# Run both Redis and Solid in parallel during migration
# config/application.rb
if ENV['MIGRATION_MODE']
  # Queue: Run jobs in both
  config.active_job.queue_adapter = :solid_queue
  
  # Also keep Sidekiq running temporarily
  
  # Cache: Write to both, read from Redis
  config.cache_store = :redis_cache_store
  
  # Cable: Keep Redis for now
  # config/cable.yml stays on Redis
end
```

### Step 2: Data Migration

```ruby
# lib/tasks/migrate_to_solid.rake
namespace :solid do
  desc "Migrate Redis cache to Solid Cache"
  task migrate_cache: :environment do
    redis = Redis.new
    solid = ActiveSupport::Cache::SolidCacheStore.new
    
    redis.keys("*").each do |key|
      value = redis.get(key)
      ttl = redis.ttl(key)
      solid.write(key, value, expires_in: ttl.seconds) if ttl > 0
    end
  end
  
  desc "Verify Solid Queue is processing"
  task verify_queue: :environment do
    TestJob.perform_later
    sleep 5
    if SolidQueue::Job.finished.where(class_name: "TestJob").exists?
      puts "✅ Solid Queue is working!"
    else
      puts "❌ Solid Queue not processing jobs"
    end
  end
end
```

### Step 3: Complete Cutover

```ruby
# Final configuration after verification
# config/application.rb
config.active_job.queue_adapter = :solid_queue
config.cache_store = :solid_cache_store
# config/cable.yml - switch to solid_cable

# Remove Redis gems from Gemfile
# bundle remove redis sidekiq
```

## Connection Pool Optimization

```ruby
# config/database.yml
production:
  primary:
    pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  queue:
    # Higher pool for job workers
    pool: <%= ENV.fetch("QUEUE_POOL_SIZE") { 20 } %>
  cache:
    # Lower pool for cache operations
    pool: <%= ENV.fetch("CACHE_POOL_SIZE") { 5 } %>
  cable:
    # Minimal pool for cable
    pool: <%= ENV.fetch("CABLE_POOL_SIZE") { 3 } %>

# config/puma.rb
workers ENV.fetch("WEB_CONCURRENCY") { 2 }
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count

# Ensure total connections don't exceed database limits
# PostgreSQL default max_connections = 100
# Total = (workers * threads * databases) + job_workers
# Example: (2 * 5 * 4) + 20 = 60 connections
```

## Performance Tuning

### SQLite Optimizations

```ruby
# config/initializers/sqlite_optimizations.rb
if Rails.configuration.database_configuration[Rails.env]["adapter"] == "sqlite3"
  Rails.application.config.after_initialize do
    ActiveRecord::Base.connection.execute("PRAGMA journal_mode = WAL")
    ActiveRecord::Base.connection.execute("PRAGMA synchronous = NORMAL")
    ActiveRecord::Base.connection.execute("PRAGMA cache_size = -64000")
    ActiveRecord::Base.connection.execute("PRAGMA temp_store = MEMORY")
    ActiveRecord::Base.connection.execute("PRAGMA mmap_size = 30000000000")
  end
end
```

### PostgreSQL Optimizations

```sql
-- Optimize for Solid Queue
ALTER DATABASE myapp_queue_production SET lock_timeout = '5s';
ALTER DATABASE myapp_queue_production SET statement_timeout = '30s';

-- Optimize for Solid Cache
ALTER DATABASE myapp_cache_production SET random_page_cost = 1.1;
ALTER DATABASE myapp_cache_production SET effective_cache_size = '4GB';
```

## Monitoring

```ruby
# app/controllers/admin/solid_status_controller.rb
class Admin::SolidStatusController < ApplicationController
  def index
    @status = {
      queue: {
        pending: SolidQueue::Job.pending.count,
        processing: SolidQueue::Job.processing.count,
        failed: SolidQueue::Job.failed.count,
        workers: SolidQueue::Process.workers.count
      },
      cache: {
        entries: SolidCache::Entry.count,
        size_mb: SolidCache::Entry.sum(:byte_size) / 1.megabyte,
        expired: SolidCache::Entry.expired.count
      },
      cable: {
        messages: SolidCable::Message.count,
        channels: SolidCable::Message.distinct.count(:channel)
      }
    }
  end
end
```

## Deployment with Kamal

```yaml
# config/deploy.yml
service: myapp

servers:
  web:
    - 192.168.1.1
  jobs:
    hosts:
      - 192.168.1.2
    cmd: bin/jobs start

env:
  SOLID_QUEUE_IN_PROCESS: false  # Run separately
  
accessories:
  postgres:
    image: postgres:16
    host: 192.168.1.3
    env:
      POSTGRES_DB: myapp_production,myapp_queue_production,myapp_cache_production,myapp_cable_production
```

## Troubleshooting Checklist

- [ ] Separate databases created for queue/cache/cable?
- [ ] Migrations run in correct databases?
- [ ] Connection pools sized appropriately?
- [ ] Workers/processes started for Solid Queue?
- [ ] Encryption keys set for Solid Cache?
- [ ] Polling intervals configured for Cable?
- [ ] Database optimizations applied?
- [ ] Monitoring endpoints working?

---

*Remember: The key to Solid trilogy success is proper database separation and connection pool management. Start with conservative settings and tune based on monitoring.*