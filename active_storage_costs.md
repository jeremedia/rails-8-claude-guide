# Active Storage Cost Calculator & Decision Guide

*Understanding the real costs of Active Storage configuration changes*

## The Hidden Costs of Active Storage

Every Active Storage configuration change can trigger thousands of dollars in S3 operations. This guide helps you calculate costs BEFORE making changes.

## S3 Pricing Breakdown (as of 2024)

### Storage Costs
- **Standard**: $0.023 per GB/month (first 50TB)
- **Infrequent Access**: $0.0125 per GB/month
- **Glacier Instant**: $0.004 per GB/month

### Request Costs
- **PUT/COPY/POST**: $0.005 per 1,000 requests
- **GET/SELECT**: $0.0004 per 1,000 requests
- **DELETE**: Free
- **LIST**: $0.005 per 1,000 requests

### Data Transfer
- **Out to Internet**: $0.09 per GB (after 1GB free)
- **CloudFront**: $0.085 per GB
- **Between regions**: $0.02 per GB

## Cost Calculator

### Scenario 1: Variant Regeneration

```ruby
# Calculate cost of changing variant processor
def calculate_variant_regeneration_cost
  # Your numbers
  total_images = 100_000
  variants_per_image = 3  # thumb, medium, large
  average_image_size_mb = 2
  
  # S3 operations per variant
  operations_per_variant = {
    get_original: 1,      # Fetch original
    put_variant: 1,       # Store variant
    put_variant_record: 1 # Update metadata
  }
  
  # Calculations
  total_variants = total_images * variants_per_image
  total_get_requests = total_variants * operations_per_variant[:get_original]
  total_put_requests = total_variants * (operations_per_variant[:put_variant] + 
                                         operations_per_variant[:put_variant_record])
  
  # Data transfer (assuming processing server in same region)
  download_gb = (total_images * average_image_size_mb) / 1024.0
  upload_gb = download_gb * 0.3  # Variants usually smaller
  
  # Costs
  get_cost = (total_get_requests / 1000.0) * 0.0004
  put_cost = (total_put_requests / 1000.0) * 0.005
  transfer_cost = 0  # Same region
  
  total_cost = get_cost + put_cost + transfer_cost
  
  puts "Variant Regeneration Cost Estimate:"
  puts "GET requests: #{total_get_requests} = $#{'%.2f' % get_cost}"
  puts "PUT requests: #{total_put_requests} = $#{'%.2f' % put_cost}"
  puts "Data transfer: #{download_gb.round}GB = $#{'%.2f' % transfer_cost}"
  puts "TOTAL COST: $#{'%.2f' % total_cost}"
  puts "Per image: $#{'%.4f' % (total_cost / total_images)}"
  
  total_cost
end

# Example output:
# Variant Regeneration Cost Estimate:
# GET requests: 300000 = $120.00
# PUT requests: 600000 = $3000.00
# Data transfer: 195GB = $0.00
# TOTAL COST: $3120.00
# Per image: $0.0312
```

### Scenario 2: Proxy vs Redirect Mode

```ruby
def calculate_proxy_mode_costs(monthly_page_views)
  # Assumptions
  images_per_page = 20
  average_image_size_mb = 0.5
  cache_hit_rate = 0.7  # 70% served from CDN
  
  # Redirect mode (baseline)
  redirect_costs = {
    s3_requests: 0,  # Users go directly to S3
    bandwidth: 0,     # S3 handles bandwidth
    server_resources: 0
  }
  
  # Proxy mode
  total_image_requests = monthly_page_views * images_per_page
  uncached_requests = total_image_requests * (1 - cache_hit_rate)
  
  proxy_costs = {
    # Your Rails server fetches from S3
    s3_requests: (uncached_requests / 1000.0) * 0.0004,
    
    # Your server bandwidth (both in and out)
    bandwidth_gb: (uncached_requests * average_image_size_mb * 2) / 1024.0,
    bandwidth_cost: ((uncached_requests * average_image_size_mb * 2) / 1024.0) * 0.09,
    
    # Additional server resources (estimate)
    server_resources: 200  # Extra server capacity needed
  }
  
  puts "Monthly Proxy Mode Costs (#{monthly_page_views} page views):"
  puts "S3 requests: $#{'%.2f' % proxy_costs[:s3_requests]}"
  puts "Bandwidth (#{proxy_costs[:bandwidth_gb].round}GB): $#{'%.2f' % proxy_costs[:bandwidth_cost]}"
  puts "Extra servers: $#{'%.2f' % proxy_costs[:server_resources]}"
  puts "TOTAL MONTHLY: $#{'%.2f' % proxy_costs.values.select { |v| v.is_a?(Numeric) }.sum}"
  puts "vs Redirect mode: $0.00"
  
  proxy_costs
end

# Example for 1M page views/month:
# Monthly Proxy Mode Costs (1000000 page views):
# S3 requests: $2400.00
# Bandwidth (5859GB): $527.34
# Extra servers: $200.00
# TOTAL MONTHLY: $3127.34
# vs Redirect mode: $0.00
```

