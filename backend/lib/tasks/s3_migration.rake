namespace :s3 do
  desc "Migrate photos to S3 with Active Storage (selective by day)"
  task :migrate_photos, [:day] => :environment do |t, args|
    require 'fileutils'
    
    # Use development storage for now (will use amazon when ready)
    ActiveStorage::Current.url_options = { host: 'http://localhost:4000' }
    
    # Filter by day if specified
    query = Photo.includes(:photo_session => :session_day)
    
    if args[:day].present?
      day_name = args[:day].downcase
      query = query.joins(photo_session: :session_day)
                   .where(session_days: { day_name: day_name })
      puts "Migrating photos from #{day_name.capitalize} only..."
    else
      puts "Migrating ALL photos..."
    end
    
    total_photos = query.count
    puts "Found #{total_photos} photos to migrate"
    
    if total_photos == 0
      puts "No photos found to migrate"
      exit
    end
    
    # Confirm before proceeding
    print "Continue? (y/n): "
    response = STDIN.gets.chomp.downcase
    unless response == 'y'
      puts "Migration cancelled"
      exit
    end
    
    success_count = 0
    error_count = 0
    already_attached = 0
    
    query.find_each.with_index do |photo, index|
      begin
        # Skip if already has attachment
        if photo.image.attached?
          already_attached += 1
          print "✓"
          next
        end
        
        # Find the actual file
        file_path = photo.original_path
        
        unless File.exist?(file_path)
          puts "\n⚠️  File not found: #{file_path}"
          error_count += 1
          next
        end
        
        # Attach the file to Active Storage
        photo.image.attach(
          io: File.open(file_path),
          filename: photo.filename,
          content_type: 'image/jpeg'
        )
        
        success_count += 1
        
        # Progress indicator
        if (index + 1) % 10 == 0
          percent = ((index + 1).to_f / total_photos * 100).round(1)
          print "\n[#{index + 1}/#{total_photos}] #{percent}% complete"
        else
          print "."
        end
        
      rescue => e
        error_count += 1
        puts "\n❌ Error processing photo #{photo.id}: #{e.message}"
      end
    end
    
    puts "\n\n✅ Migration complete!"
    puts "   - Successfully migrated: #{success_count}"
    puts "   - Already attached: #{already_attached}"
    puts "   - Errors: #{error_count}"
    puts "   - Total processed: #{total_photos}"
  end
  
  desc "Test S3 connection and configuration"
  task test_connection: :environment do
    begin
      # Try to create a test file
      test_blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("S3 connection test"),
        filename: "test_#{Time.now.to_i}.txt",
        content_type: "text/plain"
      )
      
      puts "✅ S3 connection successful!"
      puts "   Bucket: #{Rails.application.credentials.dig(:aws, :bucket)}"
      puts "   Region: #{Rails.application.credentials.dig(:aws, :region)}"
      puts "   Test file created: #{test_blob.key}"
      
      # Clean up test file
      test_blob.purge
      puts "   Test file cleaned up"
      
    rescue => e
      puts "❌ S3 connection failed!"
      puts "   Error: #{e.message}"
      puts "\nPlease check:"
      puts "1. AWS credentials in Rails credentials"
      puts "2. S3 bucket exists and is accessible"
      puts "3. IAM user has proper permissions"
    end
  end
  
  desc "Generate variants for already uploaded photos"
  task generate_variants: :environment do
    photos_with_images = Photo.joins(:image_attachment)
    total = photos_with_images.count
    
    puts "Generating variants for #{total} photos..."
    
    photos_with_images.find_each.with_index do |photo, index|
      begin
        if photo.image.attached? && photo.image.variable?
          # This will generate and cache the variants
          photo.image.variant(:thumb).processed
          photo.image.variant(:medium).processed
          
          if (index + 1) % 10 == 0
            percent = ((index + 1).to_f / total * 100).round(1)
            puts "[#{index + 1}/#{total}] #{percent}% complete"
          end
        end
      rescue => e
        puts "Error generating variants for photo #{photo.id}: #{e.message}"
      end
    end
    
    puts "✅ Variant generation complete!"
  end
  
  desc "Show migration status"
  task status: :environment do
    total_photos = Photo.count
    attached_photos = Photo.joins(:image_attachment).count
    
    puts "\n📊 Migration Status:"
    puts "   Total photos in database: #{total_photos}"
    puts "   Photos with Active Storage: #{attached_photos}"
    puts "   Photos pending migration: #{total_photos - attached_photos}"
    
    if attached_photos > 0
      puts "\n   Progress: #{(attached_photos.to_f / total_photos * 100).round(1)}% complete"
    end
    
    # Show breakdown by day
    puts "\n📅 By Day:"
    SessionDay.includes(photo_sessions: :photos).each do |day|
      day_photos = day.photo_sessions.joins(:photos).count
      day_attached = day.photo_sessions.joins(photos: :image_attachment).count
      status = day_attached == day_photos ? "✅" : "⏳"
      puts "   #{status} #{day.day_name.capitalize}: #{day_attached}/#{day_photos} photos"
    end
  end
end