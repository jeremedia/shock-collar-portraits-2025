namespace :import do
  desc "Import photos from existing directory structure and photo_index.json"
  task photos: :environment do
    require "json"
    require "date"

    puts "Starting photo import..."

    # Path to the photo index
    index_path = Rails.root.join("..", "photo_index.json")
    unless File.exist?(index_path)
      puts "Error: photo_index.json not found at #{index_path}"
      exit 1
    end

    # Parse the photo index
    index_data = JSON.parse(File.read(index_path))

    # Create or find the BurnEvent for 2025
    event = BurnEvent.find_or_create_by!(
      theme: "OKNOTOK Shock Collar Portraits",
      year: 2025,
      location: "Black Rock City, NV"
    )
    puts "Using BurnEvent: #{event.theme} (#{event.year})"

    # Create session days
    day_mapping = {
      "sunday" => Date.new(2025, 8, 24),
      "monday" => Date.new(2025, 8, 25),
      "tuesday" => Date.new(2025, 8, 26),
      "wednesday" => Date.new(2025, 8, 27),
      "thursday" => Date.new(2025, 8, 28),
      "friday" => Date.new(2025, 8, 29)
    }

    session_days = {}
    day_mapping.each do |name, date|
      session_days[name] = SessionDay.find_or_create_by!(
        burn_event: event,
        day_name: name,
        date: date
      )
      puts "Created/found SessionDay: #{name}"
    end

    # Import sessions
    imported_sessions = 0
    imported_photos = 0

    index_data["sessions"].each do |session_data|
      day_name = session_data["dayOfWeek"]
      session_day = session_days[day_name]

      unless session_day
        puts "Warning: Unknown day #{day_name} for session #{session_data['id']}"
        next
      end

      # Create the photo session - use burst_id as unique identifier
      photo_session = PhotoSession.find_or_create_by!(
        session_day: session_day,
        burst_id: session_data["id"]
      ) do |ps|
        ps.session_number = session_data["sessionNumber"]
        ps.started_at = DateTime.parse(session_data["timestamp"])
        ps.ended_at = ps.started_at + session_data["duration"].seconds if session_data["duration"]
        ps.source = session_data["source"]
        ps.photo_count = session_data["photoCount"]
      end

      imported_sessions += 1

      # Import photos for this session
      session_data["photos"].each_with_index do |photo_data, index|
        photo = Photo.find_or_create_by!(
          photo_session: photo_session,
          filename: photo_data["filename"]
        ) do |p|
          p.original_path = Rails.root.join("..", photo_data["path"]).to_s
          p.position = index
          p.rejected = false
          p.metadata = {
            size: photo_data["size"],
            has_raw: photo_data["hasRaw"],
            type: photo_data["type"]
          }.to_json
        end

        imported_photos += 1

        # Output progress every 100 photos
        if imported_photos % 100 == 0
          print "."
        end
      end
    end

    puts "\n✅ Import complete!"
    puts "   - Imported #{imported_sessions} sessions"
    puts "   - Imported #{imported_photos} photos"
    puts "   - Days: #{session_days.keys.join(', ')}"
  end

  desc "Import emails from localStorage export"
  task emails: :environment do
    require "json"

    export_path = Rails.root.join("..", "shock-collar-vue", "emails_export.json")
    unless File.exist?(export_path)
      puts "No emails export found. Please export from the Vue app first."
      puts "In the browser console: localStorage.getItem('emails')"
      exit 1
    end

    emails_data = JSON.parse(File.read(export_path))
    imported_count = 0

    emails_data.each do |session_id, email_info|
      # Extract session number from session ID
      session_number = session_id.match(/\d+/)&.[](0)&.to_i
      next unless session_number

      # Find the corresponding photo session
      photo_session = PhotoSession.find_by(session_number: session_number)
      unless photo_session
        puts "Warning: No session found for #{session_id}"
        next
      end

      # Create or update the sitting
      sitting = Sitting.find_or_create_by!(
        photo_session: photo_session,
        email: email_info["email"]
      ) do |s|
        s.name = email_info["name"]
        s.notes = email_info["notes"]
        s.position = email_info["sessionNumber"] || 0
      end

      imported_count += 1
      puts "Imported sitting for session #{session_number}: #{sitting.email}"
    end

    puts "✅ Imported #{imported_count} sittings with emails"
  end

  desc "Import hero selections from localStorage export"
  task heroes: :environment do
    require "json"

    export_path = Rails.root.join("..", "shock-collar-vue", "hero_selections_export.json")
    unless File.exist?(export_path)
      puts "No hero selections export found. Please export from the Vue app first."
      puts "In the browser console: localStorage.getItem('heroSelections')"
      exit 1
    end

    heroes_data = JSON.parse(File.read(export_path))
    updated_count = 0

    heroes_data.each do |session_id, hero_index|
      # Find the photo session by burst_id
      photo_session = PhotoSession.find_by(burst_id: session_id)
      unless photo_session
        puts "Warning: No session found for #{session_id}"
        next
      end

      # Find the hero photo by position
      hero_photo = photo_session.photos.find_by(position: hero_index)
      unless hero_photo
        puts "Warning: No photo at position #{hero_index} for session #{session_id}"
        next
      end

      # Update any sittings for this session with the hero photo
      photo_session.sittings.each do |sitting|
        sitting.update!(hero_photo: hero_photo)
        updated_count += 1
      end

      puts "Set hero photo for session #{photo_session.session_number}"
    end

    puts "✅ Updated #{updated_count} sittings with hero photos"
  end

  desc "Export localStorage data from Vue app"
  task export_instructions: :environment do
    puts <<~INSTRUCTIONS
      To export data from the Vue app, open the browser console and run:

      1. Export emails:
         copy(JSON.stringify(JSON.parse(localStorage.getItem('emails') || '{}')))
      #{'   '}
         Then paste into: shock-collar-vue/emails_export.json

      2. Export hero selections:
         copy(JSON.stringify(JSON.parse(localStorage.getItem('heroSelections') || '{}')))
      #{'   '}
         Then paste into: shock-collar-vue/hero_selections_export.json

      After saving both files, run:
         rails import:emails
         rails import:heroes
    INSTRUCTIONS
  end
end
