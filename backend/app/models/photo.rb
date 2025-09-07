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
  
  # Automatically enqueue image attachment and face detection for new photos
  after_create :enqueue_image_attachment
  after_create :enqueue_face_detection

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
    
    Rails.application.routes.url_helpers.rails_blob_url(image.variant(variant_params).processed, only_path: true)
  end
  
  # Check if face detection is needed
  def needs_face_detection?
    face_detected_at.nil? && (image.attached? || original_path.present?)
  end
end
