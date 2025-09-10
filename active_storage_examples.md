# Active Storage Rails 8 Examples & Patterns

## Correct Patterns

### 1. Public Image Gallery (Best Performance)

```yaml
# config/storage.yml
amazon_public:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
  region: us-west-2
  bucket: my-public-images
  public: true  # ✅ Direct S3 URLs, no signatures
```

```ruby
# config/application.rb
# ✅ Keep default redirect mode for performance
# config.active_storage.resolve_model_to_route = :rails_storage_redirect # DEFAULT

# app/models/photo.rb
class Photo < ApplicationRecord
  has_one_attached :image do |attachable|
    attachable.variant :thumb, resize_to_limit: [300, 300], format: :webp
    attachable.variant :large, resize_to_limit: [1920, 1920], format: :webp
  end
end

# app/views/gallery/show.html.erb
# ✅ Images load directly from S3
<%= image_tag photo.image.variant(:thumb) %>
```

### 2. Protected User Avatars (Security Required)

```yaml
# config/storage.yml  
amazon_private:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
  region: us-west-2
  bucket: my-private-files
  public: false  # ✅ Signed URLs for security
```

```ruby
# app/controllers/avatars_controller.rb
class AvatarsController < ApplicationController
  before_action :authenticate_user!
  
  def show
    @user = User.find(params[:id])
    
    # ✅ Use proxy selectively for sensitive content
    if current_user.can_view?(@user)
      redirect_to rails_storage_proxy_path(@user.avatar.variant(:medium))
    else
      head :forbidden
    end
  end
end
```

### 3. Batch Processing Variants

```ruby
# lib/tasks/variants.rake
namespace :variants do
  desc "Preprocess all variants to avoid on-demand generation"
  task preprocess: :environment do
    Photo.find_each do |photo|
      next unless photo.image.attached?
      
      # ✅ Process variants in background job
      VariantPreprocessJob.perform_later(photo)
    end
  end
end

# app/jobs/variant_preprocess_job.rb
class VariantPreprocessJob < ApplicationJob
  def perform(photo)
    return unless photo.image.attached?
    
    # Force variant generation
    photo.image.variant(:thumb).processed
    photo.image.variant(:large).processed
  rescue => e
    Rails.logger.error "Failed to process variants for Photo #{photo.id}: #{e.message}"
  end
end
```

## Common Anti-Patterns to Avoid

### ❌ Anti-Pattern 1: Global Proxy Mode for Public Images

```ruby
# config/application.rb
# ❌ NEVER DO THIS for public images
config.active_storage.resolve_model_to_route = :rails_storage_proxy

# Why it's bad:
# - Every image request goes through Rails
# - Rails downloads from S3, then streams to user
# - Massive performance hit
# - Unnecessary server load
```

### ❌ Anti-Pattern 2: Changing Processor Mid-Project

```ruby
# Initial configuration
Rails.application.config.active_storage.variant_processor = :mini_magick

# Later change - ❌ THIS REGENERATES ALL VARIANTS
Rails.application.config.active_storage.variant_processor = :vips

# Result: All existing variants become invalid
# Cost: Reprocessing thousands of images
```

### ❌ Anti-Pattern 3: Inconsistent Variant Definitions

```ruby
# ❌ DON'T define variants inline differently
<%= image_tag photo.image.variant(resize_to_limit: [300, 300]) %>
<%= image_tag photo.image.variant(resize: "300x300") %>
<%= image_tag photo.image.variant(resize_to_fit: [300, 300]) %>

# These create THREE different variants!

# ✅ DO: Define once in model
class Photo < ApplicationRecord
  has_one_attached :image do |attachable|
    attachable.variant :thumb, resize_to_limit: [300, 300]
  end
end

# Use consistently
<%= image_tag photo.image.variant(:thumb) %>
```

## Understanding Variant Keys

### What Creates a New Variant

```ruby
# Each of these creates a DIFFERENT variant:
variant(resize_to_limit: [300, 300])
variant(resize_to_limit: [300, 300], format: :webp)
variant(resize_to_limit: [300, 300], format: :webp, saver: { quality: 80 })

# The digest is calculated from ALL transformation parameters
```

