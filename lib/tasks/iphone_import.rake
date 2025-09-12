namespace :iphone do
  desc "Analyze iPhone photo timestamps to identify sessions"
  task analyze_timestamps: :environment do
    require 'open3'
    
    iphone_dir = '/Users/jeremy/Desktop/OK-SHOCK-25/iphone_day_one_shots'
    files = Dir["#{iphone_dir}/*.HEIC"].sort
    
    puts "Found #{files.count} HEIC files"
    puts "Analyzing timestamps to identify sessions..."
    
    # Get creation dates using mdls (macOS metadata)
    timestamps = []
    files.each do |file|
      filename = File.basename(file)
      
      # Try to get creation date from macOS metadata
      cmd = "mdls -name kMDItemContentCreationDate '#{file}'"
      output = `#{cmd}`.strip
      
      if output.include?("kMDItemContentCreationDate")
        # Parse the date from mdls output
        date_str = output.split('=').last.strip
        begin
          timestamp = DateTime.parse(date_str)
          timestamps << { file: filename, time: timestamp }
        rescue => e
          puts "Error parsing timestamp for #{filename}: #{e.message}"
        end
      end
    end
    
    # Sort by timestamp
    timestamps.sort_by! { |t| t[:time] }
    
    # Identify session breaks (gap > 30 seconds)
    session_gap_seconds = 30
    sessions = []
    current_session = []
    
    timestamps.each_with_index do |photo, index|
      if current_session.empty?
        current_session << photo
      else
        prev_time = current_session.last[:time]
        time_diff = (photo[:time] - prev_time) * 24 * 60 * 60 # in seconds * 60 # difference in seconds
        
        if time_diff > session_gap_seconds
          # New session detected
          sessions << current_session
          current_session = [photo]
        else
          current_session << photo
        end
      end
    end
    
    # Add the last session
    sessions << current_session unless current_session.empty?
    
    # Display results
    puts "\nIdentified #{sessions.count} sessions:"
    sessions.each_with_index do |session, index|
      session_num = (index + 1).to_s.rjust(3, '0')
      first_photo = session.first
      last_photo = session.last
      duration = ((last_photo[:time] - first_photo[:time]) * 24 * 60).round(1)
      
      puts "\nSession iphone_#{session_num}:"
      puts "  Photos: #{session.count}"
      puts "  Start: #{first_photo[:time].strftime('%Y-%m-%d %H:%M:%S')}"
      puts "  End: #{last_photo[:time].strftime('%Y-%m-%d %H:%M:%S')}"
      puts "  Duration: #{duration} minutes"
      puts "  Files: #{first_photo[:file]} to #{last_photo[:file]}"
    end
  end
  
  desc "Import iPhone photos with proper session splits"
  task import: :environment do
    require 'open3'
    
    iphone_dir = '/Users/jeremy/Desktop/OK-SHOCK-25/iphone_day_one_shots'
    files = Dir["#{iphone_dir}/*.HEIC"].sort
    
    puts "Found #{files.count} HEIC files"
    
    # First, delete existing iPhone sessions
    puts "\nDeleting existing iPhone sessions..."
    PhotoSession.where("burst_id LIKE 'iphone%'").destroy_all
    
    # Get timestamps for all files
    timestamps = []
    files.each do |file|
      filename = File.basename(file)
      
      # Try to get creation date from macOS metadata
      cmd = "mdls -name kMDItemContentCreationDate '#{file}'"
      output = `#{cmd}`.strip
      
      if output.include?("kMDItemContentCreationDate")
        date_str = output.split('=').last.strip
        begin
          timestamp = DateTime.parse(date_str)
          # Adjust to Monday if needed (photos were taken on Monday 08/25)
          if timestamp.strftime('%Y-%m-%d') == '2025-08-27'
            # Adjust to Monday 08/25 while preserving time
            timestamp = DateTime.parse("2025-08-25 #{timestamp.strftime('%H:%M:%S')}")
          end
          timestamps << { file: file, filename: filename, time: timestamp }
        rescue => e
          puts "Error parsing timestamp for #{filename}: #{e.message}"
        end
      end
    end
    
    # Sort by timestamp
    timestamps.sort_by! { |t| t[:time] }
    
    # Identify session breaks (gap > 30 seconds)
    session_gap_seconds = 30
    sessions = []
    current_session = []
    
    timestamps.each do |photo|
      if current_session.empty?
        current_session << photo
      else
        prev_time = current_session.last[:time]
        time_diff = (photo[:time] - prev_time) * 24 * 60 * 60 # in seconds
        
        if time_diff > session_gap_seconds
          sessions << current_session
          current_session = [photo]
        else
          current_session << photo
        end
      end
    end
    
    sessions << current_session unless current_session.empty?
    
    # Create sessions and photos
    puts "\nCreating #{sessions.count} iPhone sessions..."
    
    sessions.each_with_index do |session_photos, index|
      session_num = (index + 1).to_s.rjust(3, '0')
      first_photo = session_photos.first
      
      # Create session
      burst_id = "iphone_#{session_num}_#{first_photo[:time].strftime('%Y%m%d_%H%M%S')}"
      
      # Get or create Monday session day
      monday = SessionDay.find_or_create_by!(date: Date.parse('2025-08-25'))
      
      # Create session with required fields
      session = PhotoSession.create!(
        burst_id: burst_id,
        session_day: monday,
        session_number: (monday.photo_sessions.maximum(:session_number) || 0) + 1,
        started_at: first_photo[:time],
        photo_count: session_photos.count
      )
      
      puts "\nSession #{burst_id}:"
      puts "  Creating #{session_photos.count} photos..."
      
      # Create photos and attach images
      session_photos.each_with_index do |photo_data, photo_index|
        photo = session.photos.create!(
          filename: photo_data[:filename],
          original_path: photo_data[:file],
          position: photo_index,
          rejected: false
        )
        
        # Attach the HEIC file to Active Storage
        if File.exist?(photo_data[:file])
          photo.image.attach(
            io: File.open(photo_data[:file]),
            filename: photo_data[:filename],
            content_type: 'image/heic'
          )
          print "."
        else
          print "x"
        end
      end
      
      puts " Done!"
    end
    
    puts "\n\nImport complete!"
    puts "Created #{sessions.count} sessions with #{timestamps.count} total photos"
  end
end