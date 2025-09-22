namespace :monday do
  desc "Process face detection for Monday's photos"
  task process_faces: :environment do
    sessions = PhotoSession.where("started_at >= '2025-08-26' AND started_at < '2025-08-27'")
    total_sessions = sessions.count
    total_photos = sessions.joins(:photos).count

    puts "Processing Monday's sessions..."
    puts "=" * 60
    puts "Sessions: #{total_sessions}"
    puts "Total photos: #{total_photos}"
    puts "=" * 60

    processed_photos = 0
    faces_found = 0

    sessions.order(:started_at).each_with_index do |session, session_index|
      photos_to_process = session.photos.where(face_detected_at: nil)

      next if photos_to_process.empty?

      puts "\n[#{session_index + 1}/#{total_sessions}] Processing #{session.burst_id}"
      puts "  Photos to process: #{photos_to_process.count}"

      photos_to_process.each_with_index do |photo, photo_index|
        print "\r  Processing photo #{photo_index + 1}/#{photos_to_process.count}..."

        begin
          photo.detect_faces!
          processed_photos += 1

          if photo.has_faces?
            faces_found += photo.face_count
            print " ✓ #{photo.face_count} face(s)"
          else
            print " - No faces"
          end
        rescue => e
          print " ✗ Error: #{e.message}"
        end

        # Be nice to the CPU - small delay every 10 photos
        sleep 0.05 if (photo_index + 1) % 10 == 0
      end

      puts "\n  Session complete. Faces found: #{session.photos.where.not(face_data: nil).count}"

      # Longer break between sessions
      sleep 0.2
    end

    puts "\n" + "=" * 60
    puts "Monday processing complete!"
    puts "Photos processed: #{processed_photos}"
    puts "Total faces found: #{faces_found}"
    puts "=" * 60
  end

  desc "Process just a few Monday sessions for testing"
  task test_process: :environment do
    sessions = PhotoSession.where("started_at >= '2025-08-26' AND started_at < '2025-08-27'")
                          .order(:photo_count)
                          .limit(3)

    puts "Processing #{sessions.count} small Monday sessions for testing..."

    sessions.each do |session|
      puts "\nProcessing #{session.burst_id} (#{session.photos.count} photos)..."

      session.photos.where(face_detected_at: nil).each_with_index do |photo, index|
        print "\r  Photo #{index + 1}/#{session.photos.count}..."

        begin
          photo.detect_faces!

          if photo.has_faces?
            print " ✓ Found #{photo.face_count} face(s)"
          else
            print " - No faces"
          end
        rescue => e
          print " ✗ Error"
        end
      end

      puts "\n  Complete!"
    end

    puts "\nTest processing complete!"
  end
end
