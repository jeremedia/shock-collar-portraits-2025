#!/usr/bin/env ruby

require_relative 'config/environment'
require 'fileutils'
require 'logger'
require 'csv'

# Setup logging
logger = Logger.new(STDOUT)
logger.info "=" * 80
logger.info "FIXING LOCAL PHOTO ARCHIVE"
logger.info "=" * 80
logger.info "This will copy all missing/zero-byte files from MacBook Air"
logger.info ""

# Load lists from audit
zero_byte_files = File.readlines("zero_byte_files_list.txt").map(&:strip) rescue []
missing_files = []

if File.exist?("missing_files_list.txt")
  CSV.foreach("missing_files_list.txt", headers: false) do |row|
    missing_files << {
      photo_id: row[0],
      filename: row[1],
      day: row[2],
      expected_path: row[3]
    }
  end
end

total_to_fix = zero_byte_files.count + missing_files.count
logger.info "Files to fix:"
logger.info "  Zero-byte: #{zero_byte_files.count}"
logger.info "  Missing: #{missing_files.count}"
logger.info "  Total: #{total_to_fix}"
logger.info ""

# Create a list of all files we need to find
files_to_find = {}

# Add zero-byte files
zero_byte_files.each do |path|
  filename = File.basename(path)
  files_to_find[filename] ||= []
  files_to_find[filename] << { type: :zero_byte, path: path }
end

# Add missing files
missing_files.each do |m|
  filename = m[:filename]
  files_to_find[filename] ||= []
  files_to_find[filename] << { type: :missing, path: m[:expected_path], day: m[:day] }
end

logger.info "Unique files to find: #{files_to_find.count}"
logger.info ""

# Find all files on MacBook Air
logger.info "🔍 STEP 1: Locating files on MacBook Air..."
logger.info "This will take a few minutes..."

source_locations = {}
batch_size = 20

files_to_find.keys.each_slice(batch_size) do |batch|
  # Build find command for batch
  find_conditions = batch.map { |f| "-name '#{f}'" }.join(" -o ")
  cmd = "ssh jeremy@jer-air 'find /Users/jeremy/Desktop/OKNOTOK/OK-SHOCK-25 \\( #{find_conditions} \\) -type f 2>/dev/null | grep -v zero_byte | grep -v Trash'"

  results = `#{cmd}`.strip.split("\n")

  results.each do |path|
    next if path.empty?
    filename = File.basename(path)
    source_locations[filename] = path
  end

  print "."
end

logger.info ""
logger.info "Found #{source_locations.count} files on MacBook Air"

# Copy files
logger.info ""
logger.info "📥 STEP 2: Copying files..."

fixed_count = 0
failed_count = 0
copied_size = 0

files_to_find.each do |filename, targets|
  source = source_locations[filename]

  unless source
    logger.warn "  ⚠️  Not found on Air: #{filename}"
    failed_count += targets.count
    next
  end

  # Copy to each target location
  targets.each do |target|
    target_path = target[:path]

    # Create directory if needed
    target_dir = File.dirname(target_path)
    FileUtils.mkdir_p(target_dir) unless Dir.exist?(target_dir)

    # Copy file
    cmd = "scp -q 'jeremy@jer-air:#{source}' '#{target_path}' 2>&1"
    output = `#{cmd}`

    if $?.success? && File.exist?(target_path)
      size = File.size(target_path)
      if size > 0
        size_mb = (size / 1024.0 / 1024.0).round(1)
        logger.info "  ✅ #{filename} (#{size_mb}MB) -> #{target[:type]}"
        fixed_count += 1
        copied_size += size
      else
        logger.error "  ❌ #{filename} - copied but still zero bytes"
        failed_count += 1
      end
    else
      logger.error "  ❌ #{filename} - copy failed: #{output}"
      failed_count += 1
    end
  end
end

# Final verification
logger.info ""
logger.info "🔍 STEP 3: Final verification..."

remaining_zero = Dir.glob("session_originals/**/*.JPG").select { |f| File.size(f) == 0 }
remaining_missing = 0

Photo.find_each do |photo|
  session_day = photo.photo_session&.session_day&.day_name
  next unless session_day

  expected_path = "session_originals/#{session_day}/#{File.basename(photo.filename, '.*')}/#{photo.filename}"
  remaining_missing += 1 unless File.exist?(expected_path)
end

# Summary
logger.info ""
logger.info "=" * 80
logger.info "📊 FIX RESULTS"
logger.info "=" * 80
logger.info ""
logger.info "Files processed:"
logger.info "  Fixed: #{fixed_count}"
logger.info "  Failed: #{failed_count}"
logger.info "  Data copied: #{(copied_size / 1024.0 / 1024.0 / 1024.0).round(2)}GB"
logger.info ""
logger.info "Remaining issues:"
logger.info "  Zero-byte files: #{remaining_zero.count}"
logger.info "  Missing files: #{remaining_missing}"
logger.info ""

if remaining_zero.count == 0 && remaining_missing == 0
  logger.info "✨ SUCCESS! Local archive is now complete!"
  logger.info ""
  logger.info "Next steps:"
  logger.info "1. Run: ruby reupload_all_to_minio.rb"
  logger.info "   This will ensure all MinIO files match local archive"
else
  logger.info "⚠️  Some files still need attention"

  if remaining_zero.count > 0
    logger.info ""
    logger.info "Remaining zero-byte files:"
    remaining_zero[0..4].each { |f| logger.info "  - #{f}" }
    logger.info "  ... and #{remaining_zero.count - 5} more" if remaining_zero.count > 5
  end

  if remaining_missing > 0
    logger.info ""
    logger.info "These files may:"
    logger.info "  - Be in a different location on the Air"
    logger.info "  - Have different names"
    logger.info "  - Be truly missing"
  end
end

logger.info "=" * 80
