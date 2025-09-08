class FaceDetectionJob < ApplicationJob
  queue_as :face_detection

  # Process face detection for a single photo
  def perform(photo_id)
    photo = Photo.find(photo_id)
    
    # Skip if already processed
    return if photo.face_data.present?
    
    # Process face detection
    photo.detect_faces!
    
    Rails.logger.info "Face detection completed for Photo ##{photo.id} (#{photo.filename})"
  rescue => e
    Rails.logger.error "Face detection failed for Photo ##{photo_id}: #{e.message}"
    raise # Re-raise to trigger retry
  end
end