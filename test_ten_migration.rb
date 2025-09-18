#!/usr/bin/env ruby

require_relative 'config/environment'
require 'aws-sdk-s3'

minio_client = Aws::S3::Client.new(
  endpoint: "https://s3-api.zice.app",
  access_key_id: "jeremy",
  secret_access_key: "Lopsad29",
  region: "jerBook",
  force_path_style: true
)

bucket_name = "shock-collar-portraits-2025"

# Test with 10 image blobs
blobs = ActiveStorage::Blob.where(content_type: ["image/jpeg", "image/heic"], service_name: "amazon").limit(10)

puts "Testing migration with #{blobs.count} photos..."
puts "=" * 60

success = 0
failed = 0

blobs.each_with_index do |blob, index|
  begin
    # Find photo
    attachment = ActiveStorage::Attachment.where(blob_id: blob.id, record_type: "Photo").first
    unless attachment
      puts "#{index+1}. ⏭️  Skipped: #{blob.filename} (not attached to Photo)"
      next
    end

    photo = Photo.find(attachment.record_id)
    unless photo.photo_session&.started_at
      puts "#{index+1}. ⏭️  Skipped: #{blob.filename} (no session date)"
      next
    end

    # Get local file path
    day = photo.photo_session.started_at.strftime("%A").downcase
    unless %w[monday tuesday wednesday thursday friday].include?(day)
      puts "#{index+1}. ⏭️  Skipped: #{blob.filename} (weekend: #{day})"
      next
    end

    folder_name = File.basename(blob.filename.to_s, ".*")
    local_path = Rails.root.join("session_originals", day, folder_name, blob.filename.to_s)

    unless File.exist?(local_path)
      puts "#{index+1}. ❌ Missing: #{blob.filename} at #{local_path}"
      failed += 1
      next
    end

    # Check if already in MinIO
    begin
      minio_client.head_object(bucket: bucket_name, key: blob.key)
      puts "#{index+1}. ⏭️  Already in MinIO: #{blob.filename}"
      # Still update the database
      blob.update!(service_name: "minio")
      success += 1
      next
    rescue Aws::S3::Errors::NotFound
      # Not in MinIO, proceed with upload
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
          checksum: blob.checksum
        }
      )
    end

    # Update database
    blob.update!(service_name: "minio")

    success += 1
    puts "#{index+1}. ✅ Migrated: #{blob.filename} (#{blob.byte_size} bytes)"

  rescue => e
    failed += 1
    puts "#{index+1}. ❌ Error: #{blob.filename} - #{e.message}"
  end
end

puts "=" * 60
puts "Results: #{success} succeeded, #{failed} failed"

# Show current status
s3_count = ActiveStorage::Blob.where(service_name: "amazon").count
minio_count = ActiveStorage::Blob.where(service_name: "minio").count
puts "\nDatabase status:"
puts "  Still on S3: #{s3_count}"
puts "  On MinIO: #{minio_count}"