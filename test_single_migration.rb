#!/usr/bin/env ruby

require_relative 'config/environment'
require 'aws-sdk-s3'

# MinIO client
minio_client = Aws::S3::Client.new(
  endpoint: "https://s3-api.zice.app",
  access_key_id: "jeremy",
  secret_access_key: "Lopsad29",
  region: "jerBook",
  force_path_style: true
)

bucket_name = "shock-collar-portraits-2025"

# Find first photo blob
blob = ActiveStorage::Blob.where(content_type: [ "image/jpeg", "image/heic" ]).first
puts "Testing with blob:"
puts "  ID: #{blob.id}"
puts "  Key: #{blob.key}"
puts "  Filename: #{blob.filename}"
puts "  Service: #{blob.service_name}"
puts "  Size: #{blob.byte_size} bytes"

# Find corresponding photo record
attachment = ActiveStorage::Attachment.where(blob_id: blob.id).first
photo = Photo.find(attachment.record_id) if attachment&.record_type == "Photo"

if photo.nil?
  puts "❌ No photo record found for this blob"
  exit 1
end

puts "\nPhoto record:"
puts "  ID: #{photo.id}"
puts "  Filename: #{photo.filename}"
puts "  Session: #{photo.photo_session&.id}"

# Determine local file path
day = photo.photo_session&.started_at&.strftime('%A')&.downcase
unless %w[monday tuesday wednesday thursday friday].include?(day)
  puts "❌ Invalid day: #{day}"
  exit 1
end

folder_name = File.basename(blob.filename.to_s, '.*')
local_path = Rails.root.join('session_originals', day, folder_name, blob.filename.to_s)

puts "\nLocal file:"
puts "  Path: #{local_path}"
puts "  Exists: #{File.exist?(local_path)}"

unless File.exist?(local_path)
  puts "❌ Local file not found!"
  exit 1
end

puts "  Size: #{File.size(local_path)} bytes"

# Check if already in MinIO
begin
  existing = minio_client.head_object(bucket: bucket_name, key: blob.key)
  puts "\n⚠️  File already exists in MinIO!"
  puts "  ETag: #{existing.etag}"
rescue Aws::S3::Errors::NotFound
  puts "\n✅ File not in MinIO yet, proceeding with upload..."
end

# Upload to MinIO
puts "\nUploading to MinIO..."
File.open(local_path, 'rb') do |file|
  result = minio_client.put_object(
    bucket: bucket_name,
    key: blob.key,
    body: file,
    content_type: blob.content_type || 'image/jpeg',
    metadata: {
      filename: blob.filename.to_s,
      content_type: blob.content_type || 'image/jpeg',
      byte_size: blob.byte_size.to_s,
      checksum: blob.checksum
    }
  )
  puts "✅ Upload successful!"
  puts "  ETag: #{result.etag}"
end

# Verify upload
head = minio_client.head_object(bucket: bucket_name, key: blob.key)
puts "\nVerification:"
puts "  File in MinIO: ✅"
puts "  Size: #{head.content_length} bytes"
puts "  Content-Type: #{head.content_type}"

# Update blob service
puts "\nUpdating database..."
blob.update!(service_name: "minio")
puts "✅ Blob service updated to 'minio'"

# Test URL generation
puts "\nTesting URL generation..."
minio_service = ActiveStorage::Service.configure(:minio, Rails.application.config_for(:storage))
url = minio_service.url(blob.key, expires_in: 300, filename: blob.filename, content_type: blob.content_type, disposition: :inline)
puts "✅ URL generated: #{url[0..80]}..."

puts "\n🎉 Single photo migration successful!"
