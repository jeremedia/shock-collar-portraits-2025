namespace :photos do
  desc "Create directory structure for organizing original photos by day and filename"
  task organize_structure: :environment do
    require 'fileutils'

    base_dir = Rails.root.join('session_originals')

    # Create day directories
    days = %w[monday tuesday wednesday thursday friday]
    days.each do |day|
      FileUtils.mkdir_p(base_dir.join(day))
      puts "Created #{base_dir.join(day)}"
    end

    # Group photos by day of week based on shot_at
    photos_by_day = {}

    Photo.includes(:photo_session).find_each do |photo|
      next unless photo.photo_session&.started_at

      day_of_week = photo.photo_session.started_at.strftime('%A').downcase
      next unless days.include?(day_of_week)

      photos_by_day[day_of_week] ||= []
      photos_by_day[day_of_week] << photo
    end

    # Create subdirectories for each unique filename
    manifest = []

    photos_by_day.each do |day, day_photos|
      unique_filenames = day_photos.map(&:filename).compact.uniq

      unique_filenames.each do |filename|
        # Remove extension for cleaner folder names
        folder_name = File.basename(filename, '.*')
        folder_path = base_dir.join(day, folder_name)

        FileUtils.mkdir_p(folder_path)
        puts "Created #{folder_path}"

        # Add to manifest for scp copying
        manifest << {
          day: day,
          folder: folder_name,
          filename: filename,
          path: folder_path.to_s
        }
      end
    end

    # Save manifest for reference
    manifest_path = base_dir.join('copy_manifest.json')
    File.write(manifest_path, JSON.pretty_generate(manifest))

    # Generate scp helper script
    scp_script_path = base_dir.join('scp_from_air.sh')
    File.open(scp_script_path, 'w') do |f|
      f.puts "#!/bin/bash"
      f.puts "# SCP script to copy originals from MacBook Air"
      f.puts "# Usage: ./scp_from_air.sh <air_username>@<air_ip>:<source_path>"
      f.puts ""
      f.puts "if [ $# -eq 0 ]; then"
      f.puts '  echo "Usage: $0 <air_username>@<air_ip>:<source_path>"'
      f.puts '  echo "Example: $0 jeremy@192.168.1.100:/path/to/photos"'
      f.puts '  exit 1'
      f.puts "fi"
      f.puts ""
      f.puts "SOURCE=$1"
      f.puts ""

      manifest.each do |item|
        f.puts "# Copy #{item[:filename]} to #{item[:day]}/#{item[:folder]}/"
        f.puts "scp \"${SOURCE}/#{item[:filename]}\" \"#{item[:path]}/\""
      end
    end

    FileUtils.chmod(0755, scp_script_path)

    puts "\n=== Summary ==="
    puts "Total photos organized: #{manifest.length}"
    photos_by_day.each do |day, photos|
      puts "#{day.capitalize}: #{photos.map(&:filename).compact.uniq.length} unique files"
    end
    puts "\nManifest saved to: #{manifest_path}"
    puts "SCP script saved to: #{scp_script_path}"
    puts "\nNext steps:"
    puts "1. Review the generated structure"
    puts "2. Run the scp script with your MacBook Air's connection details"
    puts "3. Or use rsync for more efficient copying"
  end

  desc "Generate photo copy list by directory"
  task list_originals: :environment do
    # List all photos with their source paths for manual copying
    photos_by_source = {}

    Photo.includes(:photo_session).find_each do |photo|
      next unless photo.photo_session&.started_at

      day = photo.photo_session.started_at.strftime('%A').downcase
      next unless %w[monday tuesday wednesday thursday friday].include?(day)

      # Group by potential source directories on the Air
      source_hint = photo.filename&.start_with?('IMG_') ? 'iphone' : 'canon'
      photos_by_source[source_hint] ||= []
      photos_by_source[source_hint] << {
        filename: photo.filename,
        day: day,
        folder: File.basename(photo.filename, '.*'),
        session_id: photo.photo_session.id
      }
    end

    # Output organized lists
    photos_by_source.each do |source, photos|
      puts "\n=== #{source.upcase} Photos (#{photos.length} files) ==="
      photos.group_by { |p| p[:day] }.each do |day, day_photos|
        puts "\n#{day.capitalize}: #{day_photos.length} files"
        day_photos.first(5).each do |photo|
          puts "  - #{photo[:filename]} -> session_originals/#{day}/#{photo[:folder]}/"
        end
        puts "  ... and #{day_photos.length - 5} more" if day_photos.length > 5
      end
    end
  end
end