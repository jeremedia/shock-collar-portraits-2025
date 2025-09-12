class Photo < ApplicationRecord
  belongs_to :photo_session
  belongs_to :sitting, optional: true
  has_one_attached :image do |attachable|
    attachable.variant :thumb, resize_to_limit: [300, 300], format: :webp, saver: { quality: 80 }
    attachable.variant :medium, resize_to_limit: [800, 800], format: :webp, saver: { quality: 85 }
    attachable.variant :large, resize_to_limit: [1600, 1600], format: :webp, saver: { quality: 90 }
    attachable.variant :gallery, resize_to_limit: [1200, 1200], format: :jpeg, saver: { quality: 85 }
  end

  scope :not_rejected, -> { where(rejected: false) }
  scope :accepted, -> { where(rejected: false) }
  scope :rejected, -> { where(rejected: true) }
  scope :heroes, -> { joins("INNER JOIN sittings ON sittings.hero_photo_id = photos.id") }
  scope :without_face_detection, -> { where(face_data: nil) }
  
  # Automatically enqueue processing for new photos
  after_create :enqueue_image_attachment
  after_create :enqueue_face_detection
  after_create :enqueue_variant_generation
  after_create :enqueue_exif_extraction

  # Rails 8 uses coder instead of second argument for serialize
  serialize :metadata, coder: JSON
  serialize :exif_data, coder: JSON

  validates :filename, presence: true
  
  def image_url(variant = nil)
    return nil unless image.attached?
    
    if variant
      # Rails 8 syntax - directly access named variant
      image.variant(variant).url
    else
      image.url
    end
  end
  
  # Face detection methods
  def detect_faces!
    ::FaceDetectionService.detect_for_photo(self)
  end
  
  # Enqueue image attachment job for this photo
  def enqueue_image_attachment
    return if image.attached? # Skip if already attached
    return unless original_path.present? # Skip if no file path
    ImageAttachmentJob.perform_later(id)
  end
  
  # Enqueue face detection job for this photo
  def enqueue_face_detection
    return if face_data.present? # Skip if already processed
    FaceDetectionJob.perform_later(id)
  end
  
  # Enqueue variant generation job for this photo
  def enqueue_variant_generation
    # Queue variant generation after attachment (will be skipped if no attachment)
    VariantGenerationJob.perform_later(id, [:thumb, :large, :gallery])
  end
  
  # Enqueue EXIF extraction job for this photo
  # Extracts DateTimeOriginal to determine actual photo taken time
  # Important for maintaining correct chronological order when sessions are split
  def enqueue_exif_extraction
    return if exif_data && exif_data['DateTimeOriginal'].present? # Skip if already extracted
    ExifExtractionJob.perform_later(id)
  end
  
  def has_faces?
    return false unless face_data.present? && face_data['faces'].present?
    faces = face_data['faces']
    faces.is_a?(Array) && faces.any?
  end
  
  def face_count
    return 0 unless has_faces?
    face_data['faces'].length
  end
  
  def primary_face
    return nil unless has_faces?
    face_data['faces'].max_by { |face| face['width'] * face['height'] }
  end
  
  # Dynamic face crop variant
  def face_crop_variant(size)
    crop_params = ::FaceDetectionService.face_crop_params(self)
    
    if crop_params
      {
        crop: "#{crop_params[:width]}x#{crop_params[:height]}+#{crop_params[:left]}+#{crop_params[:top]}",
        resize_to_fill: [size, size]
      }
    else
      # Fallback to center crop if no face detected
      { resize_to_fill: [size, size] }
    end
  end
  
  # Get face crop URL
  def face_crop_url(size: 300)
    return nil unless has_faces? && image.attached?
    
    crop_params = ::FaceDetectionService.face_crop_params(self)
    return nil unless crop_params
    
    # Generate dynamic variant for face crop
    # Using extract_area for vips processor
    variant_params = {
      extract_area: [crop_params[:left], crop_params[:top], crop_params[:width], crop_params[:height]],
      resize_to_fill: [size, size],
      format: :webp,
      saver: { quality: 85 }
    }
    
    begin
      Rails.application.routes.url_helpers.rails_blob_url(image.variant(variant_params).processed, only_path: true)
    rescue ActiveStorage::FileNotFoundError
      # Return nil if the file doesn't exist (e.g., still being uploaded to S3)
      nil
    end
  end
  
  # Check if face detection is needed
  def needs_face_detection?
    face_detected_at.nil? && (image.attached? || original_path.present?)
  end
  
  # Extract EXIF datetime from original file using exiftool
  # The DateTimeOriginal field contains when the photo was actually taken
  # Format: "2025:08:25 15:14:48" (in camera's local time - PST at Burning Man)
  def extract_exif_datetime
    return unless original_path && File.exist?(original_path)
    
    # Use exiftool to extract DateTimeOriginal
    # -s3 flag returns just the value without field name
    result = `exiftool -DateTimeOriginal -s3 "#{original_path}" 2>/dev/null`.strip
    
    if result.present?
      self.exif_data ||= {}
      self.exif_data['DateTimeOriginal'] = result
      save! if persisted?
      result
    end
  end
  
  # Get the actual time the photo was taken
  # CRITICAL: This method is used for chronological sorting of sessions!
  # Returns UTC time to match the burst folder timestamps
  def photo_taken_at
    # First try to get from stored EXIF data
    if exif_data && exif_data['DateTimeOriginal']
      begin
        # EXIF datetime is in camera's local time (PST at Burning Man)
        # Format: "2025:08:25 15:14:48" - this is PST time
        # Must convert to UTC to match burst folder timestamps which are already UTC
        local_time = DateTime.strptime(exif_data['DateTimeOriginal'], '%Y:%m:%d %H:%M:%S')
        # Burning Man is in PST (UTC-7), so add 7 hours to get UTC
        local_time.change(offset: '-0700').utc
      rescue => e
        Rails.logger.warn "Failed to parse EXIF datetime for photo #{id}: #{e.message}"
        calculated_taken_at
      end
    else
      # Extract EXIF if not already done
      datetime_str = extract_exif_datetime
      if datetime_str.present?
        begin
          # EXIF datetime is in camera's local time (PST at Burning Man)
          local_time = DateTime.strptime(datetime_str, '%Y:%m:%d %H:%M:%S')
          # Burning Man is in PST (UTC-7)
          local_time.change(offset: '-0700').utc
        rescue => e
          Rails.logger.warn "Failed to parse extracted EXIF datetime for photo #{id}: #{e.message}"
          calculated_taken_at
        end
      else
        calculated_taken_at
      end
    end
  end
  
  # Fallback calculated time based on position in burst
  # Used when EXIF data is not available
  # Burst folder timestamp (already UTC) + offset based on photo position
  def calculated_taken_at
    # Canon R5 shoots approximately 0.5fps in burst mode (2 seconds per photo)
    # Position 0 = burst start time, Position 1 = +2 seconds, etc.
    photo_session.started_at + (position * 2).seconds
  end
end
