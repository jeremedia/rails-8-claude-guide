# Turbo 8 Morphing & Broadcasting Guide

*Complete guide to Turbo 8's revolutionary morphing and refresh broadcasting features*

## Overview

Turbo 8 (released February 2024) introduces two game-changing features:
1. **Page Morphing**: Updates pages by morphing only changed elements (via idiomorph)
2. **Refresh Broadcasting**: Models broadcast refresh signals instead of HTML

Result: Real-time updates with minimal code and preserved scroll/form state.

## Core Concepts

### Traditional Turbo (Pre-8)
```ruby
# Model broadcasts HTML fragments
broadcast_replace_to "posts", target: "post_#{id}", 
                     html: render_to_string(partial: "post")
# Problems: 
# - Renders HTML in background job
# - Sends large payloads over WebSocket
# - Complex partial management
```

### Turbo 8 Approach
```ruby
# Model broadcasts refresh signal only
broadcasts_refreshes
# Benefits:
# - No HTML rendering in jobs
# - Tiny WebSocket messages
# - Client fetches fresh page and morphs changes
```

## Quick Setup

### 1. Enable Morphing in Layout

```erb
<!-- app/views/layouts/application.html.erb -->
<!DOCTYPE html>
<html>
  <head>
    <%= turbo_refreshes_with method: :morph, scroll: :preserve %>
    <!-- This enables morphing for all refresh broadcasts -->
  </head>
  <body>
    <%= yield %>
  </body>
</html>
```

### 2. Add Broadcasting to Models

```ruby
# app/models/post.rb
class Post < ApplicationRecord
  # One line for real-time updates!
  broadcasts_refreshes
  
  # Or more control:
  broadcasts_refreshes_to ->(post) { "dashboard" }
  
  # Or conditional:
  broadcasts_refreshes if: :published?
end
```

### 3. Subscribe Views to Updates

```erb
<!-- app/views/posts/index.html.erb -->
<%= turbo_stream_from "posts" %>

<div id="posts">
  <% @posts.each do |post| %>
    <%= render post %>
  <% end %>
</div>
```

## Morphing Strategies

### Method 1: Global Morphing (Simplest)

```erb
<!-- Enable for entire app -->
<%= turbo_refreshes_with method: :morph, scroll: :preserve %>

<!-- All broadcasts will use morphing -->
```

### Method 2: Per-Page Morphing

```erb
<!-- app/views/posts/show.html.erb -->
<% content_for :head do %>
  <%= turbo_refreshes_with method: :morph, scroll: :preserve %>
<% end %>

<!-- Only this page uses morphing -->
```

### Method 3: Per-Element Control

```erb
<!-- Mix morphing and replace on same page -->
<div data-turbo-permanent="true" id="sidebar">
  <!-- Never morphed, always preserved -->
</div>

<div id="content">
  <!-- Morphed on refresh -->
</div>

<turbo-frame id="modal" data-turbo-action="replace">
  <!-- Always replaced, never morphed -->
</turbo-frame>
```

## Broadcasting Patterns

### Pattern 1: Simple CRUD

```ruby
# app/models/message.rb
class Message < ApplicationRecord
  belongs_to :chat
  
  # Broadcast to chat-specific stream
  broadcasts_refreshes_to ->(message) { message.chat }
  
  # Or broadcast to multiple streams
  after_create_commit do
    broadcast_refresh_to chat
    broadcast_refresh_to "unread_messages"
  end
end
```

### Pattern 2: Debounced Updates

```ruby
# app/models/document.rb
class Document < ApplicationRecord
  # Turbo 8 automatically debounces (0.5s default)
  broadcasts_refreshes
  
  # But you can customize
  after_update_commit do
    broadcast_refresh_later_to(
      "documents",
      wait: 2.seconds  # Custom debounce
    )
  end
end
```

### Pattern 3: Conditional Broadcasting

```ruby
# app/models/order.rb
class Order < ApplicationRecord
  # Only broadcast when status changes
  broadcasts_refreshes if: :status_previously_changed?
  
  # Or custom logic
  after_update_commit :maybe_broadcast
  
  private
  
  def maybe_broadcast
    if total_previously_changed? && total > 100
      broadcast_refresh_to "high_value_orders"
    end
  end
end
```

### Pattern 4: Multi-Model Coordination

