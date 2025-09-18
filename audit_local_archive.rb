#!/usr/bin/env ruby

require_relative 'config/environment'
require 'fileutils'

puts "=" * 80
puts "LOCAL PHOTO ARCHIVE AUDIT"
puts "=" * 80
puts "Auditing session_originals directory for completeness"
puts ""

# Stats
stats = {
  total_photos_in_db: Photo.count,
  by_day: {},
  zero_byte_files: [],
  missing_files: [],
  good_files: [],
  total_size: 0
}

# Days to check
days = %w[monday tuesday wednesday thursday friday saturday sunday]

# Check each day
days.each do |day|
  day_path = "session_originals/#{day}"
  next unless Dir.exist?(day_path)

  stats[:by_day][day] = {
    folders: 0,
    files: 0,
    zero_byte: 0,
    good: 0,
    size: 0
  }

  # Count folders
  folders = Dir.glob("#{day_path}/*").select { |f| File.directory?(f) }
  stats[:by_day][day][:folders] = folders.count

  # Check each file
  Dir.glob("#{day_path}/*/*.JPG").each do |file|
    stats[:by_day][day][:files] += 1
    size = File.size(file)

    if size == 0
      stats[:by_day][day][:zero_byte] += 1
      stats[:zero_byte_files] << file
    else
      stats[:by_day][day][:good] += 1
      stats[:good_files] << file
      stats[:by_day][day][:size] += size
      stats[:total_size] += size
    end
  end
end

# Check database photos against local files
puts "Checking database photos against local files..."
missing_from_local = []

Photo.find_each do |photo|
  # Determine expected local path based on session day
  session_day = photo.photo_session&.session_day&.day_name
  next unless session_day

  expected_path = "session_originals/#{session_day}/#{File.basename(photo.filename, '.*')}/#{photo.filename}"

  unless File.exist?(expected_path)
    missing_from_local << {
      photo_id: photo.id,
      filename: photo.filename,
      session_id: photo.photo_session_id,
      day: session_day,
      expected_path: expected_path
    }
    stats[:missing_files] << expected_path
  end
end

# Print report
puts "\n" + "=" * 80
puts "📊 AUDIT RESULTS"
puts "=" * 80
puts ""
puts "Database:"
puts "  Total photos in database: #{stats[:total_photos_in_db]}"
puts ""
puts "Local Archive by Day:"

days.each do |day|
  next unless stats[:by_day][day]
  day_stats = stats[:by_day][day]
  next if day_stats[:files] == 0

  size_gb = (day_stats[:size] / 1024.0 / 1024.0 / 1024.0).round(2)
  puts "  #{day.capitalize.ljust(10)} - Folders: #{day_stats[:folders]}, " \
       "Files: #{day_stats[:files]} (Good: #{day_stats[:good]}, Zero: #{day_stats[:zero_byte]}), " \
       "Size: #{size_gb}GB"
end

puts ""
puts "Overall Statistics:"
puts "  Total good files: #{stats[:good_files].count}"
puts "  Total zero-byte files: #{stats[:zero_byte_files].count}"
puts "  Total missing files: #{stats[:missing_files].count}"
puts "  Total archive size: #{(stats[:total_size] / 1024.0 / 1024.0 / 1024.0).round(2)}GB"

puts ""
puts "Quality Check:"
total_expected = stats[:total_photos_in_db]
total_have = stats[:good_files].count
percentage = (total_have.to_f / total_expected * 100).round(1)
puts "  Database photos: #{total_expected}"
puts "  Good local files: #{total_have}"
puts "  Completeness: #{percentage}%"

if stats[:zero_byte_files].any?
  puts ""
  puts "⚠️  Zero-byte files need fixing:"
  puts "  Total: #{stats[:zero_byte_files].count}"

  # Group by day for easier fixing
  by_day = stats[:zero_byte_files].group_by { |f| f.split('/')[1] }
  by_day.each do |day, files|
    puts "  #{day.capitalize}: #{files.count} files"
  end
end

if missing_from_local.any?
  puts ""
  puts "❌ Files missing from local archive:"
  puts "  Total: #{missing_from_local.count}"

  # Show first few examples
  missing_from_local[0..4].each do |m|
    puts "  - Photo ##{m[:photo_id]}: #{m[:filename]} (#{m[:day]})"
  end
  puts "  ... and #{missing_from_local.count - 5} more" if missing_from_local.count > 5
end

# Save detailed lists for reference
if stats[:zero_byte_files].any?
  File.open("zero_byte_files_list.txt", "w") do |f|
    stats[:zero_byte_files].each { |file| f.puts file }
  end
  puts ""
  puts "💾 Saved list of zero-byte files to: zero_byte_files_list.txt"
end

if missing_from_local.any?
  File.open("missing_files_list.txt", "w") do |f|
    missing_from_local.each do |m|
      f.puts "#{m[:photo_id]},#{m[:filename]},#{m[:day]},#{m[:expected_path]}"
    end
  end
  puts "💾 Saved list of missing files to: missing_files_list.txt"
end

puts ""
puts "=" * 80
puts "Next steps:"
if stats[:zero_byte_files].any? || missing_from_local.any?
  puts "1. Run: ruby fix_local_archive.rb"
  puts "   This will copy all missing/zero-byte files from MacBook Air"
else
  puts "✨ Local archive is complete!"
  puts "1. Ready to re-upload everything to MinIO"
end
puts "=" * 80