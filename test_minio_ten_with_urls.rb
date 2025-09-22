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

# Get 10 photo blobs that haven't been migrated yet
blobs = ActiveStorage::Blob
  .where(content_type: "image/jpeg", service_name: "amazon")
  .where("byte_size > ?", 1_000_000)
  .limit(10)

puts "🚀 Testing MinIO migration with 10 photos"
puts "=" * 60

success_urls = []

blobs.each_with_index do |blob, index|
  begin
    # Find photo attachment
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

    # Handle both .jpg and .JPG extensions
    local_path = nil
    [ ".JPG", ".jpg" ].each do |ext|
      test_path = Rails.root.join("session_originals", day, folder_name, "#{folder_name}#{ext}")
      if File.exist?(test_path)
        local_path = test_path
        break
      end
    end

    unless local_path && File.exist?(local_path)
      puts "#{index+1}. ❌ Missing: #{blob.filename}"
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
          checksum: blob.checksum
        }
      )
    end

    # Update database
    blob.update!(service_name: "minio")

    # Generate URLs for testing
    rails_url = "https://scp-25-dev.oknotok.com/rails/active_storage/blobs/redirect/#{blob.signed_id}/#{blob.filename}"
    direct_url = "https://s3-api.zice.app/shock-collar-portraits-2025/#{blob.key}"

    success_urls << {
      index: index + 1,
      filename: blob.filename.to_s,
      photo_id: photo.id,
      blob_id: blob.id,
      rails_url: rails_url,
      direct_url: direct_url
    }

    puts "#{index+1}. ✅ Migrated: #{blob.filename} (Photo ##{photo.id})"

  rescue => e
    puts "#{index+1}. ❌ Error: #{blob.filename} - #{e.message}"
  end
end

puts "\n" + "=" * 60
puts "📋 TEST URLS"
puts "=" * 60

success_urls.each do |item|
  puts "\n#{item[:index]}. #{item[:filename]} (Photo ##{item[:photo_id]})"
  puts "   Rails URL (with redirect):"
  puts "   #{item[:rails_url]}"
  puts ""
  puts "   Direct MinIO URL:"
  puts "   #{item[:direct_url]}"
end

puts "\n" + "=" * 60
puts "📊 Summary"
puts "=" * 60
puts "Migrated: #{success_urls.length} photos"
puts "On MinIO now: #{ActiveStorage::Blob.where(service_name: "minio").count} total blobs"
puts "Still on S3: #{ActiveStorage::Blob.where(service_name: "amazon", content_type: "image/jpeg").where("byte_size > ?", 1_000_000).count} original photos"

puts "\n🧪 To test these URLs:"
puts "1. Click any Rails URL above - should redirect to MinIO and display the image"
puts "2. Click any Direct URL above - should immediately display the image"
puts "3. Both should load quickly with browser caching enabled"