```ruby
# app/models/project.rb
class Project < ApplicationRecord
  has_many :tasks
  
  broadcasts_refreshes_to ->(project) { "workspace_#{project.workspace_id}" }
end

# app/models/task.rb
class Task < ApplicationRecord
  belongs_to :project
  
  # Broadcast to same stream as project
  broadcasts_refreshes_to ->(task) { "workspace_#{task.project.workspace_id}" }
end

# Both update the same view!
```

## Form Preservation

### Preserving Form Input During Morphs

```erb
<!-- Form inputs are preserved by default during morphing -->
<%= form_with model: @post, id: "post_form" do |f| %>
  <%= f.text_field :title %>
  <%= f.text_area :content %>
  
  <!-- This input will keep its value during morphs -->
<% end %>

<!-- But you can opt out -->
<%= form_with model: @post, data: { turbo_permanent: false } do |f| %>
  <!-- This form will reset on morph -->
<% end %>
```

### Handling Validation Errors

```ruby
# app/controllers/posts_controller.rb
class PostsController < ApplicationController
  def update
    @post = Post.find(params[:id])
    
    if @post.update(post_params)
      # Success: morph will update the page
      redirect_to @post
    else
      # Error: morph preserves form with user input
      # Errors will appear without losing form data
      render :edit, status: :unprocessable_entity
    end
  end
end
```

## Advanced Idiomorph Configuration

### Custom Morph Configuration

```javascript
// app/javascript/application.js
import { Idiomorph } from '@hotwired/turbo/dist/turbo.es2017-esm'

// Configure idiomorph behavior
document.addEventListener('turbo:before-morph-element', (event) => {
  // Preserve certain attributes during morph
  if (event.target.hasAttribute('data-preserve-class')) {
    event.detail.newElement.className = event.target.className
  }
})

// Custom morph logic
document.addEventListener('turbo:before-morph-element', (event) => {
  const { target, newElement } = event.detail
  
  // Skip morphing for specific elements
  if (target.dataset.skipMorph) {
    event.preventDefault()
  }
  
  // Custom attribute preservation
  if (target.dataset.preserveStyle) {
    newElement.style.cssText = target.style.cssText
  }
})
```

### Morph Callbacks

```javascript
// app/javascript/morphing_callbacks.js

// Before morph starts
document.addEventListener('turbo:before-morph-element', (event) => {
  console.log('About to morph:', event.target)
})

// After morph completes
document.addEventListener('turbo:morph-element', (event) => {
  console.log('Morphed:', event.target)
  
  // Re-initialize JavaScript components
  if (event.target.dataset.component) {
    initializeComponent(event.target)
  }
})
```

## Real-World Examples

### Example 1: Live Dashboard

```ruby
# app/models/metric.rb
class Metric < ApplicationRecord
  broadcasts_refreshes_to "dashboard"
  
  # Update every minute from background job
end

# app/views/dashboard/show.html.erb
<%= turbo_stream_from "dashboard" %>
<%= turbo_refreshes_with method: :morph, scroll: :preserve %>

<div class="grid">
  <div class="metric-card">
    <h3>Revenue</h3>
    <p>$<%= number_with_delimiter(@revenue) %></p>
  </div>
  
  <div class="metric-card">
    <h3>Active Users</h3>
    <p><%= @active_users %></p>
  </div>
</div>

<!-- Updates automatically when any metric changes! -->
```

### Example 2: Collaborative Editor

```ruby
# app/models/document.rb
class Document < ApplicationRecord
  has_many :paragraphs
  
  broadcasts_refreshes
end

# app/models/paragraph.rb
class Paragraph < ApplicationRecord
  belongs_to :document, touch: true
  
  # Touching document triggers its broadcast
end

# app/views/documents/edit.html.erb
<%= turbo_stream_from @document %>
<%= turbo_refreshes_with method: :morph, scroll: :preserve %>

<div id="editor">
  <% @document.paragraphs.each do |paragraph| %>
    <div class="paragraph" data-id="<%= paragraph.id %>">
      <%= paragraph.content %>
    </div>
  <% end %>
</div>

<!-- Multiple users can edit, changes morph in real-time -->
```

### Example 3: Shopping Cart

