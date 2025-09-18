#!/usr/bin/env ruby

require_relative 'config/environment'
require 'net/http'
require 'uri'

puts "🔍 Testing MinIO Active Storage Integration"
puts "=" * 60

# Find a photo that's already migrated to MinIO
blob = ActiveStorage::Blob.where(service_name: "minio", content_type: ["image/jpeg", "image/heic"]).first

unless blob
  puts "❌ No blobs found on MinIO service. Please run migration first."
  exit 1
end

puts "\n📦 Testing with blob:"
puts "  ID: #{blob.id}"
puts "  Filename: #{blob.filename}"
puts "  Key: #{blob.key}"
puts "  Size: #{blob.byte_size} bytes"
puts "  Service: #{blob.service_name}"

# Find the photo record
attachment = ActiveStorage::Attachment.where(blob_id: blob.id, record_type: "Photo").first
photo = Photo.find(attachment.record_id) if attachment

unless photo
  puts "❌ No photo found for this blob"
  exit 1
end

puts "\n📸 Photo record:"
puts "  ID: #{photo.id}"
puts "  Filename: #{photo.filename}"

# Test 1: Generate URL through Active Storage
puts "\n" + "=" * 60
puts "TEST 1: URL Generation through Active Storage"
puts "=" * 60

begin
  # This should use the MinIO service configured in storage.yml
  url = Rails.application.routes.url_helpers.rails_blob_url(
    blob,
    host: "http://localhost:4000"  # Use your Rails server host
  )
  puts "✅ URL generated: #{url}"
rescue => e
  puts "❌ Failed to generate URL: #{e.message}"
  exit 1
end

# Test 2: Generate a direct service URL
puts "\n" + "=" * 60
puts "TEST 2: Direct Service URL"
puts "=" * 60

begin
  # Get the MinIO service directly
  service = blob.service

  # Generate a signed URL
  service_url = service.url(
    blob.key,
    expires_in: 300,
    disposition: :inline,
    filename: blob.filename,
    content_type: blob.content_type
  )

  puts "✅ Service URL generated: #{service_url[0..100]}..."

  # Actually try to fetch the file
  uri = URI(service_url)
  response = Net::HTTP.get_response(uri)

  if response.code == "200"
    puts "✅ File downloadable: #{response.content_length} bytes"
    puts "  Content-Type: #{response['content-type']}"
  else
    puts "❌ Failed to download: HTTP #{response.code} #{response.message}"
    puts "  URL: #{service_url}"
  end

rescue => e
  puts "❌ Failed: #{e.message}"
  puts e.backtrace.first(5)
end

# Test 3: Variant generation
puts "\n" + "=" * 60
puts "TEST 3: Variant Generation"
puts "=" * 60

begin
  # Try to create a thumbnail variant
  variant = photo.file.variant(resize_to_limit: [300, 300])

  # This will trigger processing if not already done
  variant_key = variant.key
  puts "✅ Variant key generated: #{variant_key}"

  # Try to get the variant URL
  variant_url = Rails.application.routes.url_helpers.rails_representation_url(
    variant,
    host: "http://localhost:4000"
  )
  puts "✅ Variant URL: #{variant_url}"

  # Check if variant exists in MinIO
  require 'aws-sdk-s3'
  minio_client = Aws::S3::Client.new(
    endpoint: "https://s3-api.zice.app",
    access_key_id: "jeremy",
    secret_access_key: "Lopsad29",
    region: "jerBook",
    force_path_style: true
  )

  begin
    minio_client.head_object(bucket: "shock-collar-portraits-2025", key: variant_key)
    puts "✅ Variant exists in MinIO"
  rescue Aws::S3::Errors::NotFound
    puts "⚠️  Variant not yet in MinIO (will be created on first access)"
  end

rescue => e
  puts "❌ Variant generation failed: #{e.message}"
  puts e.backtrace.first(5)
end

# Test 4: Rails blob/representation paths
puts "\n" + "=" * 60
puts "TEST 4: Rails Path Helpers"
puts "=" * 60

begin
  blob_path = Rails.application.routes.url_helpers.rails_blob_path(blob)
  puts "✅ Blob path: #{blob_path}"

  representation_path = Rails.application.routes.url_helpers.rails_representation_path(
    photo.file.variant(resize_to_limit: [500, 500])
  )
  puts "✅ Representation path: #{representation_path}"

rescue => e
  puts "❌ Path generation failed: #{e.message}"
end

# Test 5: Check if we can actually serve through Rails
puts "\n" + "=" * 60
puts "TEST 5: Rails Server Integration"
puts "=" * 60

puts "To complete this test:"
puts "1. Start Rails server: bin/rails server -p 4000"
puts "2. Visit: http://localhost:4000#{Rails.application.routes.url_helpers.rails_blob_path(blob)}"
puts "3. You should see the image load in your browser"

# Summary
puts "\n" + "=" * 60
puts "📊 SUMMARY"
puts "=" * 60

minio_blobs = ActiveStorage::Blob.where(service_name: "minio").count
s3_blobs = ActiveStorage::Blob.where(service_name: "amazon").count

puts "Blobs on MinIO: #{minio_blobs}"
puts "Blobs on S3: #{s3_blobs}"

if service_url && response&.code == "200"
  puts "\n✅ MinIO integration is WORKING!"
  puts "Files are being served correctly from MinIO."
else
  puts "\n⚠️  MinIO integration needs configuration fixes."
end