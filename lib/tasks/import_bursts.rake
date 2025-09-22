namespace :import do
  desc "Import burst folders and automatically process everything"
  task :bursts, [ :base_path, :day_name, :start_burst, :end_burst ] => :environment do |t, args|
    require "fileutils"

    base_path = args[:base_path] || raise("Missing base_path argument")
    day_name = args[:day_name] || raise("Missing day_name argument")
    start_burst = args[:start_burst] || raise("Missing start_burst argument")
    end_burst = args[:end_burst] || raise("Missing end_burst argument")

    puts "🎯 Starting comprehensive import for #{day_name.capitalize}"
    puts "   Base path: #{base_path}"
    puts "   Burst range: #{start_burst} to #{end_burst}"

    # Validate paths exist
    unless Dir.exist?(base_path)
      puts "❌ Error: Base path doesn't exist: #{base_path}"
      exit 1
    end

    # Create or find the BurnEvent for 2025
    event = BurnEvent.find_or_create_by!(
      theme: "OKNOTOK Shock Collar Portraits",
      year: 2025,
      location: "Black Rock City, NV"
    )

    # Create session day
    day_dates = {
      "sunday" => Date.new(2025, 8, 24),
      "monday" => Date.new(2025, 8, 25),
      "tuesday" => Date.new(2025, 8, 26),
      "wednesday" => Date.new(2025, 8, 27),
      "thursday" => Date.new(2025, 8, 28),
      "friday" => Date.new(2025, 8, 29)
    }

    session_day = SessionDay.find_or_create_by!(
      burn_event: event,
      day_name: day_name.downcase,
      date: day_dates[day_name.downcase]
    )

    puts "📅 Using session day: #{session_day.day_name} (#{session_day.date})"

    # Find all burst directories in range
    start_num = start_burst.match(/\d+/)[0].to_i
    end_num = end_burst.match(/\d+/)[0].to_i

    burst_dirs = Dir.glob("#{base_path}/burst_*").select do |dir|
      if match = File.basename(dir).match(/burst_(\d+)_/)
        burst_num = match[1].to_i
        burst_num >= start_num && burst_num <= end_num
      end
    end.sort

    puts "📁 Found #{burst_dirs.length} burst directories to import"

    if burst_dirs.empty?
      puts "❌ No burst directories found in range!"
      exit 1
    end

    imported_sessions = 0
    imported_photos = 0
    jobs_queued = 0

    burst_dirs.each do |burst_dir|
      dir_name = File.basename(burst_dir)

      # Parse burst directory name: burst_XXX_YYYYMMDD_HHMMSS
      unless match = dir_name.match(/burst_(\d+)_(\d{8})_(\d{6})/)
        puts "⚠️  Skipping invalid burst directory: #{dir_name}"
        next
      end

      burst_num = match[1].to_i
      date_str = match[2]
      time_str = match[3]

      # Parse timestamp from burst folder name
      # IMPORTANT: These timestamps are already in UTC (converted from PST during camera download)
      # Format: burst_016_20250825_081448 where timestamp represents UTC time
      begin
        started_at = DateTime.strptime("#{date_str}_#{time_str}", "%Y%m%d_%H%M%S")
      rescue => e
        puts "⚠️  Invalid timestamp in #{dir_name}, using current time"
        started_at = DateTime.current
      end

      # Find all JPG files in burst directory
      jpg_files = Dir.glob("#{burst_dir}/*.JPG").sort

      if jpg_files.empty?
        puts "⚠️  No JPG files in #{dir_name}"
        next
      end

      # Create photo session
      photo_session = PhotoSession.find_or_create_by!(
        session_day: session_day,
        burst_id: dir_name
      ) do |ps|
        ps.session_number = burst_num
        ps.started_at = started_at
        ps.ended_at = started_at + (jpg_files.length * 2).seconds # Estimate end time
        ps.source = "Canon R5"
        ps.photo_count = jpg_files.length
        ps.hidden = false
      end

      imported_sessions += 1

      # Import photos
      jpg_files.each_with_index do |photo_path, index|
        filename = File.basename(photo_path)

        photo = Photo.find_or_create_by!(
          photo_session: photo_session,
          filename: filename
        ) do |p|
          p.original_path = photo_path
          p.position = index
          p.rejected = false
          p.created_at = started_at + (index * 2).seconds
        end

        imported_photos += 1

        # Jobs are automatically queued by Photo model callbacks
        jobs_queued += 3  # attachment + face_detection + variants

        # Progress indicator
        if imported_photos % 50 == 0
          print "."
        end
      end

      # Update session photo count
      photo_session.update!(photo_count: photo_session.photos.count)

      puts "\n✅ #{dir_name}: #{jpg_files.length} photos"
    end

    puts "\n🎉 Import and processing queue complete!"
    puts "   📊 Imported #{imported_sessions} sessions"
    puts "   📷 Imported #{imported_photos} photos"
    puts "   ⚙️  Queued #{jobs_queued} processing jobs"
    puts ""
    puts "🔄 Background jobs are now processing:"
    puts "   • Image attachments (Active Storage)"
    puts "   • Face detection (bounding boxes)"
    puts "   • Variant generation (thumbnails & large)"
    puts ""
    puts "💡 Monitor progress with:"
    puts "   bin/rails runner \"puts SolidQueue::Job.where(finished_at: nil).group(:queue_name).count\""
    puts ""
    puts "🚀 When jobs complete, photos will be ready for hero selection and review!"
  end

  desc "Import Thursday burst folders"
  task thursday: :environment do
    Rake::Task["import:bursts"].invoke(
      "/Users/jeremy/Desktop/OK-SHOCK-25/card_download_1",
      "thursday",
      "burst_214",
      "burst_295"
    )
  end

  desc "Import Friday burst folders"
  task friday: :environment do
    Rake::Task["import:bursts"].invoke(
      "/Users/jeremy/Desktop/OK-SHOCK-25/card_download_1",
      "friday",
      "burst_296",
      "burst_408"
    )
  end

  desc "Import both Thursday and Friday"
  task thursday_friday: :environment do
    puts "🌟 Starting comprehensive import for Thursday and Friday"
    puts "=" * 60

    Rake::Task["import:thursday"].invoke

    puts "\n" + "=" * 60
    puts ""

    Rake::Task["import:friday"].invoke

    puts "\n" + "=" * 60
    puts "🏁 All done! Thursday and Friday photos imported and processing."
    puts "Check the web app to monitor progress and start hero selection!"
  end
end