```ruby
# app/models/cart.rb
class Cart < ApplicationRecord
  has_many :line_items
  
  broadcasts_refreshes_to ->(cart) { "cart_#{cart.session_id}" }
  
  def total
    line_items.sum(&:total)
  end
end

# app/views/carts/show.html.erb
<%= turbo_stream_from "cart_#{session.id}" %>
<%= turbo_refreshes_with method: :morph, scroll: :preserve %>

<div id="cart">
  <% @cart.line_items.each do |item| %>
    <div class="line-item">
      <%= item.product.name %>
      <%= form_with model: item, data: { turbo_frame: "_top" } do |f| %>
        <%= f.number_field :quantity, 
            onchange: "this.form.requestSubmit()" %>
      <% end %>
    </div>
  <% end %>
  
  <div class="total">
    Total: $<%= @cart.total %>
  </div>
</div>

<!-- Quantity changes update total without losing focus -->
```

## Performance Optimization

### 1. Debouncing Strategies

```ruby
# app/models/search_result.rb
class SearchResult < ApplicationRecord
  # Don't broadcast on every keystroke
  def self.update_results(query)
    # Use Rails cache for debouncing
    cache_key = "search_debounce_#{query}"
    
    unless Rails.cache.exist?(cache_key)
      Rails.cache.write(cache_key, true, expires_in: 0.5.seconds)
      
      # Perform search and broadcast
      results = perform_search(query)
      broadcast_refresh_to "search_results"
    end
  end
end
```

### 2. Selective Broadcasting

```ruby
# app/models/notification.rb
class Notification < ApplicationRecord
  # Only broadcast to relevant users
  broadcasts_refreshes_to ->(notification) { 
    "notifications_user_#{notification.user_id}"
  }
  
  # Don't broadcast system notifications
  broadcasts_refreshes unless: :system_generated?
end
```

### 3. Batch Updates

```ruby
# app/jobs/bulk_update_job.rb
class BulkUpdateJob < ApplicationJob
  def perform(record_ids)
    # Disable callbacks during bulk update
    Post.where(id: record_ids).update_all(
      status: "published",
      published_at: Time.current
    )
    
    # Single broadcast after all updates
    broadcast_refresh_to "posts"
  end
end
```

## Testing Morphing & Broadcasting

### System Tests

```ruby
# test/system/morphing_test.rb
class MorphingTest < ApplicationSystemTestCase
  test "updates preserve form input" do
    post = posts(:draft)
    visit edit_post_path(post)
    
    # Start typing
    fill_in "Title", with: "New Title in Progress"
    
    # Trigger background update
    post.update!(updated_at: Time.current)
    
    # Wait for morph
    sleep 0.6  # Debounce delay
    
    # Input should be preserved
    assert_field "Title", with: "New Title in Progress"
  end
end
```

### Broadcasting Tests

```ruby
# test/models/post_test.rb
class PostTest < ActiveSupport::TestCase
  include ActionCable::TestHelper
  
  test "broadcasts refresh on update" do
    post = posts(:published)
    
    assert_broadcast_on("posts", refresh: true) do
      post.update!(title: "Updated")
    end
  end
end
```

## Debugging Tips

```javascript
// Enable Turbo debugging
Turbo.session.drive = true
Turbo.setLogLevel("debug")

// Monitor morphing
document.addEventListener('turbo:morph', (e) => {
  console.log('Morphed elements:', e.detail.elements)
})

// Track broadcasts
document.addEventListener('turbo:before-stream-render', (e) => {
  console.log('Stream action:', e.detail.newStream.action)
})
```

## Common Gotchas

1. **Morphing doesn't work**: Check `turbo_refreshes_with` is in layout
2. **Forms reset on morph**: Add `data-turbo-permanent="true"`
3. **JavaScript breaks**: Re-initialize in `turbo:morph` event
4. **Too many updates**: Implement proper debouncing
5. **Scroll jumps**: Ensure `scroll: :preserve` is set

## Migration from Turbo 7

```ruby
# Before (Turbo 7)
class Post < ApplicationRecord
  after_update_commit do
    broadcast_replace_to "posts",
      target: "post_#{id}",
      partial: "posts/post",
      locals: { post: self }
  end
end

# After (Turbo 8)
class Post < ApplicationRecord
  broadcasts_refreshes_to "posts"
end
# That's it! 90% less code!
```

---

*Remember: Turbo 8 morphing is about sending signals, not HTML. Let the browser fetch and morph - it's faster, simpler, and preserves user state.*