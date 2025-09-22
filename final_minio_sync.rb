#!/usr/bin/env ruby

require_relative 'config/environment'
require 'aws-sdk-s3'
require 'logger'

logger = Logger.new(STDOUT)
logger.info "=" * 80
logger.info "FINAL MINIO SYNC"
logger.info "=" * 80
logger.info "Ensuring all MinIO objects match local files"
logger.info ""

# MinIO client
minio_client = Aws::S3::Client.new(
  endpoint: Rails.application.credentials.dig(:minio, :endpoint) || "https://s3-api.zice.app",
  access_key_id: Rails.application.credentials.dig(:minio, :access_key_id),
  secret_access_key: Rails.application.credentials.dig(:minio, :secret_access_key),
  region: Rails.application.credentials.dig(:minio, :region) || "jerBook",
  force_path_style: true
)

bucket_name = Rails.application.credentials.dig(:minio, :bucket) || "shock-collar-portraits-2025"

stats = {
  total: 0,
  checked: 0,
  already_good: 0,
  fixed: 0,
  failed: 0,
  uploaded_bytes: 0
}

logger.info "Processing all photos with attachments..."

# Process all photos that have attachments
Photo.joins(:image_attachment).includes(image_attachment: :blob).find_each do |photo|
  stats[:total] += 1

  blob = photo.image.blob
  next unless blob

  # Skip if not on MinIO
  unless blob.service_name == "minio"
    stats[:checked] += 1
    next
  end

  # Determine local file path
  session_day = photo.photo_session&.session_day&.day_name
  next unless session_day

  local_path = Rails.root.join("session_originals/#{session_day}/#{File.basename(photo.filename, '.*')}/#{photo.filename}")

  # Check if local file exists and is valid
  unless File.exist?(local_path) && File.size(local_path) > 0
    logger.warn "  ⚠️  No local file for Photo ##{photo.id}: #{photo.filename}"
    stats[:failed] += 1
    next
  end

  local_size = File.size(local_path)

  # Check MinIO object
  needs_upload = false
  begin
    obj = minio_client.head_object(bucket: bucket_name, key: blob.key)

    # Compare sizes
    if obj.content_length != local_size || obj.content_length == 0
      logger.info "  Size mismatch for #{photo.filename}: MinIO=#{obj.content_length}, Local=#{local_size}"
      needs_upload = true
    else
      stats[:already_good] += 1
    end
  rescue Aws::S3::Errors::NotFound
    logger.info "  Not in MinIO: #{photo.filename}"
    needs_upload = true
  end

  # Upload if needed
  if needs_upload
    begin
      File.open(local_path, "rb") do |file|
        minio_client.put_object(
          bucket: bucket_name,
          key: blob.key,
          body: file,
          content_type: blob.content_type || "image/jpeg",
          metadata: {
            filename: blob.filename.to_s,
            byte_size: blob.byte_size.to_s,
            checksum: blob.checksum,
            photo_id: photo.id.to_s
          }
        )
      end

      # Update blob byte_size if different
      if blob.byte_size != local_size
        blob.update!(byte_size: local_size)
      end

      stats[:fixed] += 1
      stats[:uploaded_bytes] += local_size
      logger.info "  ✅ Fixed: #{photo.filename} (#{(local_size/1024.0/1024.0).round(1)}MB)"
    rescue => e
      logger.error "  ❌ Failed to upload #{photo.filename}: #{e.message}"
      stats[:failed] += 1
    end
  end

  stats[:checked] += 1

  # Progress
  if stats[:checked] % 100 == 0
    logger.info "Progress: #{stats[:checked]}/#{stats[:total]} checked, #{stats[:fixed]} fixed"
  end
end

# Final report
logger.info ""
logger.info "=" * 80
logger.info "📊 SYNC COMPLETE"
logger.info "=" * 80
logger.info ""
logger.info "Results:"
logger.info "  Total photos: #{stats[:total]}"
logger.info "  Checked: #{stats[:checked]}"
logger.info "  Already good: #{stats[:already_good]}"
logger.info "  Fixed: #{stats[:fixed]}"
logger.info "  Failed: #{stats[:failed]}"
logger.info ""
logger.info "Data uploaded: #{(stats[:uploaded_bytes]/1024.0/1024.0/1024.0).round(2)}GB"
logger.info ""

if stats[:failed] == 0
  logger.info "✨ SUCCESS! All photos are properly synced to MinIO!"
  logger.info ""
  logger.info "You can now:"
  logger.info "1. Test the gallery at https://scp-25-dev.oknotok.com"
  logger.info "2. Close GitHub issue #1"
  logger.info "3. Cancel AWS S3 service"
else
  logger.info "⚠️  #{stats[:failed]} photos could not be synced"
  logger.info "These are likely the iPhone photos that are missing from local"
end

logger.info "=" * 80
