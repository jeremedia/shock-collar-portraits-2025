# Tasks for fixing photo session timestamps to maintain chronological order
# 
# IMPORTANT: Session timestamps are critical for correct chronological display
# - Burst folder timestamps are in UTC (already converted from PST)
# - EXIF DateTimeOriginal is in camera's local time (PST at Burning Man)
# - Split sessions MUST use actual photo taken time to appear in correct order
#
# Usage:
#   rails photos:fix_split_sessions    # Fix timestamps for split sessions
#   rails photos:extract_all_exif      # Extract EXIF for all photos
#   rails photos:fix_session_timestamps # Fix all session timestamps using EXIF

namespace :photos do
  desc "Fix split session timestamps using EXIF data"
  task fix_split_sessions: :environment do
    puts "🔧 Fixing split session timestamps using EXIF data..."
    
    # Find all split sessions
    split_sessions = PhotoSession.where("burst_id LIKE ?", "%-split-%")
    
    puts "📊 Found #{split_sessions.count} split sessions to fix"
    
    sessions_fixed = 0
    exif_extracted = 0
    
    split_sessions.each do |session|
      photos = session.photos.order(:position)
      next if photos.empty?
      
      first_photo = photos.first
      last_photo = photos.last
      
      # Extract EXIF for photos if needed
      [first_photo, last_photo].each do |photo|
        unless photo.exif_data && photo.exif_data['DateTimeOriginal']
          photo.extract_exif_datetime
          exif_extracted += 1
          print "."
        end
      end
      
      # Get actual photo taken times
      new_started_at = first_photo.photo_taken_at
      new_ended_at = last_photo.photo_taken_at
      
      if session.started_at != new_started_at || session.ended_at != new_ended_at
        old_started = session.started_at
        session.update!(
          started_at: new_started_at,
          ended_at: new_ended_at
        )
        sessions_fixed += 1
        puts "\n  ✅ Fixed #{session.burst_id}:"
        puts "     Old: #{old_started.strftime('%Y-%m-%d %H:%M:%S')}"
        puts "     New: #{new_started_at.strftime('%Y-%m-%d %H:%M:%S')}"
      end
    end
    
    puts "\n✨ Results:"
    puts "   • Fixed #{sessions_fixed} split session timestamps"
    puts "   • Extracted EXIF for #{exif_extracted} photos"
    
    # Also queue EXIF extraction for all photos without it
    photos_without_exif = Photo.where("exif_data IS NULL OR exif_data = '{}'")
    if photos_without_exif.any?
      puts "\n📷 Queueing EXIF extraction for #{photos_without_exif.count} photos..."
      photos_without_exif.find_each do |photo|
        ExifExtractionJob.perform_later(photo.id)
      end
      puts "   ✅ Jobs queued"
    end
  end
  
  desc "Extract EXIF for all photos"
  task extract_all_exif: :environment do
    puts "📷 Extracting EXIF data for all photos..."
    
    photos_without_exif = Photo.where("exif_data IS NULL OR exif_data = '{}'")
    total = photos_without_exif.count
    
    puts "Found #{total} photos without EXIF data"
    
    if total > 0
      puts "Queueing extraction jobs..."
      photos_without_exif.find_each.with_index do |photo, index|
        ExifExtractionJob.perform_later(photo.id)
        print "." if index % 100 == 0
      end
      puts "\n✅ Queued #{total} EXIF extraction jobs"
    else
      puts "✨ All photos already have EXIF data!"
    end
  end

  desc "Fix session timestamps using actual EXIF data from photos"
  task fix_session_timestamps: :environment do
    require 'open3'
    
    fixed_count = 0
    failed_count = 0
    
    PhotoSession.find_each do |session|
      begin
        # Get first and last photos
        first_photo = session.photos.order(:position).first
        last_photo = session.photos.order(:position).last
        
        next unless first_photo&.original_path
        
        # Extract EXIF timestamp from first photo
        if File.exist?(first_photo.original_path)
          # Use mdls to get creation date (more reliable on macOS)
          cmd = "mdls -name kMDItemContentCreationDate -raw '#{first_photo.original_path}'"
          stdout, stderr, status = Open3.capture3(cmd)
          
          if status.success? && stdout.present? && stdout != '(null)'
            # Parse the timestamp
            timestamp_str = stdout.strip
            
            # mdls returns format like "2025-08-25 21:59:06 +0000"
            if timestamp_str =~ /\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/
              first_photo_time = Time.parse(timestamp_str)
              
              # Update session started_at
              old_time = session.started_at
              session.started_at = first_photo_time
              
              # If we have a last photo, get its timestamp for ended_at
              if last_photo&.original_path && File.exist?(last_photo.original_path)
                cmd = "mdls -name kMDItemContentCreationDate -raw '#{last_photo.original_path}'"
                stdout, stderr, status = Open3.capture3(cmd)
                
                if status.success? && stdout.present? && stdout != '(null)'
                  timestamp_str = stdout.strip
                  if timestamp_str =~ /\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/
                    last_photo_time = Time.parse(timestamp_str)
                    session.ended_at = last_photo_time
                  end
                end
              end
              
              session.save!
              fixed_count += 1
              
              puts "✓ #{session.burst_id}: #{old_time.in_time_zone('America/Los_Angeles').strftime('%-l:%M %p')} → #{session.started_at.in_time_zone('America/Los_Angeles').strftime('%-l:%M %p PST')}"
            else
              puts "✗ #{session.burst_id}: Could not parse timestamp: #{timestamp_str}"
              failed_count += 1
            end
          else
            puts "✗ #{session.burst_id}: Could not extract EXIF data"
            failed_count += 1
          end
        else
          puts "✗ #{session.burst_id}: File not found: #{first_photo.original_path}"
          failed_count += 1
        end
      rescue => e
        puts "✗ #{session.burst_id}: Error - #{e.message}"
        failed_count += 1
      end
    end
    
    puts "\n" + "="*50
    puts "Fixed #{fixed_count} sessions"
    puts "Failed to fix #{failed_count} sessions" if failed_count > 0
    
    # Show some examples
    puts "\nSample times after correction:"
    PhotoSession.joins(:session_day).order('session_days.date ASC, started_at ASC').limit(5).each do |session|
      day_name = session.session_day&.day_name || 'unknown'
      puts "  #{day_name.capitalize} - #{session.burst_id}: #{session.started_at.in_time_zone('America/Los_Angeles').strftime('%B %d at %-l:%M %p PST')}"
    end
  end
end