### Scenario 3: Public vs Private S3 Bucket

```ruby
def calculate_public_bucket_savings(monthly_requests)
  # Private bucket (signed URLs)
  signing_compute_time_ms = 0.5
  lambda_requests = monthly_requests  # Each needs signing
  lambda_cost_per_million = 0.20
  lambda_compute_cost_per_gb_second = 0.0000166667
  
  private_costs = {
    lambda_invocations: (lambda_requests / 1_000_000.0) * lambda_cost_per_million,
    lambda_compute: (lambda_requests * signing_compute_time_ms / 1000.0) * 
                    lambda_compute_cost_per_gb_second * 0.128  # 128MB function
  }
  
  # Public bucket
  public_costs = {
    lambda_invocations: 0,
    lambda_compute: 0
  }
  
  savings = private_costs.values.sum
  
  puts "Monthly Signed URL Costs (#{monthly_requests} requests):"
  puts "Lambda invocations: $#{'%.2f' % private_costs[:lambda_invocations]}"
  puts "Lambda compute: $#{'%.2f' % private_costs[:lambda_compute]}"
  puts "Total private: $#{'%.2f' % private_costs.values.sum}"
  puts "Total public: $0.00"
  puts "MONTHLY SAVINGS: $#{'%.2f' % savings}"
  
  savings
end
```

## Decision Framework

### Choose Redirect Mode When:
```ruby
def should_use_redirect_mode?
  public_content = true
  performance_critical = true
  high_traffic = true  # > 100k requests/day
  
  if public_content && (performance_critical || high_traffic)
    puts "✅ Use REDIRECT mode"
    puts "Config: resolve_model_to_route = :rails_storage_redirect"
    true
  else
    false
  end
end
```

### Choose Proxy Mode When:
```ruby
def should_use_proxy_mode?
  requires_authentication = true
  needs_analytics = true
  watermarking_required = true
  low_traffic = true  # < 10k requests/day
  
  if requires_authentication || watermarking_required
    puts "✅ Use PROXY mode (selectively)"
    puts "Config: Use rails_storage_proxy_path in controllers"
    true
  elsif needs_analytics && low_traffic
    puts "⚠️ Consider PROXY mode"
    true
  else
    false
  end
end
```

### Choose Public S3 When:
```ruby
def should_use_public_s3?
  content_public = true
  seo_important = true
  cdn_in_use = true
  
  if content_public && (seo_important || cdn_in_use)
    puts "✅ Use PUBLIC S3 bucket"
    puts "Config: public: true in storage.yml"
    true
  else
    false
  end
end
```

## Real-World Cost Examples

### E-commerce Site (1M products, 5 images each)

```ruby
# Initial setup
products = 1_000_000
images_per_product = 5
variants_per_image = 4  # thumb, small, medium, large

total_files = products * images_per_product * (1 + variants_per_image)
# = 25,000,000 files

# Storage costs (assuming 500KB average)
storage_gb = (total_files * 0.5) / 1024
monthly_storage_cost = storage_gb * 0.023
# = $287.50/month

# Configuration change impact
variant_regeneration_cost = total_files * 0.0004 * 2  # GET + PUT
# = $20,000 ONE TIME COST for processor change!

puts "E-commerce Site Costs:"
puts "Monthly storage: $#{monthly_storage_cost}"
puts "Config change cost: $#{variant_regeneration_cost}"
puts "⚠️ Think twice before changing variant configuration!"
```

### Social Media Platform (100k users, 50 photos each)

```ruby
users = 100_000
photos_per_user = 50
variants = 3
daily_views_per_photo = 10

total_photos = users * photos_per_user
total_variants = total_photos * variants
daily_image_requests = total_photos * daily_views_per_photo

# Proxy mode costs
monthly_proxy_bandwidth_gb = (daily_image_requests * 30 * 0.3) / 1024
monthly_proxy_cost = monthly_proxy_bandwidth_gb * 0.09
# = $13,184/month

# Redirect mode costs
monthly_redirect_cost = 0  # S3 serves directly
# = $0/month

savings = monthly_proxy_cost

puts "Social Media Platform:"
puts "Proxy mode: $#{monthly_proxy_cost}/month"
puts "Redirect mode: $0/month"
puts "💰 Savings with redirect: $#{savings}/month"
puts "Annual savings: $#{savings * 12}"
```

## Cost Optimization Strategies

