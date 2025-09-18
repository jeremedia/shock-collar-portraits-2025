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

puts "Migrating Session #396 photos (Thursday evening at Burning Man)"
puts "=" * 60

session = PhotoSession.find(396)
photos = session.photos.includes(image_attachment: :blob)

photos.each do |photo|
  blob = photo.image.blob
  next unless blob

  # This was Thursday evening, not Saturday!
  local_path = Rails.root.join("session_originals/thursday/3Q7A2681/#{photo.filename}")

  unless File.exist?(local_path)
    puts "❌ Missing: #{photo.filename}"
    next
  end

  # Check if already in MinIO
  begin
    minio_client.head_object(bucket: bucket_name, key: blob.key)
    # Already exists, just update database
    blob.update!(service_name: "minio")
    puts "⏭️  Already in MinIO: #{photo.filename}"
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
        checksum: blob.checksum,
        photo_id: photo.id.to_s
      }
    )
  end

  # Update database
  blob.update!(service_name: "minio")
  puts "✅ Migrated: #{photo.filename} (#{(blob.byte_size/1024.0/1024.0).round(1)}MB)"
end

puts "\n" + "=" * 60
puts "Migration complete for Session #396"
puts "Photos are now served from MinIO!"