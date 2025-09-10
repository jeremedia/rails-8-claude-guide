# Rails 8.1 Beta Features Guide

*Released September 4, 2025 - Latest Rails innovations*

## Overview

Rails 8.1 Beta 1 introduces three major features that significantly improve production Rails applications:
- **Job Continuations**: Resumable long-running jobs
- **Structured Events**: Machine-readable logging system
- **Local CI**: Built-in continuous integration

This guide covers implementation patterns and migration strategies for each feature.

## Job Continuations

### Problem Solved
Long-running jobs traditionally fail completely when interrupted (deployments, restarts, crashes). With Kamal's 30-second shutdown grace period, complex jobs often can't complete, forcing full restarts from the beginning.

### How It Works

Jobs can now be broken into discrete steps that allow execution to continue from the last completed step:

```ruby
class DataMigrationJob < ApplicationJob
  include ActiveJob::Continuations
  
  def perform
    # Step 1: Export old data
    continuation.step(:export_data) do
      export_legacy_records
    end
    
    # Step 2: Transform data
    continuation.step(:transform_data) do
      transform_exported_records
    end
    
    # Step 3: Import to new system
    continuation.step(:import_data) do
      import_transformed_records
    end
    
    # Step 4: Cleanup
    continuation.step(:cleanup) do
      cleanup_temporary_files
    end
  end
  
  private
  
  def export_legacy_records
    LegacyRecord.find_in_batches(batch_size: 1000) do |batch|
      continuation.checkpoint # Save progress within step
      process_batch(batch)
    end
  end
end
```

### Configuration

```ruby
# config/application.rb
config.active_job.use_continuations = true

# Optional: Configure storage backend
config.active_job.continuations_store = :solid_cache # or :redis
```

### Best Practices

1. **Idempotent Steps**: Each step should be safe to retry
2. **Checkpoint Frequently**: Use `continuation.checkpoint` for progress within steps
3. **State Persistence**: Store necessary state between steps

```ruby
class ProcessOrdersJob < ApplicationJob
  include ActiveJob::Continuations
  
  def perform(start_date, end_date)
    continuation.step(:fetch_orders) do
      orders = Order.where(created_at: start_date..end_date)
      continuation.state[:order_ids] = orders.pluck(:id)
    end
    
    continuation.step(:process_orders) do
      order_ids = continuation.state[:order_ids]
      order_ids.each_slice(100) do |batch|
        continuation.checkpoint(processed: batch)
        process_batch(batch)
      end
    end
  end
end
```

### Monitoring

```ruby
# Check continuation status
job = DataMigrationJob.perform_later
job.continuation.current_step # => :transform_data
job.continuation.completed_steps # => [:export_data]
job.continuation.progress # => 45.2 (percentage)
```

## Structured Events

### Problem Solved
Rails default logger is human-readable but difficult to parse programmatically. Structured Events provide machine-readable logging for observability tools.

### Basic Usage

```ruby
# Notify an event
Rails.event.notify("user.signup", 
  user_id: user.id,
  email: user.email,
  plan: "premium",
  source: "organic"
)

# Add context tags
Rails.event.tagged("api", "v2") do
  Rails.event.notify("request.processed", 
    duration_ms: 125,
    status: 200
  )
end

# Set persistent context
Rails.event.set_context(
  request_id: SecureRandom.uuid,
  shop_id: Current.shop&.id,
  user_id: Current.user&.id
)
```

### Creating Custom Subscribers

```ruby
# app/subscribers/datadog_event_subscriber.rb
class DatadogEventSubscriber
  def emit(event)
    # Event hash includes:
    # - name: "user.signup"
    # - timestamp: Time.current
    # - tags: ["api", "v2"]
    # - context: { request_id: "...", shop_id: 123 }
    # - data: { user_id: 456, email: "..." }
    
    Datadog::Statsd.new.event(
      event[:name],
      event[:data].to_json,
      tags: build_tags(event)
    )
  end
  
  private
  
  def build_tags(event)
    event[:tags] + event[:context].map { |k, v| "#{k}:#{v}" }
  end
end

# config/initializers/events.rb
Rails.event.subscribe(DatadogEventSubscriber.new)
```

### Integration with Controllers

```ruby
class ApplicationController < ActionController::Base
  around_action :set_event_context
  
  private
  
  def set_event_context
    Rails.event.set_context(
      request_id: request.request_id,
      session_id: session.id,
      ip: request.remote_ip
    )
    
    Rails.event.tagged(controller_name, action_name) do
      yield
    end
  ensure
    Rails.event.clear_context
  end
end

class UsersController < ApplicationController
  def create
    @user = User.new(user_params)
    
    if @user.save
      Rails.event.notify("user.created",
        user_id: @user.id,
        referrer: request.referrer,
        utm_source: params[:utm_source]
      )
      redirect_to @user
    else
      Rails.event.notify("user.creation_failed",
        errors: @user.errors.full_messages,
        params: user_params.keys
      )
      render :new
    end
  end
end
```

### Structured Events in Jobs

```ruby
class ProcessPaymentJob < ApplicationJob
  def perform(order_id)
    order = Order.find(order_id)
    
    Rails.event.tagged("payment", "stripe") do
      Rails.event.notify("payment.started",
        order_id: order.id,
        amount_cents: order.total_cents
      )
      
      begin
        charge = process_stripe_payment(order)
        
        Rails.event.notify("payment.succeeded",
          order_id: order.id,
          charge_id: charge.id,
          processing_time_ms: charge.processing_time
        )
      rescue Stripe::CardError => e
        Rails.event.notify("payment.failed",
          order_id: order.id,
          error: e.message,
          error_code: e.code
        )
        raise
      end
    end
  end
end
```

