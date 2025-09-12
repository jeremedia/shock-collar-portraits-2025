class BatchProcessingService
  class << self
    def process_variants_in_batches(photos_scope, batch_size: 10, variants: [:thumb, :large])
      total = photos_scope.count
      processed = 0
      
      photos_scope.find_in_batches(batch_size: batch_size) do |batch|
        # Process batch in parallel using threads
        threads = batch.map do |photo|
          Thread.new do
            begin
              if photo.image.attached?
                variants.each do |variant_name|
                  variant = photo.image.variant(variant_name)
                  variant.processed
                end
              end
            rescue => e
              Rails.logger.error "Failed to generate variants for photo #{photo.id}: #{e.message}"
            end
          end
        end
        
        # Wait for all threads in this batch to complete
        threads.each(&:join)
        
        processed += batch.size
        puts "Processed #{processed}/#{total} variant generations (#{(processed * 100.0 / total).round(1)}%)"
      end
      
      processed
    end
    
    def queue_variant_generation(photos_scope, variants: [:thumb, :large])
      count = 0
      photos_scope.find_each do |photo|
        if photo.image.attached?
          VariantGenerationJob.perform_later(photo.id, variants)
          count += 1
        end
      end
      
      puts "Queued #{count} photos for variant generation"
      count
    end
    def process_attachments_in_batches(photos_scope, batch_size: 50)
      total = photos_scope.count
      processed = 0
      
      photos_scope.find_in_batches(batch_size: batch_size) do |batch|
        # Process batch in parallel using threads
        threads = batch.map do |photo|
          Thread.new do
            begin
              ImageAttachmentService.attach_image(photo) unless photo.image.attached?
            rescue => e
              Rails.logger.error "Failed to attach image for photo #{photo.id}: #{e.message}"
            end
          end
        end
        
        # Wait for all threads in this batch to complete
        threads.each(&:join)
        
        processed += batch.size
        puts "Processed #{processed}/#{total} attachments (#{(processed * 100.0 / total).round(1)}%)"
      end
      
      processed
    end
    
    def process_face_detection_in_batches(photos_scope, batch_size: 10)
      total = photos_scope.count
      processed = 0
      
      photos_scope.find_in_batches(batch_size: batch_size) do |batch|
        # Process batch in parallel using threads
        threads = batch.map do |photo|
          Thread.new do
            begin
              photo.detect_faces! unless photo.face_data.present?
            rescue => e
              Rails.logger.error "Failed to detect faces for photo #{photo.id}: #{e.message}"
            end
          end
        end
        
        # Wait for all threads in this batch to complete
        threads.each(&:join)
        
        processed += batch.size
        puts "Processed #{processed}/#{total} face detections (#{(processed * 100.0 / total).round(1)}%)"
      end
      
      processed
    end
    
    def process_day_async(day_name)
      day = SessionDay.find_by(day_name: day_name.downcase)
      return unless day
      
      sessions = PhotoSession.where(session_day: day)
      photos = Photo.joins(:photo_session).where(photo_session: sessions)
      
      # Queue attachment jobs for photos without attachments
      photos_needing_attachment = photos.where.not(id: photos.joins(:image_attachment))
      photos_needing_attachment.find_each do |photo|
        ImageAttachmentJob.perform_later(photo.id)
      end
      
      # Queue face detection jobs for photos without face data
      photos_needing_faces = photos.where(face_data: nil)
      photos_needing_faces.find_each do |photo|
        FaceDetectionJob.perform_later(photo.id)
      end
      
      {
        attachments_queued: photos_needing_attachment.count,
        face_detection_queued: photos_needing_faces.count
      }
    end
  end
end