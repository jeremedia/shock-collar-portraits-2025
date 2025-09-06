namespace :faces do
  desc "Detect faces in all photos"
  task detect_all: :environment do
    photos = Photo.where(face_detected_at: nil)
    total = photos.count
    
    puts "Starting face detection for #{total} photos..."
    
    photos.find_each.with_index do |photo, index|
      print "\rProcessing photo #{index + 1}/#{total} (#{photo.filename})..."
      
      begin
        photo.detect_faces!
        
        if photo.has_faces?
          print " ✓ Found #{photo.face_count} face(s)"
        else
          print " - No faces found"
        end
      rescue => e
        print " ✗ Error: #{e.message}"
      end
      
      # Be nice to the CPU
      sleep 0.1 if index % 10 == 0
    end
    
    puts "\n\nFace detection complete!"
    
    # SQLite-compatible counting
    with_faces = Photo.where.not(face_data: nil).select { |p| p.face_data['faces'].present? && p.face_data['faces'].any? }.count
    without_faces = Photo.where.not(face_data: nil).select { |p| p.face_data['faces'].blank? || p.face_data['faces'].empty? }.count + Photo.where(face_data: nil).count
    
    puts "Photos with faces: #{with_faces}"
    puts "Photos without faces: #{without_faces}"
  end
  
  desc "Detect faces in a specific session"
  task :detect_session, [:burst_id] => :environment do |t, args|
    session = PhotoSession.find_by!(burst_id: args[:burst_id])
    photos = session.photos.where(face_detected_at: nil)
    
    puts "Detecting faces in session #{session.burst_id} (#{photos.count} photos)..."
    
    photos.each_with_index do |photo, index|
      print "\rProcessing photo #{index + 1}/#{photos.count}..."
      
      begin
        photo.detect_faces!
        
        if photo.has_faces?
          print " ✓ Found #{photo.face_count} face(s)"
        else
          print " - No faces found"
        end
      rescue => e
        print " ✗ Error: #{e.message}"
      end
    end
    
    puts "\nComplete!"
  end
  
  desc "Test face detection on a single photo"
  task :test, [:photo_id] => :environment do |t, args|
    photo = Photo.find(args[:photo_id])
    
    puts "Testing face detection on photo #{photo.id} (#{photo.filename})..."
    
    result = photo.detect_faces!
    
    if photo.has_faces?
      puts "✓ Successfully detected #{photo.face_count} face(s):"
      
      photo.face_data['faces'].each_with_index do |face, i|
        puts "  Face #{i + 1}:"
        puts "    Position: (#{face['x'].round}, #{face['y'].round})"
        puts "    Size: #{face['width'].round}x#{face['height'].round}"
        puts "    Confidence: #{(face['confidence'] * 100).round}%"
      end
      
      crop_params = FaceDetectionService.face_crop_params(photo)
      if crop_params
        puts "\nSuggested crop for primary face:"
        puts "  Position: (#{crop_params[:left]}, #{crop_params[:top]})"
        puts "  Size: #{crop_params[:width]}x#{crop_params[:height]}"
      end
    else
      puts "No faces detected in this photo."
    end
  end
  
  desc "Clear face data for re-detection"
  task clear: :environment do
    puts "Are you sure you want to clear all face detection data? (yes/no)"
    response = STDIN.gets.chomp
    
    if response.downcase == 'yes'
      Photo.update_all(face_data: nil, face_detected_at: nil)
      puts "Face detection data cleared."
    else
      puts "Operation cancelled."
    end
  end
  
  desc "Show face detection statistics"
  task stats: :environment do
    total = Photo.count
    detected = Photo.where.not(face_detected_at: nil).count
    
    # SQLite-compatible counting
    photos_with_data = Photo.where.not(face_data: nil)
    with_faces = photos_with_data.select { |p| p.face_data['faces'].present? && p.face_data['faces'].any? }.count
    
    puts "Face Detection Statistics:"
    puts "=" * 40
    puts "Total photos: #{total}"
    puts "Photos analyzed: #{detected} (#{(detected.to_f / total * 100).round(1)}%)"
    puts "Photos with faces: #{with_faces} (#{(with_faces.to_f / total * 100).round(1)}%)"
    puts "Photos without faces: #{detected - with_faces}"
    puts "Photos not yet analyzed: #{total - detected}"
    
    if with_faces > 0
      face_counts = photos_with_data
                      .select { |p| p.face_data['faces'].present? && p.face_data['faces'].any? }
                      .map { |p| p.face_data['faces'].length }
      
      puts "\nFace count distribution:"
      face_counts.tally.sort.each do |count, photos|
        puts "  #{count} face(s): #{photos} photos"
      end
    end
  end
end