### Checking Variant Existence

```ruby
# Rails console debugging
photo = Photo.first
variant = photo.image.variant(:thumb)

# Check if processed
variant.send(:processed?)

# Get the variant key
variant.key
# => "variants/5xwj.../abc123..."

# Check variant record
ActiveStorage::VariantRecord.find_by(
  blob_id: photo.image.blob.id,
  variation_digest: variant.variation.digest
)
```

## Service Worker Caching (When Proxy Mode Required)

```javascript
// public/sw.js
// Only works with proxy mode or public S3 bucket

self.addEventListener('fetch', event => {
  const url = event.request.url;
  
  // Cache Active Storage URLs
  if (url.includes('/rails/active_storage/')) {
    event.respondWith(
      caches.open('images-v1').then(cache => {
        return cache.match(event.request).then(response => {
          return response || fetch(event.request).then(response => {
            // Only cache successful responses
            if (response.ok) {
              cache.put(event.request, response.clone());
            }
            return response;
          });
        });
      })
    );
  }
});
```

## Debugging Variant Issues

### 1. Find Orphaned Variants

```ruby
# Rails console
# Find variant records without matching blobs
orphaned = ActiveStorage::VariantRecord
  .joins(:blob)
  .where.not(
    id: ActiveStorage::VariantRecord
      .joins(:blob)
      .joins("INNER JOIN active_storage_attachments ON active_storage_attachments.blob_id = active_storage_blobs.id")
      .select(:id)
  )

puts "Found #{orphaned.count} orphaned variants"
```

### 2. Check S3 Costs

```ruby
# lib/tasks/storage_audit.rake
namespace :storage do
  desc "Audit S3 storage usage"
  task audit: :environment do
    # Original files
    original_size = ActiveStorage::Blob.sum(:byte_size)
    
    # Variants (approximate)
    variant_count = ActiveStorage::VariantRecord.count
    avg_variant_size = 500_000 # 500KB estimate
    variant_size = variant_count * avg_variant_size
    
    puts "Storage Audit:"
    puts "Original files: #{(original_size / 1.gigabyte).round(2)} GB"
    puts "Variants (est): #{(variant_size / 1.gigabyte).round(2)} GB"
    puts "Total (est): #{((original_size + variant_size) / 1.gigabyte).round(2)} GB"
    puts "Variant count: #{variant_count}"
  end
end
```

### 3. Force Variant Regeneration

```ruby
# Only if absolutely necessary
photo.image.variant(:thumb).blob.purge
photo.image.variant(:thumb).processed # Regenerates
```

## Performance Optimization

### 1. CDN Integration

```ruby
# config/environments/production.rb
config.action_controller.asset_host = "https://cdn.example.com"

# With CloudFront
Rails.application.routes.default_url_options[:host] = "https://cdn.example.com"
```

### 2. Lazy Loading

```erb
<!-- app/views/gallery/index.html.erb -->
<% @photos.each do |photo| %>
  <%= image_tag photo.image.variant(:thumb), 
                loading: "lazy",
                class: "gallery-thumb" %>
<% end %>
```

### 3. Responsive Images

```erb
<%= picture_tag photo.image.variant(:large),
    sources: [
      { 
        srcset: photo.image.variant(:mobile),
        media: "(max-width: 768px)"
      },
      {
        srcset: photo.image.variant(:tablet),
        media: "(max-width: 1024px)"
      }
    ] %>
```

## Monitoring & Alerts

```ruby
# app/jobs/variant_monitor_job.rb
class VariantMonitorJob < ApplicationJob
  def perform
    unprocessed = Photo.joins(:image_attachment)
                       .where.not(
                         id: ActiveStorage::VariantRecord
                              .select(:blob_id)
                              .distinct
                       )
    
    if unprocessed.count > 100
      Rails.logger.error "⚠️ #{unprocessed.count} photos without variants!"
      # Send alert to monitoring service
    end
  end
end
```

---

Remember: The key to Active Storage success is understanding what triggers variant regeneration and planning accordingly. Test configuration changes in development first!