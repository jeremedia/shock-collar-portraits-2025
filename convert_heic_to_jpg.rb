#!/usr/bin/env ruby

require_relative 'config/environment'
require 'fileutils'

puts "🔄 HEIC to JPG Conversion"
puts "=" * 60

# Find all HEIC files in session_originals
heic_files = Dir.glob("session_originals/**/*.HEIC", File::FNM_SYSCASE)
puts "Found #{heic_files.length} HEIC files to convert"

# Stats
converted = 0
failed = 0
errors = []

# Find corresponding Photo records
photos_to_update = []

heic_files.each_with_index do |heic_path, index|
  begin
    # Get file info
    dir = File.dirname(heic_path)
    basename = File.basename(heic_path, ".*")
    jpg_path = File.join(dir, "#{basename}.jpg")

    puts "\n#{index + 1}/#{heic_files.length}: Converting #{basename}.HEIC..."

    # Check if already converted
    if File.exist?(jpg_path)
      puts "  ⏭️  Already converted, skipping"
      next
    end

    # Convert using sips (macOS native tool)
    # -s format jpeg: Convert to JPEG
    # -s formatOptions 95: 95% quality (high quality, reasonable size)
    # --resampleHeightWidthMax 5000: Keep under 5000px (optional, remove if you want full size)
    cmd = "sips -s format jpeg -s formatOptions 95 '#{heic_path}' --out '#{jpg_path}' 2>/dev/null"

    success = system(cmd)

    if success && File.exist?(jpg_path)
      converted += 1
      jpg_size = File.size(jpg_path) / 1024.0 / 1024.0
      puts "  ✅ Converted: #{jpg_size.round(2)} MB"

      # Find corresponding Photo record to update later
      original_filename = "#{basename}.HEIC"
      photo = Photo.find_by(filename: original_filename)
      if photo
        photos_to_update << { photo: photo, new_filename: "#{basename}.jpg" }
        puts "  📝 Will update Photo ##{photo.id}"
      end

      # Optionally remove the HEIC file after successful conversion
      # FileUtils.rm(heic_path)
      # puts "  🗑️  Removed original HEIC"

    else
      failed += 1
      errors << "#{basename}.HEIC: conversion failed"
      puts "  ❌ Conversion failed"
    end

  rescue => e
    failed += 1
    errors << "#{basename}.HEIC: #{e.message}"
    puts "  ❌ Error: #{e.message}"
  end
end

puts "\n" + "=" * 60
puts "📊 Conversion Results:"
puts "  ✅ Converted: #{converted}"
puts "  ❌ Failed: #{failed}"

if errors.any?
  puts "\n⚠️  Errors:"
  errors.first(10).each { |err| puts "  - #{err}" }
end

# Update database
if photos_to_update.any?
  puts "\n" + "=" * 60
  puts "📝 Updating database..."

  updated = 0
  photos_to_update.each do |update|
    photo = update[:photo]
    old_filename = photo.filename
    new_filename = update[:new_filename]

    # Update Photo record
    photo.update!(filename: new_filename)
    updated += 1

    # Update Active Storage blob if it exists
    if photo.image.attached?
      blob = photo.image.blob
      blob.update!(
        filename: new_filename,
        content_type: 'image/jpeg'
      )
      puts "  Updated Photo ##{photo.id}: #{old_filename} → #{new_filename}"
    end
  end

  puts "\n✅ Updated #{updated} Photo records"
end

# Verify conversions
puts "\n" + "=" * 60
puts "🔍 Verification:"
remaining_heic = Dir.glob("session_originals/**/*.HEIC", File::FNM_SYSCASE).length
jpg_files = Dir.glob("session_originals/**/*.jpg", File::FNM_SYSCASE).length

puts "  HEIC files remaining: #{remaining_heic}"
puts "  JPG files total: #{jpg_files}"
puts "\nNext steps:"
puts "  1. Review converted files"
puts "  2. Once verified, uncomment line to delete HEIC files"
puts "  3. Run MinIO migration"
