#!/usr/bin/env ruby

require_relative 'config/environment'
require 'aws-sdk-s3'
require 'logger'

# Setup logging
logger = Logger.new(STDOUT)
logger.info "=" * 80
logger.info "COMPREHENSIVE TUESDAY ZERO-BYTE FIX"
logger.info "Starting at: #{Time.now}"
logger.info "=" * 80

# MinIO client for later
minio_client = Aws::S3::Client.new(
  endpoint: "https://s3-api.zice.app",
  access_key_id: "jeremy",
  secret_access_key: "Lopsad29",
  region: "jerBook",
  force_path_style: true
)

# Step 1: Identify all zero-byte files
logger.info "\n📋 STEP 1: Identifying zero-byte files..."
zero_files = Dir.glob("session_originals/tuesday/*/*.JPG").select { |f| File.size(f) == 0 }
logger.info "Found #{zero_files.length} zero-byte files"

# Create a mapping of files to their database records
file_to_photo = {}
zero_files.each do |filepath|
  filename = File.basename(filepath)
  photo = Photo.joins(photo_session: :session_day)
               .where(session_days: { day_name: "tuesday" })
               .where(filename: filename)
               .first

  if photo
    file_to_photo[filepath] = photo
    logger.debug "Mapped #{filename} to Photo ##{photo.id}"
  end
end

logger.info "Mapped #{file_to_photo.length} files to database records"

# Step 2: Group files by their burst session using EXIF time
logger.info "\n📅 STEP 2: Grouping by burst sessions..."
bursts = {}
file_to_photo.each do |filepath, photo|
  next unless photo.exif_data && photo.exif_data['DateTimeOriginal']

  # Parse EXIF time to find burst group
  exif_time = photo.exif_data['DateTimeOriginal']
  # Format: "2025:08:26 16:35:03"

  if exif_time =~ /(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})/
    hour = $4.to_i
    minute = $5.to_i

    # Create a burst key based on time (photos within 2 minutes are same burst)
    burst_key = "#{$2}#{$3}_#{hour}#{(minute/2).to_s.rjust(2, '0')}"

    bursts[burst_key] ||= []
    bursts[burst_key] << { file: filepath, photo: photo, exif: exif_time }
  end
end

logger.info "Grouped into #{bursts.length} burst sessions"

# Step 3: Find and copy files for each burst
logger.info "\n🔄 STEP 3: Copying files from MacBook Air..."

fixed_files = []
failed_files = []

bursts.each_with_index do |(burst_key, files), index|
  logger.info "\nBurst #{index + 1}/#{bursts.length}: #{burst_key} (#{files.length} files)"

  # Get sample filename to find burst folder
  sample = files.first
  sample_filename = File.basename(sample[:file])

  # Find burst folder on Air
  cmd = "ssh jeremy@jer-air 'find /Users/jeremy/Desktop/OKNOTOK/OK-SHOCK-25/card_download_1 -name \"#{sample_filename}\" -type f 2>/dev/null | grep -v zero_byte | head -1'"
  source_path = `#{cmd}`.strip

  if source_path.empty?
    logger.warn "  ⚠️  Could not find source for #{sample_filename}"
    failed_files.concat(files.map { |f| f[:file] })
    next
  end

  burst_folder = File.dirname(source_path)
  burst_name = File.basename(burst_folder)
  logger.info "  Found burst folder: #{burst_name}"

  # Copy each file
  files.each do |file_info|
    filename = File.basename(file_info[:file])
    local_path = file_info[:file]
    remote_path = "#{burst_folder}/#{filename}"

    # Use scp to copy
    cmd = "scp -q jeremy@jer-air:'#{remote_path}' '#{local_path}' 2>&1"
    output = `#{cmd}`

    if $?.success? && File.exist?(local_path) && File.size(local_path) > 0
      size_mb = (File.size(local_path) / 1024.0 / 1024.0).round(1)
      logger.info "  ✅ #{filename} (#{size_mb}MB)"
      fixed_files << local_path
    else
      logger.error "  ❌ #{filename} - #{output}"
      failed_files << local_path
    end
  end
end

logger.info "\n" + "=" * 80
logger.info "📊 COPY RESULTS:"
logger.info "  ✅ Fixed: #{fixed_files.length} files"
logger.info "  ❌ Failed: #{failed_files.length} files"

# Step 4: Re-upload to MinIO
logger.info "\n☁️  STEP 4: Re-uploading to MinIO..."

upload_count = 0
upload_errors = 0

fixed_files.each do |filepath|
  photo = file_to_photo[filepath]
  next unless photo && photo.image.attached?

  blob = photo.image.blob
  next unless blob && blob.service_name == "minio"

  begin
    # Check current MinIO state
    obj = minio_client.head_object(bucket: "shock-collar-portraits-2025", key: blob.key)

    # Re-upload if size is wrong
    if obj.content_length == 0 || obj.content_length != File.size(filepath)
      File.open(filepath, "rb") do |file|
        minio_client.put_object(
          bucket: "shock-collar-portraits-2025",
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
      upload_count += 1
      logger.info "  ↑ Uploaded #{File.basename(filepath)}"
    end
  rescue Aws::S3::Errors::NotFound
    # Upload if not in MinIO
    File.open(filepath, "rb") do |file|
      minio_client.put_object(
        bucket: "shock-collar-portraits-2025",
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
    upload_count += 1
    logger.info "  + Uploaded #{File.basename(filepath)}"
  rescue => e
    logger.error "  ❌ Upload error for #{File.basename(filepath)}: #{e.message}"
    upload_errors += 1
  end
end

# Step 5: Final verification
logger.info "\n✅ STEP 5: Final verification..."

remaining_zero = Dir.glob("session_originals/tuesday/*/*.JPG").select { |f| File.size(f) == 0 }
logger.info "Remaining zero-byte files: #{remaining_zero.length}"

if remaining_zero.any?
  logger.warn "Still zero-byte:"
  remaining_zero[0..9].each { |f| logger.warn "  - #{f}" }
end

# Summary
logger.info "\n" + "=" * 80
logger.info "🎯 FINAL SUMMARY"
logger.info "=" * 80
logger.info "  Original zero-byte files: #{zero_files.length}"
logger.info "  Files fixed locally: #{fixed_files.length}"
logger.info "  Files failed to copy: #{failed_files.length}"
logger.info "  Files uploaded to MinIO: #{upload_count}"
logger.info "  Upload errors: #{upload_errors}"
logger.info "  Remaining zero-byte: #{remaining_zero.length}"

if remaining_zero.length == 0
  logger.info "\n✨ SUCCESS! All Tuesday files fixed!"
else
  percentage_fixed = ((fixed_files.length.to_f / zero_files.length) * 100).round(1)
  logger.info "\n📈 Fixed #{percentage_fixed}% of files"
end

logger.info "\nCompleted at: #{Time.now}"
logger.info "=" * 80
