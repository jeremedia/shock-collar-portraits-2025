namespace :photos do
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