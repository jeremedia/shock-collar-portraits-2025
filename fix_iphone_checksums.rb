#!/usr/bin/env ruby

require_relative 'config/environment'
require 'aws-sdk-s3'
require 'digest'
require 'logger'

logger = Logger.new(STDOUT)
logger.info "=" * 80
logger.info "FIXING IPHONE PHOTO CHECKSUMS"
logger.info "=" * 80
logger.info "Updating blob checksums to match actual JPG files in MinIO"
logger.info ""

# MinIO client
minio_client = Aws::S3::Client.new(
  endpoint: Rails.application.credentials.dig(:minio, :endpoint),
  access_key_id: Rails.application.credentials.dig(:minio, :access_key_id),
  secret_access_key: Rails.application.credentials.dig(:minio, :secret_access_key),
  region: Rails.application.credentials.dig(:minio, :region),
  force_path_style: true
)

bucket = Rails.application.credentials.dig(:minio, :bucket)

stats = {
  total: 0,
  fixed: 0,
  already_good: 0,
  failed: 0
}

# Find all iPhone photos (IMG_xxxx.jpg pattern)
iphone_photos = Photo.where("filename LIKE 'IMG_%.jpg'")
logger.info "Found #{iphone_photos.count} iPhone photos to check"
logger.info ""

iphone_photos.each do |photo|
  stats[:total] += 1

  unless photo.image.attached?
    logger.warn "  ⚠️  Photo ##{photo.id} (#{photo.filename}) has no attachment"
    stats[:failed] += 1
    next
  end

  blob = photo.image.blob

  # Skip if not on MinIO
  unless blob.service_name == "minio"
    logger.info "  Skipping #{photo.filename} - not on MinIO (#{blob.service_name})"
    next
  end

  begin
    # Get actual file from MinIO
    obj = minio_client.get_object(
      bucket: bucket,
      key: blob.key
    )

    # Calculate actual checksum and size
    content = obj.body.read
    actual_checksum = Digest::MD5.base64digest(content)
    actual_size = content.bytesize

    # Compare with stored values
    if blob.checksum == actual_checksum && blob.byte_size == actual_size
      stats[:already_good] += 1
      logger.debug "  ✓ #{photo.filename} - checksum matches"
    else
      # Update blob with correct values
      old_checksum = blob.checksum
      old_size = blob.byte_size

      blob.update!(
        checksum: actual_checksum,
        byte_size: actual_size
      )

      stats[:fixed] += 1
      logger.info "  ✅ Fixed #{photo.filename}:"
      logger.info "     Checksum: #{old_checksum[0..10]}... → #{actual_checksum[0..10]}..."
      logger.info "     Size: #{old_size} → #{actual_size} (#{(actual_size/1024.0/1024.0).round(1)}MB)"
    end

  rescue Aws::S3::Errors::NotFound
    logger.error "  ❌ #{photo.filename} - not found in MinIO"
    stats[:failed] += 1
  rescue => e
    logger.error "  ❌ #{photo.filename} - error: #{e.message}"
    stats[:failed] += 1
  end

  # Progress update
  if stats[:total] % 10 == 0
    logger.info "Progress: #{stats[:total]} checked, #{stats[:fixed]} fixed"
  end
end

# Final report
logger.info ""
logger.info "=" * 80
logger.info "📊 CHECKSUM FIX COMPLETE"
logger.info "=" * 80
logger.info ""
logger.info "Results:"
logger.info "  Total iPhone photos: #{stats[:total]}"
logger.info "  Fixed: #{stats[:fixed]}"
logger.info "  Already correct: #{stats[:already_good]}"
logger.info "  Failed: #{stats[:failed]}"
logger.info ""

if stats[:failed] == 0
  logger.info "✨ SUCCESS! All iPhone photo checksums are now correct!"
  logger.info ""
  logger.info "Next step: Generate variants for iPhone photos"
  logger.info "Run: rails runner 'Photo.where(\"filename LIKE ?\", \"IMG_%.jpg\").each(&:generate_variants)'"
else
  logger.info "⚠️  #{stats[:failed]} photos could not be fixed"
end

logger.info "=" * 80