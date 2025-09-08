namespace :variants do
  desc "Generate image variants for all photos"
  task generate_all: :environment do
    puts "=== Generating Variants for All Photos ==="
    
    photos = Photo.joins(:image_attachment)
    total = photos.count
    
    puts "Found #{total} photos with attachments"
    puts "This will generate :thumb and :large variants for each photo"
    
    print "Continue? (y/n): "
    response = STDIN.gets.chomp
    
    unless response.downcase == 'y'
      puts "Cancelled"
      exit
    end
    
    # Queue all photos for variant generation
    BatchProcessingService.queue_variant_generation(photos, variants: [:thumb, :large])
  end
  
  desc "Generate variants for a specific day"
  task :generate_day, [:day] => :environment do |t, args|
    day = args[:day]
    
    unless day
      puts "Usage: rails variants:generate_day[monday]"
      exit
    end
    
    day_obj = SessionDay.find_by(day_name: day.downcase)
    unless day_obj
      puts "Day not found: #{day}"
      exit
    end
    
    photos = Photo.joins(:photo_session, :image_attachment)
                  .where(photo_sessions: { session_day_id: day_obj.id })
    
    puts "=== Generating Variants for #{day.capitalize} ==="
    puts "Found #{photos.count} photos"
    
    BatchProcessingService.queue_variant_generation(photos, variants: [:thumb, :large])
  end
  
  desc "Generate variants for a specific session"
  task :generate_session, [:burst_id] => :environment do |t, args|
    burst_id = args[:burst_id]
    
    unless burst_id
      puts "Usage: rails variants:generate_session[burst_001_20250825_075906]"
      exit
    end
    
    session = PhotoSession.find_by(burst_id: burst_id)
    unless session
      puts "Session not found: #{burst_id}"
      exit
    end
    
    photos = session.photos.joins(:image_attachment)
    
    puts "=== Generating Variants for Session #{burst_id} ==="
    puts "Found #{photos.count} photos"
    
    BatchProcessingService.queue_variant_generation(photos, variants: [:thumb, :large])
  end
  
  desc "Generate variants synchronously (for testing)"
  task test: :environment do
    # Test with one photo
    photo = Photo.joins(:image_attachment).first
    
    if photo
      puts "Testing variant generation for Photo ##{photo.id}"
      
      [:thumb, :large].each do |variant_name|
        print "Generating #{variant_name}... "
        start = Time.now
        
        variant = photo.image.variant(variant_name)
        variant.processed
        
        elapsed = Time.now - start
        puts "done (#{(elapsed * 1000).round}ms)"
      end
    else
      puts "No photos with attachments found"
    end
  end
  
  desc "Check variant generation status"
  task status: :environment do
    puts "=== Variant Generation Status ==="
    
    # Check for photos with attachments
    total_photos = Photo.joins(:image_attachment).count
    
    # Estimate how many variants exist by checking a sample
    sample_photos = Photo.joins(:image_attachment).limit(10)
    
    thumb_count = 0
    large_count = 0
    
    sample_photos.each do |photo|
      begin
        # Check if variant exists (this doesn't generate it)
        thumb_variant = photo.image.variant(:thumb)
        large_variant = photo.image.variant(:large)
        
        # Check if processed (blob exists in storage)
        thumb_count += 1 if thumb_variant.send(:processed?)
        large_count += 1 if large_variant.send(:processed?)
      rescue
        # Ignore errors
      end
    end
    
    puts "Total photos with attachments: #{total_photos}"
    puts "Sample check (10 photos):"
    puts "  Thumb variants: #{thumb_count}/10"
    puts "  Large variants: #{large_count}/10"
    
    # Check job queue
    variant_jobs = SolidQueue::Job.where("class_name = 'VariantGenerationJob'").where(finished_at: nil).count
    puts "\nPending variant generation jobs: #{variant_jobs}"
  end
end