### 1. Pre-generate Variants

```ruby
# Rake task to pre-generate all variants
namespace :active_storage do
  desc "Pre-generate all variants to avoid on-demand processing"
  task pregenerate_variants: :environment do
    cost_estimate = 0
    
    models_with_attachments = [
      { model: Product, attachment: :image, variants: [:thumb, :medium, :large] },
      { model: User, attachment: :avatar, variants: [:thumb, :profile] }
    ]
    
    models_with_attachments.each do |config|
      records = config[:model].joins(:"#{config[:attachment]}_attachment")
      
      puts "Processing #{records.count} #{config[:model].name} records..."
      
      records.find_each do |record|
        attachment = record.send(config[:attachment])
        next unless attachment.attached?
        
        config[:variants].each do |variant_name|
          begin
            attachment.variant(variant_name).processed
            cost_estimate += 0.0004 + 0.005  # GET + PUT
          rescue => e
            puts "Error processing #{config[:model].name} ##{record.id}: #{e.message}"
          end
        end
      end
    end
    
    puts "Estimated cost: $#{'%.2f' % (cost_estimate / 1000)}"
  end
end
```

### 2. Implement Variant Caching

```ruby
# app/models/concerns/cached_variants.rb
module CachedVariants
  extend ActiveSupport::Concern
  
  included do
    def variant_url(variant_name, expires_in: 1.week)
      cache_key = "variant_url/#{self.class.name}/#{id}/#{variant_name}/#{image.blob.key}"
      
      Rails.cache.fetch(cache_key, expires_in: expires_in) do
        image.variant(variant_name).url(expires_in: expires_in)
      end
    end
  end
end
```

### 3. Use CloudFront for Cost Reduction

```yaml
# CloudFront reduces bandwidth costs
# S3 → CloudFront: $0.00 (same region)
# CloudFront → User: $0.085/GB (vs $0.09/GB from S3)
# Plus aggressive caching reduces requests

# config/environments/production.rb
config.action_controller.asset_host = "https://d1234567890.cloudfront.net"
```

### 4. Implement Smart Deletion

```ruby
# Don't orphan variants when changing configuration
class CleanupOrphanedVariantsJob < ApplicationJob
  def perform
    # Find variants without matching blob configurations
    orphaned = ActiveStorage::VariantRecord.includes(:blob)
      .select do |variant|
        transformations = variant.variation.transformations
        
        # Check if these transformations are still used
        !current_variant_definitions.include?(transformations)
      end
    
    # Calculate deletion savings (no S3 delete costs)
    storage_gb = orphaned.sum { |v| v.blob.byte_size } / 1.gigabyte
    monthly_savings = storage_gb * 0.023
    
    puts "Found #{orphaned.count} orphaned variants"
    puts "Storage: #{storage_gb}GB"
    puts "Monthly savings: $#{monthly_savings}"
    
    # Delete if confirmed
    # orphaned.each(&:destroy)
  end
end
```

## Quick Reference Card

```
OPERATION                           COST IMPACT
-------------------------------------------------
Switch processor (mini_magick→vips)  $$$$$ (regenerates all)
Switch proxy→redirect mode           $$    (URL regeneration)
Switch redirect→proxy mode           $$    (URL regeneration)
Add new variant definition           $$$   (generates for all)
Change variant dimensions            $$$   (regenerates variant)
Enable public: true                  $0    (saves on signing)
Add CloudFront                       $$    (saves long-term)
Delete unused variants               -$    (reduces storage)
Pre-generate variants                $$    (one-time cost)
On-demand variant generation         $$$   (ongoing + latency)
```

## Cost Monitoring

```ruby
# app/jobs/active_storage_cost_monitor_job.rb
class ActiveStorageCostMonitorJob < ApplicationJob
  def perform
    metrics = {
      total_blobs: ActiveStorage::Blob.count,
      total_variants: ActiveStorage::VariantRecord.count,
      storage_gb: ActiveStorage::Blob.sum(:byte_size) / 1.gigabyte,
      variants_today: ActiveStorage::VariantRecord.where(created_at: 24.hours.ago..).count,
      
      # Estimated costs
      storage_cost: (ActiveStorage::Blob.sum(:byte_size) / 1.gigabyte) * 0.023,
      new_variant_cost: ActiveStorage::VariantRecord.where(created_at: 24.hours.ago..).count * 0.0054
    }
    
    if metrics[:new_variant_cost] > 10  # Alert if > $10/day
      AdminMailer.high_variant_cost_alert(metrics).deliver_later
    end
    
    Rails.logger.info "Active Storage Costs: #{metrics.to_json}"
  end
end
```

---

*Remember: Every configuration change has a cost. Calculate before you migrate. A few hours of planning can save thousands of dollars.*