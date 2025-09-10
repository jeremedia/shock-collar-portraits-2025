# Background job to extract EXIF DateTimeOriginal from photos
# This is critical for maintaining correct chronological order when sessions are split
# The EXIF time is in camera's local time (PST) and gets converted to UTC by Photo#photo_taken_at
class ExifExtractionJob < ApplicationJob
  queue_as :default
  
  def perform(photo_id)
    photo = Photo.find(photo_id)
    
    # Skip if already has EXIF data
    return if photo.exif_data && photo.exif_data['DateTimeOriginal'].present?
    
    # Extract EXIF datetime using exiftool
    # This stores the raw EXIF time (PST) in the database
    # The Photo#photo_taken_at method handles timezone conversion
    photo.extract_exif_datetime
    
    Rails.logger.info "Extracted EXIF datetime for photo #{photo.id}: #{photo.exif_data&.dig('DateTimeOriginal')}"
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn "Photo #{photo_id} not found for EXIF extraction"
  rescue => e
    Rails.logger.error "Failed to extract EXIF for photo #{photo_id}: #{e.message}"
    raise # Re-raise for retry
  end
end