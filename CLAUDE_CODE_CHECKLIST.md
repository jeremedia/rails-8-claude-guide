# Claude Code Rails 8 Checklist

## START HERE - Before Making ANY Rails 8 Changes

### 1. Check Your Knowledge Gap
```
My training data ends: April 2024
Rails 8 released: November 2024
Status: I DON'T HAVE RAILS 8 IN MY TRAINING DATA
```

### 2. Before Changing Active Storage Config

**STOP AND CHECK:**
- [ ] Will this change variant URLs?
- [ ] Will this trigger variant regeneration?
- [ ] What's the cost in S3 operations?
- [ ] Have I tested this in development first?

### 3. Active Storage Decision Tree

```
Are images public?
├── YES → Use redirect mode + public: true in storage.yml
│         (Best performance, direct S3 access)
└── NO → Use redirect mode + signed URLs
         (Only use proxy mode for specific protected routes)
```

### 4. The Golden Rules

1. **NEVER** set global proxy mode for public images
2. **ALWAYS** test variant changes in development
3. **READ** the source code when docs are unclear
4. **ADMIT** when you don't know something
5. **CHECK** costs before bulk operations

### 5. Quick Variant Debug

```ruby
# Check if variants will regenerate
photo = Photo.first
old_digest = photo.image.variant(:thumb).variation.digest

# Make your config change here
Rails.application.reload!

new_digest = photo.image.variant(:thumb).variation.digest
puts "Will regenerate: #{old_digest != new_digest}"
```

### 6. Emergency Fixes

If you've broken variant generation:

```ruby
# 1. Check what mode you're in
Rails.application.config.active_storage.resolve_model_to_route

# 2. Check storage configuration
Rails.application.config.active_storage.service

# 3. Count existing variants
ActiveStorage::VariantRecord.count

# 4. DON'T PANIC - variants can be regenerated
# But it costs time and money
```

### 7. Essential Commands

```bash
# Check S3 costs
aws s3 ls s3://bucket-name --recursive --summarize

# Monitor variant processing
tail -f log/development.log | grep -E "VariantRecord|TransformJob"

# Quick variant status
rails runner "puts ActiveStorage::VariantRecord.count"
```

### 8. When In Doubt

1. **Read the guide**: https://github.com/jeremedia/rails-8-claude-guide
2. **Check the source**: https://github.com/rails/rails/tree/main/activestorage
3. **Test small first**: Try with one image before processing thousands
4. **Ask for help**: Admit uncertainty rather than guess

---

**Remember**: Every variant regeneration = real money spent on S3 operations.

Think twice, code once.