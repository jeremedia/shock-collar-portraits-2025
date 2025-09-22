#!/usr/bin/env ruby

require 'set'
require 'fileutils'

puts "=" * 80
puts "EFFICIENT TUESDAY ZERO-BYTE FIX"
puts "=" * 80

# Step 1: Find all zero-byte files
zero_files = Dir.glob("session_originals/tuesday/*/*.JPG").select { |f| File.size(f) == 0 }
puts "\nFound #{zero_files.length} zero-byte files"

# Step 2: Get list of filenames to find
filenames = zero_files.map { |f| File.basename(f) }.uniq
puts "Unique filenames: #{filenames.length}"

# Step 3: Find burst folders on Air
puts "\n🔍 Locating burst folders on MacBook Air..."
burst_folders = Set.new

filenames.each_slice(10) do |batch|
  # Search for multiple files at once
  search_pattern = batch.map { |f| "-name '#{f}'" }.join(" -o ")
  cmd = "ssh jeremy@jer-air \"find /Users/jeremy/Desktop/OKNOTOK/OK-SHOCK-25/card_download_1 \\( #{search_pattern} \\) -type f | grep -v zero_byte | head -#{batch.length}\""

  results = `#{cmd}`.split("\n")
  results.each do |path|
    next if path.empty?
    burst_folder = File.dirname(path)
    burst_folders.add(burst_folder)
  end

  print "."
end

puts "\nFound #{burst_folders.length} burst folders"

# Step 4: Copy files from each burst folder
puts "\n📥 Copying files from MacBook Air..."

burst_folders.each_with_index do |burst_folder, index|
  burst_name = File.basename(burst_folder)
  puts "\n#{index + 1}/#{burst_folders.length}: #{burst_name}"

  # Get list of files we need from this burst
  needed_files = filenames.select do |filename|
    local_path = "session_originals/tuesday/#{File.basename(filename, '.*')}/#{filename}"
    File.exist?(local_path) && File.size(local_path) == 0
  end

  # Use rsync to copy only the files we need
  if needed_files.any?
    # Create include patterns for rsync
    include_file = "/tmp/rsync_includes_#{burst_name}.txt"
    File.open(include_file, 'w') do |f|
      needed_files.each { |filename| f.puts filename }
    end

    # Rsync command to copy specific files
    rsync_cmd = "rsync -av --files-from=#{include_file} " \
                "jeremy@jer-air:#{burst_folder}/ " \
                "session_originals/tuesday/ " \
                "--relative 2>/dev/null"

    # For each file, copy to its proper directory
    needed_files.each do |filename|
      basename = File.basename(filename, '.*')
      target_dir = "session_originals/tuesday/#{basename}"
      source_file = "jeremy@jer-air:#{burst_folder}/#{filename}"
      target_file = "#{target_dir}/#{filename}"

      `scp -q '#{source_file}' '#{target_file}' 2>/dev/null`

      if File.exist?(target_file) && File.size(target_file) > 0
        print "✓"
      else
        print "✗"
      end
    end

    File.delete(include_file) if File.exist?(include_file)
  end
end

puts "\n\n" + "=" * 80
puts "VERIFICATION"
puts "=" * 80

# Check results
remaining_zero = Dir.glob("session_originals/tuesday/*/*.JPG").select { |f| File.size(f) == 0 }.length
fixed_count = zero_files.length - remaining_zero

puts "✅ Fixed: #{fixed_count} files"
puts "❌ Still zero: #{remaining_zero} files"

if remaining_zero == 0
  puts "\n🎉 All files successfully fixed!"
else
  puts "\n⚠️  Some files still need attention"
  # Show sample of remaining
  Dir.glob("session_originals/tuesday/*/*.JPG").select { |f| File.size(f) == 0 }[0..4].each do |f|
    puts "  - #{f}"
  end
end

puts "\nNow run: ruby reupload_tuesday_to_minio.rb"
