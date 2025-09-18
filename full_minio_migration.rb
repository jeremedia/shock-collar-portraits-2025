#!/usr/bin/env ruby

require_relative 'config/environment'
require 'aws-sdk-s3'
require 'fileutils'
require 'logger'

# Setup logging
log_dir = Rails.root.join('log', 'migration')
FileUtils.mkdir_p(log_dir)
logger = Logger.new(log_dir.join("minio_migration_#{Time.now.strftime('%Y%m%d_%H%M%S')}.log"))
logger.info "Starting MinIO migration"

# MinIO client
minio_client = Aws::S3::Client.new(
  endpoint: "https://s3-api.zice.app",
  access_key_id: "jeremy",
  secret_access_key: "Lopsad29",
  region: "jerBook",
  force_path_style: true
)

bucket_name = "shock-collar-portraits-2025"

# Stats
stats = {
  total: 0,
  already_migrated: 0,
  migrated: 0,
  skipped: 0,
  failed: 0,
  errors: [],
  start_time: Time.now
}

puts "=" * 80
puts "🚀 FULL MINIO MIGRATION"
puts "=" * 80
puts "Starting at: #{stats[:start_time]}"
puts "Target: Original photos only (>1MB)"
puts "Method: Upload from local files (zero S3 egress)"
puts "=" * 80

# Get all original photo blobs still on S3
blobs_to_migrate = ActiveStorage::Blob
  .where(service_name: "amazon", content_type: ["image/jpeg", "image/heic"])
  .where("byte_size > ?", 1_000_000)
  .order(:id)

stats[:total] = blobs_to_migrate.count
puts "\n📊 Found #{stats[:total]} original photos to migrate"
puts "Already on MinIO: #{ActiveStorage::Blob.where(service_name: 'minio').count}"
puts "\nStarting migration..."
puts "=" * 80

# Process in batches
batch_size = 100
batch_num = 0

blobs_to_migrate.find_in_batches(batch_size: batch_size) do |batch|
  batch_num += 1
  batch_start = Time.now

  puts "\n📦 Batch #{batch_num} (#{batch.size} photos)"
  puts "-" * 40

  batch.each_with_index do |blob, index|
    global_index = ((batch_num - 1) * batch_size) + index + 1

    begin
      # Check if already in MinIO
      begin
        minio_client.head_object(bucket: bucket_name, key: blob.key)
        # Already exists, just update database
        blob.update!(service_name: "minio")
        stats[:already_migrated] += 1

        if stats[:already_migrated] % 10 == 0
          puts "  ⏭️  Already in MinIO: #{stats[:already_migrated]} files"
        end
        next
      rescue Aws::S3::Errors::NotFound
        # Not in MinIO, proceed with upload
      end

      # Find the photo record
      attachment = ActiveStorage::Attachment
        .where(blob_id: blob.id, record_type: "Photo")
        .first

      unless attachment
        stats[:skipped] += 1
        logger.warn "Skipped blob #{blob.id}: No photo attachment"
        next
      end

      photo = Photo.find_by(id: attachment.record_id)
      unless photo&.photo_session&.started_at
        stats[:skipped] += 1
        logger.warn "Skipped blob #{blob.id}: No valid photo/session"
        next
      end

      # Determine local file path
      day = photo.photo_session.started_at.strftime("%A").downcase
      unless %w[monday tuesday wednesday thursday friday].include?(day)
        stats[:skipped] += 1
        logger.warn "Skipped blob #{blob.id}: Weekend day #{day}"
        next
      end

      # Handle multiple possible filenames
      folder_name = File.basename(blob.filename.to_s, ".*")
      local_path = nil

      # Try different extensions and cases
      [".JPG", ".jpg", ".jpeg", ".JPEG"].each do |ext|
        test_path = Rails.root.join("session_originals", day, folder_name, "#{folder_name}#{ext}")
        if File.exist?(test_path)
          local_path = test_path
          break
        end
      end

      unless local_path && File.exist?(local_path)
        stats[:failed] += 1
        error_msg = "Missing local file for blob #{blob.id}: #{blob.filename}"
        stats[:errors] << error_msg
        logger.error error_msg
        next
      end

      # Upload to MinIO
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

      # Update database
      blob.update!(service_name: "minio")
      stats[:migrated] += 1

      # Progress output
      if stats[:migrated] % 10 == 0
        elapsed = Time.now - stats[:start_time]
        rate = stats[:migrated] / elapsed
        remaining = (stats[:total] - global_index) / rate

        puts "  ✅ Progress: #{global_index}/#{stats[:total]} " \
             "(#{(global_index.to_f / stats[:total] * 100).round(1)}%) - " \
             "Rate: #{rate.round(1)} photos/sec - " \
             "ETA: #{(remaining / 60).round} min"
      end

    rescue => e
      stats[:failed] += 1
      error_msg = "Failed blob #{blob.id} (#{blob.filename}): #{e.message}"
      stats[:errors] << error_msg
      logger.error error_msg
      logger.error e.backtrace.first(5).join("\n")

      if stats[:failed] % 10 == 0
        puts "  ⚠️  Failures so far: #{stats[:failed]}"
      end
    end
  end

  batch_elapsed = Time.now - batch_start
  puts "  Batch completed in #{batch_elapsed.round(1)} seconds"