## Local CI

### Problem Solved
Eliminates dependency on cloud CI services for small-to-mid-sized applications, enabling faster feedback loops and reduced costs.

### Setup

```ruby
# config/ci.rb
ci do
  # Image configuration
  image "ruby:3.3.5"
  
  # Service dependencies
  service "postgres:16" do
    env DATABASE_URL: "postgresql://postgres:postgres@postgres:5432/myapp_test"
  end
  
  service "redis:7" do
    env REDIS_URL: "redis://redis:6379/1"
  end
  
  # Environment setup
  env do
    RAILS_ENV: "test"
    CI: "true"
  end
  
  # Cache configuration
  cache "vendor/bundle", "node_modules"
  
  # CI steps
  setup do
    run "bundle install"
    run "yarn install"
    run "bin/rails db:create db:schema:load"
  end
  
  # Test suites
  test "unit" do
    run "bin/rails test"
  end
  
  test "system" do
    run "bin/rails test:system"
  end
  
  test "lint" do
    run "bundle exec rubocop"
    run "yarn lint"
  end
  
  # Optional: Only on main branch
  deploy do
    branch "main"
    run "kamal deploy"
  end
end
```

### Running Local CI

```bash
# Run all CI checks
bin/ci

# Run specific test suite
bin/ci test unit

# Run with GitHub integration
bin/ci --github

# Dry run (show commands without executing)
bin/ci --dry-run
```

### GitHub Integration

```yaml
# .github/workflows/ci.yml (auto-generated)
name: CI
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - run: bin/ci
```

### Parallel Execution

```ruby
# config/ci.rb
ci do
  # Run tests in parallel
  parallel workers: 4
  
  test "models" do
    parallel_run "bin/rails test test/models"
  end
  
  test "controllers" do
    parallel_run "bin/rails test test/controllers"
  end
  
  test "system" do
    parallel_run "bin/rails test:system", workers: 2
  end
end
```

## Migration from Rails 8.0

### Upgrading to Rails 8.1 Beta

```ruby
# Gemfile
gem "rails", "~> 8.1.0.beta1"

# Bundle update
bundle update rails

# Run update task
bin/rails app:update
```

### Adopting Job Continuations

```ruby
# Before: Standard job
class LegacyJob < ApplicationJob
  def perform(user_id)
    user = User.find(user_id)
    process_user_data(user)
    send_notifications(user)
    update_analytics(user)
  end
end

# After: With continuations
class ModernJob < ApplicationJob
  include ActiveJob::Continuations
  
  def perform(user_id)
    continuation.step(:process_data) do
      user = User.find(user_id)
      process_user_data(user)
    end
    
    continuation.step(:notify) do
      user = User.find(user_id)
      send_notifications(user)
    end
    
    continuation.step(:analytics) do
      user = User.find(user_id)
      update_analytics(user)
    end
  end
end
```

### Migrating Logging to Structured Events

```ruby
# Before: Traditional logging
Rails.logger.info "User #{user.id} signed up from #{request.ip}"

# After: Structured events
Rails.event.notify("user.signup",
  user_id: user.id,
  ip_address: request.ip,
  timestamp: Time.current
)
```

## Performance Implications

### Job Continuations
- **Overhead**: ~5-10ms per checkpoint
- **Storage**: ~1KB per continuation state
- **Best for**: Jobs > 30 seconds, batch processing

### Structured Events
- **Overhead**: < 1ms per event
- **Storage**: Depends on subscriber implementation
- **Best for**: All production applications

### Local CI
- **Speed**: 2-3x faster than cloud CI for small projects
- **Cost**: $0 (vs $50-500/month for cloud CI)
- **Best for**: Teams < 20 developers

## Common Patterns

### Resilient Data Processing

```ruby
class ResilientDataProcessor < ApplicationJob
  include ActiveJob::Continuations
  
  def perform(dataset_id)
    dataset = Dataset.find(dataset_id)
    
    continuation.step(:validate) do
      raise "Invalid dataset" unless dataset.valid_for_processing?
      continuation.state[:validated_at] = Time.current
    end
    
    continuation.step(:process) do
      dataset.records.find_in_batches(batch_size: 100) do |batch|
        continuation.checkpoint(last_id: batch.last.id)
        ProcessBatch.call(batch)
      end
    end
    
    continuation.step(:finalize) do
      dataset.update!(
        processed_at: Time.current,
        validation_time: continuation.state[:validated_at]
      )
    end
  end
end
```

### Comprehensive Event Tracking

```ruby
module EventTracking
  extend ActiveSupport::Concern
  
  included do
    after_create :track_creation
    after_update :track_update
    after_destroy :track_destruction
  end
  
  private
  
  def track_creation
    Rails.event.notify("#{model_name.singular}.created",
      id: id,
      attributes: attributes
    )
  end
  
  def track_update
    Rails.event.notify("#{model_name.singular}.updated",
      id: id,
      changes: previous_changes
    )
  end
  
  def track_destruction
    Rails.event.notify("#{model_name.singular}.destroyed",
      id: id,
      attributes: attributes
    )
  end
end

class User < ApplicationRecord
  include EventTracking
end
```

---

*Rails 8.1 Beta represents a significant step forward in production Rails capabilities. These features reduce infrastructure dependencies while improving observability and resilience.*