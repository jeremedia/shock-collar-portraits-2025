#!/usr/bin/env ruby

require_relative 'config/environment'
require 'logger'

logger = Logger.new(STDOUT)
logger.info "=" * 80
logger.info "S3 VARIANT CLEANUP SCRIPT"
logger.info "=" * 80

# Safety check
logger.info "\n⚠️  WARNING: This will delete all variant blobs from the database!"
logger.info "Original photos (>1MB) will be preserved."
logger.info "Variants will regenerate from MinIO on demand."
print "\nType 'DELETE VARIANTS' to proceed: "

confirmation = STDIN.gets.chomp
unless confirmation == "DELETE VARIANTS"
  logger.info "Cancelled."
  exit
end

# Step 1: Count what we're dealing with
logger.info "\n📊 Analyzing blobs..."

total_blobs = ActiveStorage::Blob.count
s3_blobs = ActiveStorage::Blob.where(service_name: "amazon").count
minio_blobs = ActiveStorage::Blob.where(service_name: "minio").count

# Variants to delete (WebP + small JPEGs on S3)
webp_variants = ActiveStorage::Blob.where(content_type: "image/webp")
small_jpegs = ActiveStorage::Blob
  .where(service_name: "amazon", content_type: [ "image/jpeg" ])
  .where("byte_size < ?", 1_000_000)

variants_to_delete = webp_variants.or(small_jpegs)
variant_count = variants_to_delete.count

# Originals to keep
originals_on_s3 = ActiveStorage::Blob
  .where(service_name: "amazon", content_type: [ "image/jpeg", "image/heic" ])
  .where("byte_size >= ?", 1_000_000)
  .count

originals_on_minio = ActiveStorage::Blob
  .where(service_name: "minio")
  .where("byte_size >= ?", 1_000_000)
  .count

logger.info "  Total blobs: #{total_blobs}"
logger.info "  S3 blobs: #{s3_blobs}"
logger.info "  MinIO blobs: #{minio_blobs}"
logger.info ""
logger.info "  Variants to delete: #{variant_count}"
logger.info "    - WebP variants: #{webp_variants.count}"
logger.info "    - Small JPEGs (<1MB): #{small_jpegs.count}"
logger.info ""
logger.info "  Originals to preserve:"
logger.info "    - On S3: #{originals_on_s3}"
logger.info "    - On MinIO: #{originals_on_minio}"

# Step 2: Delete ActiveStorage::VariantRecord entries
logger.info "\n🗑️  Deleting variant records..."
variant_record_count = ActiveStorage::VariantRecord.count rescue 0

if variant_record_count > 0
  ActiveStorage::VariantRecord.in_batches(of: 1000) do |batch|
    batch.delete_all
    print "."
  end
  logger.info "\n  ✅ Deleted #{variant_record_count} variant records"
else
  logger.info "  No variant records found"
end

# Step 3: Delete variant blobs
logger.info "\n🗑️  Deleting variant blobs..."
deleted_count = 0
failed_count = 0
batch_size = 500

variants_to_delete.in_batches(of: batch_size) do |batch|
  begin
    # Delete associated attachments first (if any)
    blob_ids = batch.pluck(:id)
    ActiveStorage::Attachment.where(blob_id: blob_ids).delete_all

    # Delete the blobs
    batch.delete_all
    deleted_count += batch.size

    logger.info "  Deleted #{deleted_count}/#{variant_count} blobs..." if deleted_count % 5000 == 0
  rescue => e
    failed_count += batch.size
    logger.error "  Error deleting batch: #{e.message}"
  end
end

logger.info "  ✅ Deleted #{deleted_count} variant blobs"
logger.info "  ❌ Failed: #{failed_count}" if failed_count > 0

# Step 4: Final verification
logger.info "\n📈 Final Status:"

remaining_s3 = ActiveStorage::Blob.where(service_name: "amazon").count
remaining_webp = ActiveStorage::Blob.where(content_type: "image/webp").count
remaining_variants = ActiveStorage::VariantRecord.count rescue 0
current_minio = ActiveStorage::Blob.where(service_name: "minio").count
current_total = ActiveStorage::Blob.count

logger.info "  Total blobs now: #{current_total} (was #{total_blobs})"
logger.info "  Removed: #{total_blobs - current_total} blobs"
logger.info ""
logger.info "  Remaining on S3: #{remaining_s3}"
logger.info "  Remaining WebP: #{remaining_webp}"
logger.info "  Remaining variant records: #{remaining_variants}"
logger.info "  On MinIO: #{current_minio}"

if remaining_s3 > 0
  # Check what's left
  sample = ActiveStorage::Blob.where(service_name: "amazon").limit(5)
  logger.info "\n  Sample of remaining S3 blobs:"
  sample.each do |blob|
    logger.info "    - #{blob.filename} (#{(blob.byte_size/1024.0/1024.0).round(1)}MB)"
  end
end

logger.info "\n" + "=" * 80
logger.info "✨ CLEANUP COMPLETE!"
logger.info "=" * 80
logger.info "\nNext steps:"
logger.info "1. Restart Rails server to clear any cached services"
logger.info "2. Clear browser cache"
logger.info "3. Visit gallery - variants will regenerate from MinIO"
logger.info "4. Monitor first few variant generations for any issues"
logger.info "\n💡 Tip: First page load will be slower as variants regenerate"