end

# Final statistics
total_elapsed = Time.now - stats[:start_time]

puts "\n" + "=" * 80
puts "🎉 MIGRATION COMPLETE"
puts "=" * 80
puts "\n📊 Final Statistics:"
puts "  Started: #{stats[:start_time]}"
puts "  Completed: #{Time.now}"
puts "  Duration: #{(total_elapsed / 60).round(1)} minutes"
puts ""
puts "  Total processed: #{stats[:total]}"
puts "  ✅ Newly migrated: #{stats[:migrated]}"
puts "  ⏭️  Already in MinIO: #{stats[:already_migrated]}"
puts "  ⚠️  Skipped: #{stats[:skipped]}"
puts "  ❌ Failed: #{stats[:failed]}"
puts ""
puts "  Average rate: #{(stats[:migrated] / total_elapsed).round(1)} photos/sec"
puts "  Total data migrated: ~#{((stats[:migrated] * 10) / 1024.0).round(1)} GB"

if stats[:errors].any?
  puts "\n⚠️  Errors encountered (see log for full details):"
  stats[:errors].first(10).each { |err| puts "  - #{err}" }
  puts "  ... and #{stats[:errors].size - 10} more" if stats[:errors].size > 10
  puts "\n  Full log: #{log_dir.join("minio_migration_#{Time.now.strftime('%Y%m%d_%H%M%S')}.log")}"
end

# Database verification
s3_remaining = ActiveStorage::Blob
  .where(service_name: "amazon", content_type: ["image/jpeg", "image/heic"])
  .where("byte_size > ?", 1_000_000)
  .count

minio_total = ActiveStorage::Blob
  .where(service_name: "minio")
  .count

puts "\n" + "=" * 80
puts "📈 Database Status:"
puts "  Original photos still on S3: #{s3_remaining}"
puts "  Total blobs on MinIO: #{minio_total}"

if s3_remaining == 0
  puts "\n✨ SUCCESS! All original photos migrated to MinIO!"
  puts "🎯 You can now safely:"
  puts "   1. Stop AWS S3 charges"
  puts "   2. Let variants regenerate on-demand from MinIO"
  puts "   3. Delete S3 bucket after verification"
else
  puts "\n⚠️  #{s3_remaining} photos remain on S3"
  puts "   Run script again to retry failed uploads"
end

logger.info "Migration completed. Total: #{stats[:total]}, Migrated: #{stats[:migrated]}, Failed: #{stats[:failed]}"
logger.close