#!/usr/bin/env ruby

require_relative 'config/environment'
require 'aws-sdk-s3'
require 'fileutils'

# MinIO client
minio_client = Aws::S3::Client.new(
  endpoint: "https://s3-api.zice.app",
  access_key_id: "jeremy",
  secret_access_key: "Lopsad29",
  region: "jerBook",
  force_path_style: true
)

bucket_name = "shock-collar-portraits-2025"

puts "=" * 80
puts "FIXING ALL TUESDAY ZERO-BYTE FILES"
puts "=" * 80

# Find all zero-byte files
zero_byte_files = Dir.glob("session_originals/tuesday/*/*.JPG").select { |f| File.size(f) == 0 }
puts "\nFound #{zero_byte_files.length} zero-byte files to fix"

# Group by burst pattern (files in sequence)
files_by_burst = {}
zero_byte_files.each do |file|
  filename = File.basename(file)
  # Extract the number part to find the burst group
  if filename =~ /3Q7A(\d+)\.JPG/
    num = $1.to_i
    # Find the burst start (usually groups of ~10-30 photos)
    burst_start = (num / 50) * 50  # Round down to nearest 50
    files_by_burst[burst_start] ||= []
    files_by_burst[burst_start] << filename
  end
end

puts "\nGrouped into #{files_by_burst.length} burst sessions"

# Process each burst group
fixed_count = 0
failed_count = 0
files_by_burst.each do |burst_start, filenames|
  puts "\n📦 Processing burst group starting around 3Q7A#{burst_start}..."

  # Find one file from this group to determine the source folder
  sample_file = filenames.first

  # Find the burst folder on the Air
  cmd = "ssh jeremy@jer-air 'find /Users/jeremy/Desktop/OKNOTOK/OK-SHOCK-25/card_download_1 -name \"#{sample_file}\" -type f | grep -v zero_byte | head -1'"
  source_path = `#{cmd}`.strip

  if source_path.empty?
    puts "  ⚠️  Could not find source for #{sample_file}"
    failed_count += filenames.length
    next
  end

  # Get the burst folder
  burst_folder = File.dirname(source_path)
  burst_name = File.basename(burst_folder)

  puts "  Found burst: #{burst_name} with #{filenames.length} files"

  # Copy all files from this burst that we need
  filenames.each do |filename|
    local_path = "session_originals/tuesday/#{File.basename(filename, '.*')}/#{filename}"

    # Copy from Air
    remote_file = "#{burst_folder}/#{filename}"
    cmd = "scp -q jeremy@jer-air:'#{remote_file}' '#{local_path}' 2>/dev/null"
    system(cmd)

    if File.exist?(local_path) && File.size(local_path) > 0
      print "."
      fixed_count += 1
    else
      print "!"
      failed_count += 1
    end
  end
  puts " Done"
end

puts "\n" + "=" * 80
puts "📊 FIXING RESULTS:"
puts "  ✅ Fixed: #{fixed_count} files"
puts "  ❌ Failed: #{failed_count} files"
puts "=" * 80

# Now re-upload fixed files to MinIO
puts "\n🚀 RE-UPLOADING TO MINIO..."

# Get all Tuesday photos that need re-uploading
tuesday_photos = Photo.joins(photo_session: :session_day)
                      .includes(image_attachment: :blob)
                      .where(session_days: { day_name: "tuesday" })
                      .where(active_storage_blobs: { service_name: "minio" })

upload_count = 0
tuesday_photos.find_each do |photo|
  blob = photo.image.blob
  next unless blob

  local_path = Rails.root.join("session_originals/tuesday/#{File.basename(photo.filename, '.*')}/#{photo.filename}")

  # Only re-upload if we have a good file now
  next unless File.exist?(local_path) && File.size(local_path) > 0

  # Check if MinIO has wrong size
  begin
    obj = minio_client.head_object(bucket: bucket_name, key: blob.key)
    if obj.content_length == 0 || obj.content_length != File.size(local_path)
      # Re-upload
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
      upload_count += 1
      print "↑"
    end
  rescue Aws::S3::Errors::NotFound
    # Upload if not found
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
    upload_count += 1
    print "+"
  end
end

puts "\n\n" + "=" * 80
puts "✨ COMPLETE!"
puts "  📁 Fixed local files: #{fixed_count}"
puts "  ☁️  Re-uploaded to MinIO: #{upload_count}"
puts "=" * 80
puts "\nTuesday sessions should now load correctly!"