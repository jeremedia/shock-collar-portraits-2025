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

puts "Fixing Session #38 photos with correct files"
puts "=" * 60

session = PhotoSession.find(38)
photos = session.photos.includes(image_attachment: :blob)

photos.each do |photo|
  blob = photo.image.blob
  next unless blob

  local_path = Rails.root.join("session_originals/tuesday/3Q7A6483/#{photo.filename}")

  unless File.exist?(local_path)
    puts "❌ Missing: #{photo.filename}"
    next
  end

  file_size = File.size(local_path)
  puts "Uploading #{photo.filename} (#{(file_size/1024.0/1024.0).round(1)}MB) to key: #{blob.key}"

  # Delete existing empty object first
  begin
    minio_client.delete_object(bucket: bucket_name, key: blob.key)
  rescue Aws::S3::Errors::NoSuchKey
    # Ignore if doesn't exist
  end

  # Upload correct file
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

  # Verify upload
  obj = minio_client.head_object(bucket: bucket_name, key: blob.key)
  puts "✅ Uploaded: #{photo.filename} - MinIO size: #{(obj.content_length/1024.0/1024.0).round(1)}MB"
end

puts "\n" + "=" * 60
puts "Session #38 fixed! Try loading the page again."