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

  desc "Process large variants synchronously in batches"
  task process_large_sync: :environment do
    photos = Photo.joins(:image_attachment).order(:id)
    total = photos.count
    
    puts "=== Processing Large Variants Synchronously ==="
    puts "Total photos: #{total}"
    puts "Using proxy mode: #{Rails.application.config.active_storage.resolve_model_to_route}"
    puts "\nThis will process variants immediately, not through background jobs."
    print "Continue? (y/n): "
    
    response = STDIN.gets.chomp
    unless response.downcase == 'y'
      puts "Cancelled"
      exit
    end
    
    processed = 0
    errors = []
    start_time = Time.now
    
    photos.find_in_batches(batch_size: 50) do |batch|
      batch.each do |photo|
        begin
          # Process the large variant synchronously
          variant = photo.image.variant(:large)
          variant.processed
          
          processed += 1
          
          # Progress update every 10 photos
          if processed % 10 == 0
            elapsed = Time.now - start_time
            rate = processed / elapsed
            remaining = (total - processed) / rate
            
            print "\rProcessed: #{processed}/#{total} (#{(processed.to_f/total * 100).round(1)}%) | " \
                  "Rate: #{rate.round(1)}/sec | ETA: #{(remaining/60).round(1)} min"
          end
        rescue => e
          errors << { photo_id: photo.id, error: e.message }
          print "E"
        end
      end
    end
    
    puts "\n\n" + "="*50
    puts "Processing complete!"
    puts "Total processed: #{processed}/#{total}"
    puts "Errors: #{errors.count}"
    puts "Time taken: #{((Time.now - start_time)/60).round(1)} minutes"
    
    if errors.any?
      puts "\nErrors encountered:"
      errors.first(10).each do |error|
        puts "  Photo #{error[:photo_id]}: #{error[:error]}"
      end
      puts "  ... and #{errors.count - 10} more" if errors.count > 10
    end
  end
end